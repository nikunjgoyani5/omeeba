import 'dart:async';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/repository/post_repository.dart';
import 'package:omeeba_new/core/services/socket_service.dart';
import 'package:omeeba_new/presentation/main/chat/controller/chat_controller.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_model.dart';
import 'package:omeeba_new/presentation/main/chat/models/api_message_model.dart';

import '../../../../core/utils/app_prefrence.dart';

/// Custom scroll controller that restores scroll position during layout (before paint)
/// to avoid screen blink when paginating. Scroll notifications during restore are absorbed
/// in the view so AppBar does not call setState during frame.
class PaginationScrollController extends ScrollController {
  PaginationScrollController({super.initialScrollOffset, super.keepScrollOffset, super.debugLabel});

  bool _restorePending = false;
  double _savedScrollPixels = 0;
  double _savedMaxScrollExtent = 0;

  /// True only during the jumpTo() call in applyRestoreScrollIfPending.
  /// View uses this to absorb ScrollNotifications and avoid "Build scheduled during frame".
  bool isRestoringScrollPosition = false;

  void scheduleRestoreScroll(double pixels, double maxExtent) {
    _restorePending = true;
    _savedScrollPixels = pixels;
    _savedMaxScrollExtent = maxExtent;
  }

  void applyRestoreScrollIfPending(ScrollPosition position) {
    if (!_restorePending || !position.hasContentDimensions) return;
    final addedHeight = position.maxScrollExtent - _savedMaxScrollExtent;
    final targetOffset = (_savedScrollPixels + addedHeight).clamp(0.0, position.maxScrollExtent);
    _restorePending = false;
    // [jumpTo] must not run during [RenderViewport.performLayout] — it notifies listeners and
    // re-dirties layout. Defer to the next frame after layout completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!position.hasContentDimensions) return;
      final clamped = targetOffset.clamp(0.0, position.maxScrollExtent);
      isRestoringScrollPosition = true;
      position.jumpTo(clamped);
      isRestoringScrollPosition = false;
    });
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    return _RestorableScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
      restorableController: this,
    );
  }
}

class _RestorableScrollPosition extends ScrollPositionWithSingleContext {
  _RestorableScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
    required this.restorableController,
  });

  final PaginationScrollController restorableController;

  @override
  void applyNewDimensions() {
    super.applyNewDimensions();
    restorableController.applyRestoreScrollIfPending(this);
  }
}

class ChatDetailsController extends GetxController {
  final TextEditingController messageController = TextEditingController();
  final SocketService socketService = SocketService.instance;

  ChatModel? chatModel;
  RxList<MessageData> messages = <MessageData>[].obs;
  final Map<String, GlobalKey> _messageKeyCache = {};

  RxBool isSocketConnected = false.obs;
  RxString currentRoomId = ''.obs;
  RxBool isOtherUserTyping = false.obs;
  RxBool isLoadingMessages = false.obs;
  RxInt currentPage = 1.obs;
  RxBool hasMoreMessages = true.obs;
  RxBool isRequest = false.obs;

  /// Backend `requestStatus` for this chat (e.g. `pending`, `accepted`, etc).
  RxString requestStatus = ''.obs;

  /// Shows pending-request info above the message input.
  RxBool showPendingSentToast = false.obs;

  Timer? _typingTimer;
  Timer? _scrollAfterImageLoadTimer;

  // Subscriptions
  StreamSubscription? _connectSub;
  StreamSubscription? _connectErrorSub;
  StreamSubscription? _disconnectSub;
  StreamSubscription? _roomCreatedSub;
  StreamSubscription? _messagesListSub;
  StreamSubscription? _newMessageSub;
  StreamSubscription? _newSnapSub;
  StreamSubscription? _deliveredSub;
  StreamSubscription? _readSub;
  StreamSubscription? _typingStartSub;
  StreamSubscription? _typingStopSub;
  StreamSubscription? _userTypingSub;
  StreamSubscription? _acceptMessageSub;
  StreamSubscription? _blockMessageSub;
  StreamSubscription? _rejectMessageSub;

