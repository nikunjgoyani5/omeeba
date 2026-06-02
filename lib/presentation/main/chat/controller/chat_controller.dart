import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/services/socket_service.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_request_model.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_room_model.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_model.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/presentation/main/take_snap/views/take_snap_screen.dart';

import '../models/api_message_model.dart';

class ChatController extends GetxController {
  final SocketService socketService = SocketService.instance;

  static const Duration _searchDebounceDuration = Duration(milliseconds: 400);
  Timer? _searchDebounce;

  TextEditingController searchController = TextEditingController();
  ScrollController scrollController = ScrollController();
  ScrollController requestScrollController = ScrollController();

  RxBool isMessageTab = true.obs;
  RxBool isSearchMode = false.obs;

  RxBool loading = false.obs;
  RxBool requestLoading = false.obs;
  RxBool otherLoading = false.obs;
  RxBool otherRequestLoading = false.obs;

  RxInt page = 1.obs;
  RxInt requestPage = 1.obs;

  List<RoomData> roomList = [];
  List<ChatRequest> chatRequestList = [];

  /// After the first successful [rooms_list] / [requests_list], avoid full-screen shimmer on background refreshes.
  bool _roomsListHasBeenLoaded = false;
  bool _requestsListHasBeenLoaded = false;

  ChatRoomModel chatRoomModel = ChatRoomModel();
  ChatRequestModel chatRequestModel = ChatRequestModel();

  StreamSubscription? _roomsSub;
  StreamSubscription? _reqSub;
  StreamSubscription? _connectSub;
  StreamSubscription? _newMessageSub;
  StreamSubscription? _newSnapSub;
  StreamSubscription? _deliveredSub;
  StreamSubscription? _readSub;
  StreamSubscription? _snapViewedSub;

