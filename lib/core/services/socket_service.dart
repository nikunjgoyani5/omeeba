import 'dart:async';
import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:omeeba_new/core/utils/app_constant.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';

class _PendingRequest {
  final String event;
  final dynamic data;
  final DateTime timestamp;

  _PendingRequest(this.event, this.data) : timestamp = DateTime.now();
}

class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  IO.Socket? _socket;

  bool _isConnecting = false;
  bool _isConnected = false;

  // Tracks which userId the current socket was opened for.
  // If a different userId tries to connect, we force a full reconnect.
  String _activeUserId = '';

  bool get isConnected => _isConnected;

  IO.Socket? get socket => _socket;

  // ---------------- Backward Compatibility ----------------
  Function(dynamic)? onSnapSent;
  Function()? onConnect;
  Function()? onDisconnect;

  // ---------------- Pending Queue ----------------
  final List<_PendingRequest> _pending = [];
  static const int _maxPending = 100;
  static const Duration _pendingTTL = Duration(minutes: 2);

  // ---------------- Heartbeat ----------------
  Timer? _heartbeatTimer;

  /// When [true], `new_message` socket payloads are not forwarded to [onNewMessageStream]
  /// (used while `share_to_chats` is in flight so UI does not handle the same share twice).
  bool _suppressNewMessageBroadcast = true;

  // ---------------- Streams ----------------
  final _connectCtrl = StreamController<void>.broadcast();
  final _disconnectCtrl = StreamController<void>.broadcast();
  final _connectErrorCtrl = StreamController<dynamic>.broadcast();
  final _errorCtrl = StreamController<dynamic>.broadcast();

  final _roomCreatedCtrl = StreamController<dynamic>.broadcast();
  final _roomsListCtrl = StreamController<dynamic>.broadcast();
  final _requestsListCtrl = StreamController<dynamic>.broadcast();

  final _requestAcceptedCtrl = StreamController<dynamic>.broadcast();
  final _requestRejectedCtrl = StreamController<dynamic>.broadcast();
  final _requestBlockedCtrl = StreamController<dynamic>.broadcast();

  final _messagesListCtrl = StreamController<dynamic>.broadcast();
  final _newMessageCtrl = StreamController<dynamic>.broadcast();
  final _newSnapCtrl = StreamController<dynamic>.broadcast();
  final _messageDeliveredCtrl = StreamController<dynamic>.broadcast();
  final _messageReadCtrl = StreamController<dynamic>.broadcast();

  final _typingStartCtrl = StreamController<dynamic>.broadcast();
  final _typingStopCtrl = StreamController<dynamic>.broadcast();
  final _userTypingCtrl = StreamController<dynamic>.broadcast();

  final _snapSentCtrl = StreamController<dynamic>.broadcast();
  final _snapViewedCtrl = StreamController<dynamic>.broadcast();
  final _contentSharedToChatsCtrl = StreamController<dynamic>.broadcast();

  // ---------------- Stream Getters ----------------
  Stream<void> get onConnectStream => _connectCtrl.stream;

  Stream<void> get onDisconnectStream => _disconnectCtrl.stream;

  Stream<dynamic> get onConnectErrorStream => _connectErrorCtrl.stream;

  Stream<dynamic> get onErrorStream => _errorCtrl.stream;

  Stream<dynamic> get onRoomCreatedStream => _roomCreatedCtrl.stream;

  Stream<dynamic> get onRoomsListStream => _roomsListCtrl.stream;

  Stream<dynamic> get onRequestsListStream => _requestsListCtrl.stream;

  Stream<dynamic> get onRequestAcceptedStream => _requestAcceptedCtrl.stream;

  Stream<dynamic> get onRequestRejectedStream => _requestRejectedCtrl.stream;

  Stream<dynamic> get onRequestBlockedStream => _requestBlockedCtrl.stream;

  Stream<dynamic> get onMessagesListStream => _messagesListCtrl.stream;

  Stream<dynamic> get onNewMessageStream => _newMessageCtrl.stream;

  Stream<dynamic> get onNewSnapStream => _newSnapCtrl.stream;

  Stream<dynamic> get onMessageDeliveredStream => _messageDeliveredCtrl.stream;

  Stream<dynamic> get onMessageReadStream => _messageReadCtrl.stream;

  Stream<dynamic> get onTypingStartStream => _typingStartCtrl.stream;

  Stream<dynamic> get onTypingStopStream => _typingStopCtrl.stream;

  Stream<dynamic> get onUserTypingStream => _userTypingCtrl.stream;

  Stream<dynamic> get onSnapSentStream => _snapSentCtrl.stream;

  Stream<dynamic> get onSnapViewedStream => _snapViewedCtrl.stream;

  Stream<dynamic> get onContentSharedToChatsStream =>
      _contentSharedToChatsCtrl.stream;

  // =========================================================
  // CONNECT
  // =========================================================

  /// Safe connect: if already connected/connecting for this exact userId → no-op.
  /// If the userId differs (user switched), force a full reconnect.
  void ensureConnected(String userId) {
    if (userId.isEmpty) return;

    // Already connected/connecting as this user — nothing to do.
    if (_activeUserId == userId && (_isConnected || _isConnecting)) return;

    // Different user (or fresh start) — force clean reconnect.
    if (_activeUserId != userId && _activeUserId.isNotEmpty) {
      _hardReset();
    }

    _doConnect(userId);
  }

  /// Kept for backward compatibility — delegates to ensureConnected.
  void connect(String userId) => ensureConnected(userId);

  void _doConnect(String userId) {
    if (_isConnected || _isConnecting) return;

    _activeUserId = userId;
    _isConnecting = true;
    _cleanupSocketOnly();

    // enableForceNew() is critical: without it socket_io_client reuses the
    // cached Manager for the same URL, which still carries the OLD userId in
    // its query params — causing the previous user's data to be returned even
    // after logout+login. forceNew creates a brand-new Manager every time.
    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'userId': userId})
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .setTimeout(20000)
          .build(),
    );

    _setupListeners();
    _socket!.connect();
  }

  void _setupListeners() {
    if (_socket == null) return;

    // Capture the userId this socket was created for.
    // If _activeUserId changes by the time onConnect fires, this is a stale reconnect.
    final sessionUserId = _activeUserId;

    _socket!.onConnect((_) {
      // Guard against stale reconnects from a previous user session.
      // If the active user changed (logout → new login), kill this socket immediately.
      if (sessionUserId != _activeUserId) {
        _cleanupSocketOnly();
        return;
      }

      _isConnecting = false;
      _isConnected = true;

      _startHeartbeat();
      _connectCtrl.add(null);
      if (onConnect != null) onConnect!();
      _processPending();
    });

    _socket!.onDisconnect((_) {
      _isConnecting = false;
      _isConnected = false;

      _stopHeartbeat();
      _disconnectCtrl.add(null);
      if (onDisconnect != null) onDisconnect!();
    });

    _socket!.onConnectError((e) {
      _isConnecting = false;
      _isConnected = false;
      _connectErrorCtrl.add(e);
    });

    _socket!.onError((e) {
      _errorCtrl.add(e);
    });

    // ---------------- Server Events ----------------
    _socket!.on('room_created', (d) => _roomCreatedCtrl.add(d));
    _socket!.on('rooms_list', (d) => _roomsListCtrl.add(d));
    _socket!.on('message_requests_list', (d) => _requestsListCtrl.add(d));
    _socket!.on('connect_error', (d) => _connectErrorCtrl.add(d));

    _socket!.on('request_accepted', (d) => _requestAcceptedCtrl.add(d));
    _socket!.on('request_rejected', (d) => _requestRejectedCtrl.add(d));
    _socket!.on('request_blocked', (d) => _requestBlockedCtrl.add(d));

    _socket!.on('messages_list', (d) => _messagesListCtrl.add(d));
    _socket!.on('new_message', (d) {
      if (!_suppressNewMessageBroadcast) return;
      _newMessageCtrl.add(d);
    });
    _socket!.on('new_snap', (d) => _newSnapCtrl.add(d));
    _socket!.on('message_delivered', (d) => _messageDeliveredCtrl.add(d));
    _socket!.on('messages_read', (d) => _messageReadCtrl.add(d));

    _socket!.on('typing_start', (d) => _typingStartCtrl.add(d));
    _socket!.on('typing_stop', (d) => _typingStopCtrl.add(d));
    _socket!.on('user_typing', (d) => _userTypingCtrl.add(d));

    _socket!.on('snap_sent', (d) {
      _snapSentCtrl.add(d);
      if (onSnapSent != null) onSnapSent!(d);
    });

    _socket!.on('snap_viewed', (d) => _snapViewedCtrl.add(d));
    _socket!.on(
      'content_shared_to_chats',
      (d) => _contentSharedToChatsCtrl.add(d),
    );

    _socket!.onAny((event, data) {
      // Heartbeat emits `ping` with no payload — not an error; avoid noisy logs.
      if (event == 'ping' || event == 'pong') return;
      // ignore: avoid_print
      log('📥 SOCKET EVENT → $event  |  DATA → $data');
    });
  }

  // =========================================================
  // EMIT WRAPPER
  // =========================================================

  void emit(String event, dynamic data) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
      return;
    }
    _queue(event, data);
    _autoConnect();
  }

  // =========================================================
  // API METHODS
  // =========================================================

  void createRoom(String otherUserId) =>
      emit('create_room', {'otherUserId': otherUserId});

  void getMessages(String roomId, {int page = 1, int limit = 20}) =>
      emit('get_messages', {'roomId': roomId, 'page': page, 'limit': limit});

  void getRooms({int page = 1, int limit = 20, String search = ''}) =>
      emit('get_rooms', {'page': page, 'limit': limit, 'search': search});

  void getRequests({int page = 1, int limit = 20, String search = ''}) => emit(
    'get_message_requests',
    {'page': page, 'limit': limit, 'search': search},
  );

  void sendMessage(String roomId, String type, String message) => emit(
    'send_message',
    {'roomId': roomId, 'messageType': type, 'message': message},
  );

  void sendTypingStart(String roomId) =>
      emit('typing_start', {'roomId': roomId});

  void sendTypingStop(String roomId) => emit('typing_stop', {'roomId': roomId});

  void readLastMessage(Map<String, dynamic> data) => emit('mark_read', data);

  void acceptRequest(String roomId) =>
      emit('accept_message_request', {'roomId': roomId});

  void rejectRequest(String roomId) =>
      emit('reject_message_request', {'roomId': roomId});

  void blockRequest(String roomId) =>
      emit('block_message_request', {'roomId': roomId});

  void viewSnap(String snapId) => emit('view_snap', {'messageId': snapId});

  void sendSnap(Map<String, dynamic> data) => emit('send_snap', data);

  void deleteRoom(Map<String, dynamic> data) => emit('delete_room', data);

  void shareToChats(
    Map<String, dynamic> data, {
    bool suppressNewMessageUntilAck = true,
  }) {
    _suppressNewMessageBroadcast = false;
    emit('share_to_chats', data);
  }

  // =========================================================
  // PENDING QUEUE
  // =========================================================

  void _queue(String event, dynamic data) {
    _pending.removeWhere(
      (p) => DateTime.now().difference(p.timestamp) > _pendingTTL,
    );
    if (_pending.length >= _maxPending) _pending.removeAt(0);
    _pending.add(_PendingRequest(event, data));
  }

  void _processPending() {
    if (!_isConnected || _socket == null) return;
    final now = DateTime.now();
    final requests = List<_PendingRequest>.from(_pending);
    _pending.clear();
    for (final r in requests) {
      if (now.difference(r.timestamp) <= _pendingTTL) {
        _socket!.emit(r.event, r.data);
      }
    }
  }

  void _autoConnect() {
    final uid = PrefService.getString(PrefKeys.userId);
    if (uid.isEmpty) return;
    ensureConnected(uid);
  }

  // =========================================================
  // HEARTBEAT
  // =========================================================

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected && _socket != null) _socket!.emit('ping');
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // =========================================================
  // DISCONNECT / RESET
  // =========================================================

  /// Call this on LOGOUT. Resets everything so the next login gets a fresh connection.
  void logoutAndReset() {
    _hardReset();
    _activeUserId = '';
    _pending.clear();
  }

  /// Full hard-reset: kills socket + heartbeat + clears all flags.
  /// Does NOT close stream controllers (those stay alive for the singleton's lifetime).
  void _hardReset() {
    _stopHeartbeat();
    _cleanupSocketOnly();
    _isConnected = false;
    _isConnecting = false;
  }

  /// Soft disconnect (keeps activeUserId so reconnect restores the same user).
  void disconnect() {
    _stopHeartbeat();
    _cleanupSocketOnly();
    _isConnected = false;
    _isConnecting = false;
    _pending.clear();
  }

  void _cleanupSocketOnly() {
    try {
      _socket?.clearListeners();
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }

  void disposeService() {
    disconnect();
    _activeUserId = '';

    _connectCtrl.close();
    _disconnectCtrl.close();
    _connectErrorCtrl.close();
    _errorCtrl.close();
    _roomCreatedCtrl.close();
    _roomsListCtrl.close();
    _requestsListCtrl.close();
    _requestAcceptedCtrl.close();
    _requestRejectedCtrl.close();
    _requestBlockedCtrl.close();
    _messagesListCtrl.close();
    _newMessageCtrl.close();
    _newSnapCtrl.close();
    _messageDeliveredCtrl.close();
    _messageReadCtrl.close();
    _typingStartCtrl.close();
    _typingStopCtrl.close();
    _userTypingCtrl.close();
    _snapSentCtrl.close();
    _snapViewedCtrl.close();
    _contentSharedToChatsCtrl.close();
  }
}