  @override
  void onInit() {
    super.onInit();
    isLoadingMessages.value = true;
    chatModel = Get.arguments['chat'];
    isRequest.value = Get.arguments['isRequest'] ?? false;

    // Socket is already connected by DashboardController on login. Do not reconnect here.
    _connectSub = socketService.onConnectStream.listen((_) {
      isSocketConnected.value = true;
      _createRoomForChat();
    });

    _disconnectSub = socketService.onDisconnectStream.listen((_) {
      isSocketConnected.value = false;
    });
    _connectErrorSub = socketService.onConnectErrorStream.listen((_) {
      isSocketConnected.value = false;
      isLoadingMessages.value = false;
      print('====*** socket not connected ');
    });
    _roomCreatedSub = socketService.onRoomCreatedStream.listen((data) {
      if (data != null && data['success'] == true) {
        final roomId = data['data']?['roomId']?.toString() ?? '';
        currentRoomId.value = roomId;
        currentPage.value = 1;
        hasMoreMessages.value = true;
        messages.clear();
        fetchMessages();
      }
    });

    _messagesListSub = socketService.onMessagesListStream.listen(_handleMessagesList);

    _newMessageSub = socketService.onNewMessageStream.listen(_handleNewMessage);

    _deliveredSub = socketService.onMessageDeliveredStream.listen(_handleDelivered);
    _readSub = socketService.onMessageReadStream.listen(_handleRead);
    _newSnapSub = socketService.onNewSnapStream.listen(_handleRoomNewSnap);
    _typingStartSub = socketService.onTypingStartStream.listen(_handleTypingStart);
    _typingStopSub = socketService.onTypingStopStream.listen(_handleTypingStop);
    _acceptMessageSub = socketService.onRequestAcceptedStream.listen(acceptRequestHandle);
    _blockMessageSub = socketService.onRequestBlockedStream.listen(blockRequestHandle);
    _rejectMessageSub = socketService.onRequestRejectedStream.listen(rejectRequestHandle);

    _userTypingSub = socketService.onUserTypingStream.listen((data) {
      // If your backend sends user_typing with roomId + isTyping
      final rid = (data is Map) ? data['roomId']?.toString() : null;
      if (rid == currentRoomId.value) {
        isOtherUserTyping.value = (data['isTyping'] == true);
        scrollToBottom();
      }
    });

    // If already connected, create room immediately
    if (socketService.isConnected) {
      isSocketConnected.value = true;
      _createRoomForChat();
    }

    mainScrollController.addListener(_updateScrollToBottomFABVisibility);
  }

  void _updateScrollToBottomFABVisibility() {
    final pos = _safePrimaryScrollPosition();
    if (pos == null) return;
    // In reverse list, pixels=0 is the latest (bottom).
    // We show the FAB if the user has scrolled up away from the latest messages.
    final shouldShow = pos.pixels > _scrollToBottomFABThreshold;
    if (showScrollToBottomFAB.value != shouldShow) {
      showScrollToBottomFAB.value = shouldShow;
    }
  }

  void _createRoomForChat() {
    if (chatModel?.userId == null || chatModel!.userId.isEmpty) return;
    socketService.createRoom(chatModel!.userId);
  }

  /// Pehle sirf ek page (page 1) ki API call hoti hai; user ko wahi dikhta hai.
  /// User jab upar scroll karega (past chat dekhne) tab loadMoreMessages() se page 2, 3... call hogi.
  void fetchMessages() {
    if (currentRoomId.value.isEmpty /*|| isLoadingMessages.value*/ ) return;
    isLoadingMessages.value = true;
    socketService.getMessages(currentRoomId.value, page: currentPage.value, limit: 20);
  }