  @override
  void onInit() {
    super.onInit();

    // Socket is already connected by DashboardController on login. Do not reconnect here.
    _newMessageSub = socketService.onNewMessageStream.listen(
      _handleRoomNewMessage,
    );
    _newSnapSub = socketService.onNewSnapStream.listen(_handleRoomNewSnap);
    _deliveredSub = socketService.onMessageDeliveredStream.listen(
      _handleMessageDelivered,
    );
    _readSub = socketService.onMessageReadStream.listen(_handleMessageRead);
    _snapViewedSub = socketService.onSnapViewedStream.listen(_handleSnapViewed);

    _connectSub = socketService.onConnectStream.listen((_) {
      if (isMessageTab.value) {
        refreshMessages();
      } else {
        refreshRequests();
      }
    });

    _roomsSub = socketService.onRoomsListStream.listen((data) {
      if (data != null && data['success'] == true) {
        chatRoomModel = ChatRoomModel.fromJson(data);
        if (page.value == 1) roomList.clear();
        roomList.addAll(chatRoomModel.data?.rooms ?? []);
        _roomsListHasBeenLoaded = true;
      }
      loading.value = false;
      otherLoading.value = false;
      update();
    });

    _reqSub = socketService.onRequestsListStream.listen((data) {
      if (data != null && data['success'] == true) {
        chatRequestModel = ChatRequestModel.fromJson(data);
        if (requestPage.value == 1) chatRequestList.clear();
        chatRequestList.addAll(chatRequestModel.data?.requests ?? []);
        _requestsListHasBeenLoaded = true;
      }
      requestLoading.value = false;
      otherRequestLoading.value = false;
      update();
    });

    // Initial fetch: messages tab only; requests load when user opens that tab
    fetchChatRoomList();

    // Pagination listeners
    scrollController.addListener(_onMessagesScroll);
    requestScrollController.addListener(_onRequestsScroll);

    searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(_searchDebounceDuration, () {
        if (isMessageTab.value) {
          page.value = 1;
          fetchChatRoomList(showListLoading: !_roomsListHasBeenLoaded);
        } else {
          requestPage.value = 1;
          fetchChatRequestList(showListLoading: !_requestsListHasBeenLoaded);
        }
      });
    });
  }
  void _handleRoomNewMessage(dynamic data) {
    // print("CHAT LIST NEW_MESSAGE → $data");
    //
    // if (data == null) return;
    //
    // final messageObj = data['message'];
    // if (messageObj == null) return;
    //
    // final roomId = messageObj['roomId']?.toString();
    // final message = messageObj['message'] ?? '';
    // final timestamp = messageObj['timestamp'];
    // final status = messageObj['status'] ?? 'sent';   // 🔥 ADD THIS
    //
    // if (roomId == null || roomId.isEmpty) return;
    //
    // final index = roomList.indexWhere((room) => room.id?.toString() == roomId);
    //
    // if (index == -1) return;
    //
    // final room = roomList[index];
    //
    // // Update last message text
    // room.lastMessage = message;
    //
    // // Update timestamp
    // room.timestamp = timestamp;
    //
    // // 🔥 Update last message status
    // room.lastMessageStatus = status=='sent'? 'new': null;
    //
    // // Increase unread count (only if not current chat)
    // if (Get.currentRoute != AppRoutes.chatDetails) {
    //   room.unreadCount = (room.unreadCount ?? 0) + 1;
    // }
    //
    // // Move room to top
    // roomList.removeAt(index);
    // roomList.insert(0, room);
    //
    // update();

    refreshMessages();
    refreshRequests();
  }

  void _handleRoomNewSnap(dynamic data) {
    // print("CHAT LIST NEW_MESSAGE → $data");
    //
    // if (data == null) return;
    //
    // final messageObj = data['message'];
    // if (messageObj == null) return;
    //
    // final roomId = messageObj['roomId']?.toString();
    // final message = messageObj['message'] ?? '';
    // final timestamp = messageObj['timestamp'];
    // final status = messageObj['status'] ?? 'sent';   // 🔥 ADD THIS
    //
    // if (roomId == null || roomId.isEmpty) return;
    //
    // final index = roomList.indexWhere((room) => room.id?.toString() == roomId);
    //
    // if (index == -1) return;
    //
    // final room = roomList[index];
    //
    // // Update last message text
    // room.lastMessage = message;
    //
    // // Update timestamp
    // room.timestamp = timestamp;
    //
    // // 🔥 Update last message status
    // room.lastMessageStatus = status=='sent'? 'new': null;
    //
    // // Increase unread count (only if not current chat)
    // if (Get.currentRoute != AppRoutes.chatDetails) {
    //   room.unreadCount = (room.unreadCount ?? 0) + 1;
    // }
    //
    // // Move room to top
    // roomList.removeAt(index);
    // roomList.insert(0, room);
    //
    // update();

    refreshMessages();
    refreshRequests();
  }

  void _handleMessageDelivered(dynamic data) {
    refreshMessages();
    refreshRequests();
  }

  void _handleMessageRead(dynamic data) {
    refreshMessages();
    refreshRequests();
  }

  void _handleSnapViewed(dynamic data) {
    refreshMessages();
    refreshRequests();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _roomsSub?.cancel();
    _reqSub?.cancel();
    _connectSub?.cancel();
    searchController.dispose();
    scrollController.dispose();
    requestScrollController.dispose();
    _newMessageSub?.cancel();
    _newSnapSub?.cancel();
    _deliveredSub?.cancel();
    _readSub?.cancel();
    _snapViewedSub?.cancel();
    super.onClose();
  }

  void onMessagesTap(BuildContext context) {
    if (isMessageTab.value) return;
    isMessageTab.value = true;
    refreshMessages();
  }

  void onRequestsTap(BuildContext context) {
    if (!isMessageTab.value) return;
    isMessageTab.value = false;
    refreshRequests();
  }

  void onCameraTap() => Get.to(() => TakeSnapScreen());

  void onChatTap(RoomData roomData, bool isRequest) {
    final chatModel = ChatModel(
      id: roomData.id ?? '',
      userId: roomData.otherUser?.id ?? '',
      userName: roomData.otherUser?.name ?? 'Unknown',
      userProfileImage: roomData.otherUser?.profileImage?.toString() ?? '',
      lastMessage: roomData.lastMessage ?? '',
      timestamp: roomData.timestamp ?? '',
      isVerifiedBeach: isRequest,
      followers: roomData.otherUser?.followersCount ?? 0,
      isUnread: (roomData.unreadCount ?? 0) > 0,
      messageType: MessageType.text,
    );

    Get.toNamed(
      AppRoutes.chatDetails,
      arguments: {'chat': chatModel, 'isRequest': false},
    );
  }

  void onChatRequestTap(ChatRequest req, bool isRequest) {
    final chatModel = ChatModel(
      id: req.id ?? '',
      userId: req.otherUser?.id ?? '',
      userName: req.otherUser?.name ?? 'Unknown',
      userProfileImage: req.otherUser?.profileImage?.toString() ?? '',
      lastMessage: req.lastMessage ?? '',
      timestamp: req.timestamp ?? '',
      isVerifiedBeach: isRequest,
      followers: req.otherUser?.followersCount ?? 0,
      isUnread: (req.unreadCount ?? 0) > 0,
      messageType: MessageType.text,
    );

    Get.toNamed(
      AppRoutes.chatDetails,
      arguments: {'chat': chatModel, 'isRequest': false},
    );
  }

  /// [showListLoading]: full-screen shimmer (only for first load or pull-to-refresh when list was empty).
  void fetchChatRoomList({bool showListLoading = true}) {
    if (page.value == 1 && showListLoading) loading.value = true;
    socketService.getRooms(
      page: page.value,
      limit: 20,
      search: searchController.text.trim(),
    );
  }

  void fetchChatRequestList({bool showListLoading = true}) {
    if (requestPage.value == 1 && showListLoading) requestLoading.value = true;
    socketService.getRequests(
      page: requestPage.value,
      limit: 20,
      search: searchController.text.trim(),
    );
  }

  /// When [silent] is null, uses [_roomsListHasBeenLoaded] / [_requestsListHasBeenLoaded] so the first load
  /// can show shimmer; later refreshes stay quiet. Pass `silent: false` to force full reload + shimmer.
  Future<void> refreshMessages({bool? silent}) async {
    final useSilent = silent ?? _roomsListHasBeenLoaded;
    page.value = 1;
    if (!useSilent) {
      roomList.clear();
      loading.value = true;
    }
    fetchChatRoomList(showListLoading: !useSilent);
  }

  Future<void> refreshRequests({bool? silent}) async {
    final useSilent = silent ?? _requestsListHasBeenLoaded;
    requestPage.value = 1;
    if (!useSilent) {
      chatRequestList.clear();
      requestLoading.value = true;
    }
    fetchChatRequestList(showListLoading: !useSilent);
  }

  void loadMoreData() {
    if (!otherLoading.value) {
      otherLoading.value = true;
      page.value++;
      fetchChatRoomList(showListLoading: false);
    }
  }

  void loadMoreRequestData() {
    if (!otherRequestLoading.value) {
      otherRequestLoading.value = true;
      requestPage.value++;
      fetchChatRequestList(showListLoading: false);
    }
  }

  void _onMessagesScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 50) {
      chatRoomModel.pagination!.hasNext == true ? loadMoreData() : null;
    }
  }

  void _onRequestsScroll() {
    if (requestScrollController.position.pixels >=
        requestScrollController.position.maxScrollExtent - 50) {
      loadMoreRequestData();
    }
  }

  void readMessage({required String messageId, required String roomID}) {
    socketService.readLastMessage({
      "roomId": roomID,
      "lastReadMessageId": messageId,
    });
  }

  void viewSnap(String snapId) {
    socketService.viewSnap(snapId);
  }

  RxBool isDeleteMode = false.obs;
  RxString? selectedChatId = RxString('');
  GlobalKey? selectedChatKey;

  void onChatLongPress(String chatId, GlobalKey chatKey) {
    selectedChatId?.value = chatId;
    selectedChatKey = chatKey;
    isDeleteMode.value = true;
  }

  void hideDeleteMode() {
    isDeleteMode.value = false;
    selectedChatId?.value = '';
    selectedChatKey = null;
  }

  // void deleteChat(String? chatId) {
  //   if (chatId == null) return;
  //
  //   roomList.removeWhere((c) => c.id == chatId);
  //   socketService.deleteRoom({
  //     "roomId": c,
  //   });
  //   hideDeleteMode();
  //   update();
  // }
  void deleteChat(String? chatId) {
    if (chatId == null) return;

    final index = roomList.indexWhere((c) => c.id == chatId);

    if (index != -1) {
      final matchedRoom = roomList[index];

      socketService.deleteRoom({"roomId": matchedRoom.roomId ?? ""});

      roomList.removeAt(index);
    }

    hideDeleteMode();
    update();
  }

  void deleteSelectedChat() {
    if (selectedChatId?.value == null || selectedChatId!.value.isEmpty) return;

    deleteChat(selectedChatId!.value);
  }
}
