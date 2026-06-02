
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/presentation/main/chat/controller/chat_controller.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_room_model.dart';
import 'package:omeeba_new/presentation/main/take_snap/controller/take_snap_controller.dart';

import '../../../../core/services/socket_service.dart';

class SendToBottomSheet extends StatefulWidget {
  const SendToBottomSheet({super.key, required this.mediaId});

  final String mediaId;

  @override
  State<SendToBottomSheet> createState() => _SendToBottomSheetState();
}

class _SendToBottomSheetState extends State<SendToBottomSheet> {
  final TakeSnapController controller = Get.find<TakeSnapController>();
  RxList<String> selectedUsers = <String>[].obs;
  RxBool isSending = false.obs;
  RxBool isSendButtonPressed = false.obs;
  TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    initializeSocketConnection();
    controller.fetchChatRoomList(reset: true);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      controller.loadMoreChatRooms();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * 0.8,
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.h),
            height: 5.w,
            width: 55.w,
            decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
          ),
          Gap(16.h),
          _buildAppBar(),
          Gap(16.h),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(onTap: () => Get.back(), child: Assets.icons.icArrowBack.image(height: 20)),
          Text('Send To...', style: TextStyles.semiBold(20.sp, fontColor: AppColors.black2F3039)),
          Obx(() {
            final canSend = selectedUsers.isNotEmpty && !isSending.value;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8.r),
                splashColor: AppColors.primaryColor.withValues(alpha: 0.14),
                highlightColor: AppColors.primaryColor.withValues(alpha: 0.08),
                onHighlightChanged: (isPressed) => isSendButtonPressed.value = isPressed,
                onTap: canSend ? sendSnap : null,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 110),
                  scale: isSendButtonPressed.value ? 0.96 : 1.0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: isSending.value
                          ? Row(
                              key: const ValueKey('sending_state'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                                  ),
                                ),
                                Gap(8.w),
                                Text(
                                  'Sending...',
                                  style: TextStyles.semiBold(20.sp, fontColor: AppColors.primaryColor),
                                ),
                              ],
                            )
                          : Text(
                              'Send',
                              key: const ValueKey('send_state'),
                              style: TextStyles.semiBold(
                                20.sp,
                                fontColor: selectedUsers.isNotEmpty ? AppColors.primaryColor : AppColors.gray707070,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return Obx(() {
      if (controller.loading.value && controller.roomList.isEmpty) {
        return _buildShimmerLoading();
      }

      if (controller.roomList.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 50.sp, color: AppColors.gray707070),
              Gap(10.h),
              Text('No users found', style: TextStyles.medium(16.sp, fontColor: AppColors.gray707070)),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: controller.roomList.length + (controller.otherLoading.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == controller.roomList.length && controller.otherLoading.value) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                ),
              ),
            );
          }
          if (index >= controller.roomList.length) return const SizedBox.shrink();
          final room = controller.roomList[index];
          return _buildUserItem(room, index);
        },
      );
    });
  }

  Widget _buildUserItem(RoomData room, int index) {
    return Obx(() {
      final isSelected = selectedUsers.contains(room.otherUser?.id ?? '');

      return Container(
        decoration: BoxDecoration(),
        child: ListTile(
          onTap: () {
            if (isSelected) {
              selectedUsers.remove(room.otherUser?.id ?? '');
            } else {
              selectedUsers.add(room.otherUser?.id ?? '');
            }
          },
          contentPadding: EdgeInsets.symmetric(horizontal: 15.w),
          leading: CommonProfileImage(
            imageUrl: room.otherUser?.profileImage?.toString(),
            width: 50.w,
            height: 50.w,
          ),
          title: Text(
            room.otherUser?.name ?? 'Unknown',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
          ),
          subtitle: Text(
            '@${room.otherUser?.username ?? 'unknown'}',
            style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
          ),
          trailing: CommonCheckBox(
            onChanged: (value) {
              if (isSelected) {
                selectedUsers.remove(room.otherUser?.id ?? '');
              } else {
                selectedUsers.add(room.otherUser?.id ?? '');
              }
            },
            value: isSelected,
          ),
        ),
      );
    });
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 15.h),
          padding: EdgeInsets.all(15.w),
          decoration: BoxDecoration(color: AppColors.whiteFFFFFF, borderRadius: BorderRadius.circular(12.r)),
          child: Row(
            children: [
              _buildShimmerCircle(),
              Gap(15.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerLine(width: 120.w),
                    Gap(8.h),
                    _buildShimmerLine(width: 80.w),
                  ],
                ),
              ),
              _buildShimmerCircle(size: 24.w),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerCircle({double? size}) {
    return Container(
      width: size ?? 50.w,
      height: size ?? 50.w,
      decoration: BoxDecoration(color: AppColors.grayEAEAEA, shape: BoxShape.circle),
    );
  }

  Widget _buildShimmerLine({required double width}) {
    return Container(
      width: width,
      height: 16.h,
      decoration: BoxDecoration(color: AppColors.grayEAEAEA, borderRadius: BorderRadius.circular(4.r)),
    );
  }

  SocketService socketService = SocketService.instance;

  void sendSnap() {
    if (isSending.value || selectedUsers.isEmpty) return;
    isSending.value = true;
    print('Sending to users: ${selectedUsers.toList()}');
    print('sending snap to  users');
    socketService.sendSnap({
      "mediaId": widget.mediaId,
      "recipientIds": selectedUsers.toList() /*, "expiresInSeconds": "not"*/,
    });
  }

  Future<void> onSnapSendEventRecieved(dynamic data) async {
    isSending.value = false;
    Get.find<ChatController>().page.value = 1;
    Get.find<ChatController>().roomList.clear();
    Get.back();
    Get.back();
    socketService.getRooms();
  }

  void initializeSocketConnection() {
    socketService.onSnapSent = (data) {
      print('snap sent received: $data');
      onSnapSendEventRecieved(data);
    };
    socketService.onConnect = () {
      print('Socket connected successfully');
    };
    socketService.onDisconnect = () {
      print('Socket disconnected');
    };
    socketService.connect(PrefService.getString(PrefKeys.userId));
  }
}