  void loadMoreMessages() {
    if (!hasMoreMessages.value || isLoadingMessages.value) return;
    final pos = _safePrimaryScrollPosition();
    if (pos != null && mainScrollController is PaginationScrollController) {
      (mainScrollController as PaginationScrollController).scheduleRestoreScroll(pos.pixels, pos.maxScrollExtent);
    }
    currentPage.value++;
    fetchMessages();
  }

  void _handleMessagesList(dynamic data) {
    try {
      final model = MessageModel.fromJson(data);
      if (model.success == true && model.data?.messages != null) {
        final statusRaw = data['data']?['requestStatus']?.toString();
        final status = statusRaw?.toLowerCase() ?? '';
        requestStatus.value = statusRaw?.toString() ?? requestStatus.value;

        // Update request overlay state based on backend status + who initiated the pending state.
        if (status == 'pending' &&
            (data['data']['messages']?.isNotEmpty ?? false) &&
            (data['data']['messages'].first['sender']['id'] != PrefService.getString(PrefKeys.userId))) {
          isRequest.value = true;
        } else {
          isRequest.value = false;
        }

        final list = model.data!.messages!;
        final pagination = model.data?.pagination;
        final totalPages = pagination?.totalPages;
        final limit = 20;

        if (currentPage.value == 1) {
          // Server can return [] briefly after the first send while persistence catches up.
          // Replacing the list would wipe optimistic temp_* rows — merge them back in.
          final optimistic = messages.where((m) => m.id?.startsWith('temp_') ?? false).toList();
          messages.value = list;
          for (final o in optimistic.reversed) {
            final hasServerCopy = messages.any(
              (m) => m.sender?.id == o.sender?.id && m.message == o.message && (o.message ?? '').toString().isNotEmpty,
            );
            if (!hasServerCopy) {
              messages.insert(0, o);
            }
          }
          messages.refresh();
          // Ensure the chat opens at the latest message (bottom), not at older messages at top.
          scrollToBottomInstant();
        } else {
          // Track existing message IDs to avoid duplicates
          final existingIds = messages.map((m) => m.id).toSet();
          final uniqueNewMessages = list.where((m) => !existingIds.contains(m.id)).toList();
          messages.addAll(uniqueNewMessages);
          // Scroll restore in PaginationScrollController.applyNewDimensions (same frame, no blink)
        }

        if (totalPages != null && currentPage.value >= totalPages) {
          hasMoreMessages.value = false;
        } else if (list.length < limit) {
          hasMoreMessages.value = false;
        }

        // Same as _handleNewMessage: if the newest message is ours and still pending, show the banner.
        _maybeShowPendingSentToastForLatestMessage();
      }
    } catch (_) {
    } finally {
      isLoadingMessages.value = false;
    }
  }

  /// Index 0 is always the latest message (see [messages.insert] in [_handleNewMessage]).
  void _maybeShowPendingSentToastForLatestMessage() {
    if (messages.isEmpty) return;
    final latest = messages.first;
    final currentUserId = PrefService.getString(PrefKeys.userId);
    final pending =
        (latest.requestStatus?.toLowerCase() == 'pending') || (requestStatus.value.toLowerCase() == 'pending');
    if (latest.sender?.id == currentUserId && pending) {
      _showPendingSentToast();
    }
  }

  void _handleNewMessage(dynamic data) {
    try {
      final rawMessage = Map<String, dynamic>.from((data['message'] ?? {}) as Map);

      // Backend sends requestStatus in `new_message` payload; attach it to MessageData.
      rawMessage['requestStatus'] = data['requestStatus'] ?? rawMessage['requestStatus'];
      final msg = MessageData.fromJson(rawMessage);

      requestStatus.value = msg.requestStatus?.toString() ?? requestStatus.value;
      // Remove any temporary messages with ID "1", starting with 'temp_', or matching duplicate ID
      messages.removeWhere((m) => m.id == "1" || (m.id?.startsWith('temp_') ?? false) || m.id == msg.id);
      // Only add if belongs to current room
      if (msg.roomId == currentRoomId.value) {
        messages.insert(0, msg);
        scrollToBottom();

        _maybeShowPendingSentToastForLatestMessage();
      }

      Get.find<ChatController>().fetchChatRoomList();
    } catch (_) {}
  }

  // void _handleDelivered(dynamic data) {
  //   final messageId = (data is Map) ? data['messageId']?.toString() : null;
  //   if (messageId == null) return;
  //   final idx = messages.indexWhere((m) => m.id == messageId);
  //   if (idx != -1) {
  //     messages[idx].status = 'delivered';
  //     messages.refresh();
  //   }
  // }

  void _handleDelivered(dynamic data) {
    print("DELIVERED EVENT: $data");

    if (data == null) return;

    final messageId = data['messageId']?.toString() ?? data['data']?['messageId']?.toString();

    if (messageId == null) return;

    final index = messages.indexWhere((m) => m.id == messageId);

    if (index != -1) {
      messages[index].status = 'delivered';
      messages.refresh();
    } else {
      print("⚠️ Delivered message not found locally: $messageId");
    }
  }

  void _handleRead(dynamic data) {
    if (data == null) return;
    // Support multiple payload shapes: messageId, data.messageId, lastReadMessageId
    final messageId =
        data['messageId']?.toString() ??
        data['data']?['messageId']?.toString() ??
        data['lastReadMessageId']?.toString() ??
        data['data']?['lastReadMessageId']?.toString();
    if (messageId == null || messageId.isEmpty) return;
    // Only update if event is for current room (if server sends roomId)
    final roomId = data['roomId']?.toString() ?? data['data']?['roomId']?.toString();
    if (roomId != null && roomId.isNotEmpty && roomId != currentRoomId.value) return;

    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      // Mark this message and all older messages (higher index = older, since 0 = newest) as read
      for (int i = idx; i < messages.length; i++) {
        // messages[i].status = 'read';
      }
      messages.refresh();
    } else {
      print("⚠️ messages_read: message not found in list. messageId=$messageId, currentRoom=${currentRoomId.value}");
    }
  }

  void onTypingStarted() {
    _typingTimer?.cancel();
    if (currentRoomId.value.isNotEmpty) {
      socketService.sendTypingStart(currentRoomId.value);
    }
    _typingTimer = Timer(const Duration(seconds: 2), onTypingStopped);
  }

  void onTypingStopped() {
    if (currentRoomId.value.isNotEmpty) {
      socketService.sendTypingStop(currentRoomId.value);
    }
  }

  void onMessageChanged() {
    if (messageController.text.trim().isNotEmpty) {
      onTypingStarted();
    }
  }

  void sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    onTypingStopped();

    final pending = requestStatus.value.toLowerCase() == 'pending';
    messages.insert(
      0,
      MessageData(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        roomId: currentRoomId.value,
        sender: Sender(id: PrefService.getString(PrefKeys.userId), name: " ", username: " "),
        messageType: "Text",
        message: text,
        requestStatus: pending ? 'pending' : null,
      ),
    );
    messages.refresh();
    messageController.clear();
    _maybeShowPendingSentToastForLatestMessage();
    if (currentRoomId.value.isNotEmpty) {
      socketService.sendMessage(currentRoomId.value, 'Text', text);
      // Auto-scroll to bottom when message is sent
      scrollToBottom();
    }
  }

  void _showPendingSentToast() {
    if (showPendingSentToast.value) return;
    showPendingSentToast.value = true;
  }

  void dismissPendingSentToast() {
    showPendingSentToast.value = false;
  }

  void acceptMessageRequest() {
    isRequest.value = false;
    if (currentRoomId.value.isNotEmpty) socketService.acceptRequest(currentRoomId.value);
  }

  void rejectMessageRequest() {
    // isRequest.value = false;
    if (currentRoomId.value.isNotEmpty) socketService.rejectRequest(currentRoomId.value);
    Get.back();
  }

  void blockMessageRequest() {
    isRequest.value = false;
    if (currentRoomId.value.isNotEmpty) socketService.blockRequest(currentRoomId.value);
  }

  void viewSnap(String snapId) {
    final chatController = Get.find<ChatController>();
    socketService.viewSnap(snapId);
    final index = messages.indexWhere((m) => m.id == snapId);
    if (index != -1) {
      final message = messages[index];

      message.status = 'seen';
      chatController.viewSnap(snapId);

      final roomIndex = chatController.roomList.indexWhere((e) => e.id == currentRoomId.value);

      if (roomIndex != -1) {
        final room = chatController.roomList[roomIndex];
        room.lastMessageStatus = 'byte';
        room.unreadCount = 0;
        update();
      }

      messages.refresh();
    }
    // socketService.getRooms();
  }

  void _handleTypingStart(dynamic data) {
    final rid = (data is Map) ? data['roomId']?.toString() : data?.toString();
    if (rid == currentRoomId.value) isOtherUserTyping.value = true;
  }

  /// Real-time snap from socket `new_snap` — same shape as [new_message] for list UX.
  void _handleRoomNewSnap(dynamic data) {
    if (data is! Map || currentRoomId.value.isEmpty) return;
    try {
      final snapRaw = data['message'];
      if (snapRaw is! Map) return;

      final raw = Map<String, dynamic>.from(snapRaw);
      final roomId = raw['roomId']?.toString() ?? '';
      if (roomId != currentRoomId.value) return;
      raw['roomId'] = roomId;
      final msg = MessageData.fromJson(raw);
      messages.insert(0, msg);
      messages.refresh();
      scrollToBottom();
      _maybeShowPendingSentToastForLatestMessage();
      Get.find<ChatController>().fetchChatRoomList();
      Get.find<ChatController>().readMessage(messageId: msg.id ?? '', roomID: msg.roomId ?? '');
    } catch (e) {
      debugPrint("NEW SNAP SOCKET ERROR: $e");
    }
  }

  void _handleTypingStop(dynamic data) {
    final rid = (data is Map) ? data['roomId']?.toString() : data?.toString();
    if (rid == currentRoomId.value) isOtherUserTyping.value = false;
  }

  void acceptRequestHandle(dynamic data) {
    socketService.getRooms();
    socketService.getRequests();
  }

  void blockRequestHandle(dynamic data) {
    socketService.getRooms();
    socketService.getRequests();
  }

  void rejectRequestHandle(dynamic data) {
    socketService.getRooms();
    socketService.getRequests();
  }

  @override
  void onClose() {
    messageController.dispose();
    _typingTimer?.cancel();
    _scrollAfterImageLoadTimer?.cancel();
    _messageKeyCache.clear();
    _connectSub?.cancel();
    _connectErrorSub?.cancel();
    _disconnectSub?.cancel();
    _roomCreatedSub?.cancel();
    _messagesListSub?.cancel();
    _newSnapSub?.cancel();
    _newMessageSub?.cancel();
    _deliveredSub?.cancel();
    _readSub?.cancel();
    _typingStartSub?.cancel();
    _typingStopSub?.cancel();
    _acceptMessageSub?.cancel();
    _userTypingSub?.cancel();
    _rejectMessageSub?.cancel();
    _blockMessageSub?.cancel();

    mainScrollController.removeListener(_updateScrollToBottomFABVisibility);
    mainScrollController.dispose();

    // IMPORTANT: yaha socketService.disconnect() nahi karna
    super.onClose();
  }

  // -------------------- UI State --------------------

  /// Unified scroll controller for pagination + auto-scroll + FAB visibility.
  late ScrollController mainScrollController = PaginationScrollController();

  /// WhatsApp-style: show down-arrow FAB when user has scrolled up (above latest messages).
  RxBool showScrollToBottomFAB = false.obs;
  static const double _scrollToBottomFABThreshold = 120.0;

  RxString? selectedMessageId = RxString('');
  GlobalKey? selectedMessageKey;
  Widget? selectedWidget;

  RxBool isContextMenuVisible = false.obs;
  RxBool isSelectedSender = false.obs;
  MessageData? messageData;

  /// Get or create a GlobalKey for a message (cached for performance)
  GlobalKey getMessageKey(String messageId) {
    if (messageId.isEmpty) {
      return GlobalKey();
    }
    if (!_messageKeyCache.containsKey(messageId)) {
      _messageKeyCache[messageId] = GlobalKey();
    }
    return _messageKeyCache[messageId]!;
  }

  void hideContextMenu() {
    isContextMenuVisible.value = false;
    selectedMessageId?.value = '';
    selectedMessageKey = null;
    selectedWidget = null;
    messageData = null;
  }

  void onMessageLongPress({
    required String messageId,
    required MessageData data,
    required GlobalKey messageKey,
    required Widget widget,
    required bool isSender,
  }) {
    selectedMessageId?.value = messageId;
    selectedMessageKey = messageKey;
    selectedWidget = widget;
    isSelectedSender.value = isSender;
    isContextMenuVisible.value = true;
    messageData = data;
  }

  void copyMessage() {
    if (selectedMessageId?.value == null || selectedMessageId!.value.isEmpty) return;

    final message = messages.firstWhere(
      (m) => m.id == selectedMessageId!.value,
      orElse: () => MessageData(id: '', roomId: '', sender: null, messageType: '', message: ''),
    );

    if (message.message != null) {
      Clipboard.setData(ClipboardData(text: message.message!));
    }

    hideContextMenu();
  }

  Future<void> deleteMessage() async {
    if (selectedMessageId?.value == null || selectedMessageId!.value.isEmpty) {
      return;
    }

    await deleteSingleMessage(roomId: currentRoomId.value, messageId: selectedMessageId!.value);
    messages.removeWhere((m) => m.id == selectedMessageId!.value);
    hideContextMenu();
  }

  PostRepository postRepository = PostRepository();

  Future<void> deleteSingleMessage({required String roomId, required String messageId}) async {
    postRepository.deleteSingleMessageAPI(
      messageId: messageId,
      roomId: roomId,
      onSuccess: (data) {},
      onError: (error) {},
    );
  }

  // -------------------- Auto Scroll (smooth) --------------------
  static const _scrollDuration = Duration(milliseconds: 280);
  static const _scrollCurve = Curves.easeOutCubic;

  /// Naya message aate/bhejne par — ek hi smooth animation.
  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mainScrollController.hasClients) return;
        // In reverse list, 0.0 is the latest messages (bottom)
        mainScrollController.animateTo(0.0, duration: _scrollDuration, curve: _scrollCurve);
      });
    });
  }

  void _jumpToBottom() {
    if (!mainScrollController.hasClients) return;
    mainScrollController.jumpTo(0.0);
  }

  /// onlyIfNearBottom = true → scroll sirf jab user bottom ke kareeb ho.
  void _scrollToBottomIf(bool onlyIfNearBottom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pos = _safePrimaryScrollPosition();
      if (pos == null) return;
      // pos.pixels is the offset from the bottom in a reverse list
      if (onlyIfNearBottom && pos.pixels > 350) return;
      _jumpToBottom();
    });
  }

  ScrollPosition? _safePrimaryScrollPosition() {
    if (!mainScrollController.hasClients) return null;
    final positions = mainScrollController.positions;
    if (positions.isEmpty) return null;
    return positions.last;
  }

  /// Image load par — debounce, ek hi scroll (sirf jab user niche ho).
  void scrollAfterImageLoad() {
    _scrollAfterImageLoadTimer?.cancel();
    _scrollAfterImageLoadTimer = Timer(const Duration(milliseconds: 180), () {
      _scrollToBottomIf(true);
    });
  }

  /// Pehli baar list load — ek jump, 450ms baad image ke liye ek aur.
  void scrollToBottomInstant() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToBottom();
        Future.delayed(const Duration(milliseconds: 450), _jumpToBottom);
      });
    });
  }
}
