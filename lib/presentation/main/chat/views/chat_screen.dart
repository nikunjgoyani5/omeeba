import 'dart:math' as math;
import 'dart:ui';

import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/presentation/main/chat/controller/chat_controller.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_model.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_request_model.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_room_model.dart';
import 'package:omeeba_new/presentation/main/chat/widgets/chat_shimmer.dart';
import 'package:omeeba_new/presentation/main/take_snap/views/view_snap.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatController controller = Get.put(ChatController());

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(75.h),
      child: Obx(
        () => AppBar(
          leading: controller.isSearchMode.value
              ? const SizedBox()
              : IconButton(onPressed: () => Get.back(), icon: Image.asset(Assets.icons.icArrowBack.path, scale: 3.5)),
          surfaceTintColor: AppColors.whiteFFFFFF,
          backgroundColor: AppColors.white,
          toolbarHeight: 75.h,
          leadingWidth: controller.isSearchMode.value ? 0 : 40.w,
          titleSpacing: 0,
          title: controller.isSearchMode.value
              ? ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller.searchController,
                  builder: (context, value, child) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: CommonSearchTextField(
                        autofocus: true,
                        prefixIcon: Padding(
                          padding: EdgeInsetsGeometry.only(left: 10),
                          child: Assets.icons.icSearch.svg(
                            colorFilter: ColorFilter.mode(AppColors.g707070ray, BlendMode.srcIn),
                          ),
                        ),
                        suffixIcon: InkWell(
                          onTap: () {
                            controller.searchController.clear();
                            controller.isSearchMode.value = false;
                          },
                          child: Padding(
                            padding: EdgeInsetsGeometry.only(right: 10),
                            child:  Icon(Icons.close, color: AppColors.g707070ray, size: 27),
                          ),
                        ),
                        controller: controller.searchController,
                        hintText: 'Search',
                      ),
                    );
                  },
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Chat', style: TextStyles.semiBold(20.sp)),
                    Spacer(),
                    PressScaleButton(
                      onTap: () {
                        controller.isSearchMode.value = true;
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        child: Assets.icons.icSearch.svg(),
                      ),
                    ),
                  ],
                ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1.h),
            child: controller.isSearchMode.value ? const SizedBox() : Container(height: 1, color: AppColors.grayEAEAEA),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            GetBuilder<ChatController>(
              builder: (controller) {
                return Column(
                  children: [
                    Obx(() {
                      return controller.isMessageTab.value
                          ? Expanded(
                              child: Obx(
                                () => RefreshIndicator(
                                  color: AppColors.primaryColor,
                                  onRefresh: () => controller.refreshMessages(),
                                  child: controller.loading.value && controller.roomList.isEmpty
                                      ? ChatListShimmer()
                                      : controller.roomList.isEmpty
                                      ? Center(
                                          child: SingleChildScrollView(
                                            physics: const AlwaysScrollableScrollPhysics(),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                ClipOval(
                                                  child: Container(
                                                    height: 100.h,
                                                    width: 100.h,
                                                    decoration: BoxDecoration(color: AppColors.grayEDF1F4),
                                                    alignment: Alignment.center,
                                                    child: Wrap(
                                                      children: [
                                                        Assets.icons.icChatFilled.svg(height: 55.h, width: 55.h),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Text('No message requests.', style: TextStyles.semiBold(22.sp)),
                                                Text(
                                                  "You don't have any message requests.",
                                                  style: TextStyles.regular(15.sp, fontColor: AppColors.g707070ray),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Scrollbar(
                                          controller: controller.scrollController,
                                          thumbVisibility: true,
                                          child: ListView.separated(
                                            physics: const AlwaysScrollableScrollPhysics(),
                                            controller: controller.scrollController,
                                            separatorBuilder: (context, index) => Gap(20.h),
                                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                            itemCount:
                                                controller.roomList.length + (controller.otherLoading.value ? 1 : 0),
                                            itemBuilder: (context, index) {
                                              if (index == controller.roomList.length &&
                                                  controller.otherLoading.value) {
                                                return const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(16.0),
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 3,
                                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                                                    ),
                                                  ),
                                                );
                                              }
                                              if (index >= controller.roomList.length) return const SizedBox.shrink();

                                              final chat = controller.roomList[index];
                                              return _buildChatItem(chat, index);
                                            },
                                          ),
                                        ),
                                ),
                              ),
                            )
                          : Expanded(
                              child: Obx(
                                () => RefreshIndicator(
                                  color: AppColors.primaryColor,
                                  onRefresh: () => controller.refreshRequests(),
                                  child: controller.requestLoading.value && controller.chatRequestList.isEmpty
                                      ? ChatListShimmer()
                                      : controller.chatRequestList.isEmpty
                                      ? Center(
                                          child: SingleChildScrollView(
                                            physics: const AlwaysScrollableScrollPhysics(),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                ClipOval(
                                                  child: Container(
                                                    height: 100.h,
                                                    width: 100.h,
                                                    decoration: BoxDecoration(color: AppColors.grayEDF1F4),
                                                    alignment: Alignment.center,
                                                    child: Wrap(
                                                      children: [
                                                        Assets.icons.icChatFilled.svg(height: 55.h, width: 55.h),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Text('No message requests.', style: TextStyles.semiBold(22.sp)),
                                                Text(
                                                  "You don't have any message requests.",
                                                  style: TextStyles.regular(15.sp, fontColor: AppColors.g707070ray),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Scrollbar(
                                          controller: controller.requestScrollController,
                                          interactive: true,
                                          thumbVisibility: true,
                                          child: ListView.separated(
                                            physics: const AlwaysScrollableScrollPhysics(),
                                            controller: controller.requestScrollController,
                                            separatorBuilder: (context, index) => Gap(20.h),
                                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                            itemCount:
                                                controller.chatRequestList.length +
                                                (controller.otherRequestLoading.value ? 1 : 0),
                                            itemBuilder: (context, index) {
                                              if (index == controller.chatRequestList.length &&
                                                  controller.otherRequestLoading.value) {
                                                return const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(16.0),
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 3,
                                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                                                    ),
                                                  ),
                                                );
                                              }
                                              if (index >= controller.chatRequestList.length) {
                                                return const SizedBox.shrink();
                                              }

                                              final chat = controller.chatRequestList[index];
                                              return _buildChatRequestItem(chat, index);
                                            },
                                          ),
                                        ),
                                ),
                              ),
                            );
                    }),

                    Obx(() {
                      return controller.isSearchMode.value ? SizedBox() : buildBottomNavigation();
                    }),
                  ],
                );
              },
            ),

            // Delete Mode Overlay
            Obx(
              () => controller.isDeleteMode.value
                  ? GestureDetector(
                      onTap: controller.hideDeleteMode,
                      child: AnimatedOpacity(
                        opacity: controller.isDeleteMode.value ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.15),
                            child: Stack(children: [_buildDeleteMenu(controller, context)]),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteDialog(ChatModel chat) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            color: AppColors.black000000.withValues(alpha: 0.3),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Get.back();
                  controller.deleteChat(chat.id);
                },
                child: Container(
                  width: 200.w,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  decoration: BoxDecoration(color: AppColors.redFF5353, borderRadius: BorderRadius.circular(12.r)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.whiteFFFFFF, size: 24.sp),
                      Gap(8.w),
                      Text('Delete', style: TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(RoomData chat, int index) {
    final chatKey = GlobalKey();
    final isSelected = controller.selectedChatId!.value == chat.id;

    return Container(
      key: chatKey,
      child: GestureDetector(
        onLongPress: () {
          controller.onChatLongPress(chat.id ?? '', chatKey);
        },
        onTap: () {
          if (controller.isDeleteMode.value) {
            controller.hideDeleteMode();
          } else {
            if (chat.lastMessage?.toLowerCase() == "new byte") {
              Get.to(() => ViewSnapScreen(image: chat.lastMessageMediaUrl ?? ''))?.then((value) {
                controller.viewSnap(chat.lastMessageId ?? '');
                controller.refreshMessages(silent: true);
                controller.readMessage(messageId: chat.lastMessageId ?? '', roomID: chat.roomId ?? '');
              });
            } else {
              controller.readMessage(messageId: chat.lastMessageId ?? '', roomID: chat.id ?? '');
              controller.onChatTap(chat, chat.otherUser!.isVerifiedBadge ?? false);
              controller.refreshMessages(silent: true);
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.whiteFFFFFF.withValues(alpha: 0.9) : AppColors.whiteFFFFFF,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture
              CommonProfileImage(imageUrl: chat.otherUser?.profileImage?.toString(), width: 56.w, height: 56.w),
              Gap(12.w),
              // Chat Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            chat.otherUser?.name ?? '',
                            style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Gap(5.h),
                        if (chat.otherUser?.isVerifiedBadge == true) ...[
                          Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                        ],
                      ],
                    ),

                    Row(
                      children: [
                        chat.lastMessageType?.toLowerCase() == 'snap'
                            ? chat.lastMessageFromMe == true
                                  ? Expanded(
                                      child: Row(
                                        children: [
                                          chat.lastMessageStatus?.toLowerCase() == 'delivered'
                                              ? Assets.icons.icSend.svg(
                                                  colorFilter: ColorFilter.mode(AppColors.grayA4A4A4, BlendMode.srcIn),
                                                  height: 13,
                                                  width: 20,
                                                )
                                              : Assets.icons.icBytes.svg(
                                                  colorFilter: ColorFilter.mode(AppColors.grayA4A4A4, BlendMode.srcIn),
                                                ),
                                          Gap(5),
                                          Expanded(
                                            child: Text(
                                              chat.lastMessageStatus ?? '',
                                              style: TextStyles.medium(14.sp, fontColor: AppColors.grayA4A4A4),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Expanded(
                                      child: Row(
                                        children: [
                                          Assets.icons.icBytes.svg(
                                            colorFilter: ColorFilter.mode(
                                              chat.lastMessage?.toLowerCase() == "new byte"
                                                  ? AppColors.primaryColor
                                                  : AppColors.grayA4A4A4,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                          Gap(5),

                                          Expanded(
                                            child: Text(
                                              chat.lastMessage ?? '',
                                              style: TextStyles.medium(
                                                14.sp,
                                                fontColor: chat.lastMessage?.toLowerCase() == "new byte"
                                                    ? AppColors.primaryColor
                                                    : AppColors.grayA4A4A4,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                            : chat.lastMessageType?.toLowerCase() == 'post'
                            ? Expanded(
                                child: Text(
                                  chat.lastMessageFromMe == false ? 'Shared post' : "You shared Post",
                                  style: TextStyles.medium(
                                    14.sp,
                                    fontColor: chat.lastMessageFromMe == false && chat.lastMessageStatus == 'new'
                                        ? AppColors.black2F3039
                                        : AppColors.grayA4A4A4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : chat.lastMessageType?.toLowerCase() == 'zeal'
                            ? Expanded(
                                child: Text(
                                  chat.lastMessageFromMe == false ? 'Shared zeal' : "You shared zeal",
                                  style: TextStyles.medium(
                                    14.sp,
                                    fontColor: chat.lastMessageFromMe == false && chat.lastMessageStatus == 'new'
                                        ? AppColors.black2F3039
                                        : AppColors.grayA4A4A4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : Expanded(
                                child: Text(
                                  chat.lastMessage ?? '',
                                  style: TextStyles.medium(
                                    14.sp,
                                    fontColor: chat.lastMessageFromMe == false && chat.lastMessageStatus == 'new'
                                        ? AppColors.black2F3039
                                        : AppColors.grayA4A4A4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      chat.lastMessageStatus == 'new' && chat.lastMessageFromMe == false
                          ? Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(color: AppColors.primaryColor, shape: BoxShape.circle),
                            )
                          : SizedBox(),
                      Gap(8.w),
                      Text(chat.timeAgo ?? "", style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatRequestItem(ChatRequest chat, int index) {
    final chatKey = GlobalKey();
    final isSelected = controller.selectedChatId!.value == chat.id;

    return Container(
      key: chatKey,
      child: GestureDetector(
        onLongPress: () {
          // controller.onChatLongPress(chat.id ?? '', chatKey);
        },
        onTap: () {
          if (controller.isDeleteMode.value) {
            controller.hideDeleteMode();
          } else {
            if (chat.lastMessage?.toLowerCase() == "new byte") {
              Get.to(() => ViewSnapScreen(image: chat.lastMessageMediaUrl ?? ''))?.then((value) {
                controller.viewSnap(chat.lastMessageId ?? '');
                controller.refreshMessages(silent: true);
                controller.refreshRequests(silent: true);
                controller.readMessage(messageId: chat.lastMessageId ?? '', roomID: chat.roomId ?? '');
              });
            } else {
              controller.readMessage(messageId: chat.lastMessageId ?? '', roomID: chat.id ?? '');
              controller.onChatRequestTap(chat, chat.otherUser!.isVerifiedBadge ?? false);
              controller.refreshRequests(silent: true);
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.whiteFFFFFF.withValues(alpha: 0.9) : AppColors.whiteFFFFFF,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture
              CommonProfileImage(imageUrl: chat.otherUser?.profileImage ?? '', width: 56.w, height: 56.w),
              Gap(12.w),
              // Chat Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  chat.otherUser?.name ?? '',
                                  style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Gap(5.h),
                              if (chat.otherUser?.isVerifiedBadge == true) ...[
                                Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        // if (chat.lastMessageType == '')
                        //   Container(
                        //     width: 16.w,
                        //     height: 16.w,
                        //     margin: EdgeInsets.only(right: 6.w),
                        //     decoration: BoxDecoration(
                        //       color: AppColors.primaryColor,
                        //       borderRadius: BorderRadius.circular(3.r),
                        //     ),
                        //     child: Icon(Icons.play_arrow, size: 10.sp, color: AppColors.whiteFFFFFF),
                        //   )
                        // else if (chat.lastMessageType == 'delivered')
                        //   Assets.icons.icSend.svg(
                        //     height: 15,
                        //     colorFilter: ColorFilter.mode(AppColors.grayA4A4A4, BlendMode.srcIn),
                        //   ),
                        //
                        // Expanded(
                        //   child: Text(
                        //     chat.lastMessage ?? '',
                        //     style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039),
                        //     maxLines: 1,
                        //     overflow: TextOverflow.ellipsis,
                        //   ),
                        // ),
                        chat.lastMessageType?.toLowerCase() == 'snap'
                            ? chat.lastMessageFromMe == true
                                  ? Expanded(
                                      child: Row(
                                        children: [
                                          Assets.icons.icBytes.svg(
                                            colorFilter: ColorFilter.mode(AppColors.grayA4A4A4, BlendMode.srcIn),
                                          ),
                                          Gap(5),
                                          Expanded(
                                            child: Text(
                                              chat.lastMessageStatus ?? '',
                                              style: TextStyles.medium(14.sp, fontColor: AppColors.grayA4A4A4),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Expanded(
                                      child: Row(
                                        children: [
                                          if (chat.lastMessage?.toLowerCase() == "new byte") ...[
                                            Assets.icons.icBytes.svg(
                                              colorFilter: ColorFilter.mode(
                                                chat.lastMessage?.toLowerCase() == "new byte"
                                                    ? AppColors.primaryColor
                                                    : AppColors.grayA4A4A4,
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                            Gap(5),
                                          ],

                                          Expanded(
                                            child: Text(
                                              chat.lastMessage ?? '',
                                              style: TextStyles.medium(
                                                14.sp,
                                                fontColor: chat.lastMessage?.toLowerCase() == "new byte"
                                                    ? AppColors.primaryColor
                                                    : AppColors.grayA4A4A4,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                            : Expanded(
                                child: Text(
                                  chat.lastMessage ?? '',
                                  style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      chat.lastMessageStatus == 'new' && chat.lastMessageFromMe == false
                          ? Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(color: AppColors.primaryColor, shape: BoxShape.circle),
                            )
                          : SizedBox(),
                      Gap(8.w),
                      Text(chat.timestamp ?? "", style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteMenu(ChatController controller, BuildContext context) {
    if (controller.selectedChatId?.value == null || controller.selectedChatId!.value.isEmpty) {
      return const SizedBox();
    }

    final chat = controller.roomList.firstWhere((c) => c.id == controller.selectedChatId!.value);

    // Get chat item position
    RenderBox? chatBox;
    Offset? chatPosition;

    if (controller.selectedChatKey?.currentContext != null) {
      chatBox = controller.selectedChatKey!.currentContext!.findRenderObject() as RenderBox?;
      if (chatBox != null) {
        chatPosition = chatBox.localToGlobal(Offset.zero);
      }
    }

    // Calculate menu position - below the chat item, or at top if near bottom
    double menuTop = 20.w; // Default top position
    if (chatPosition != null) {
      // menuTop = chatPosition!.dy + (chatHeight ?? 80.h) + 15.h;
      menuTop = chatPosition.dy - 100;
      // If menu would go off screen at bottom, position it above the chat item
      if (menuTop > Get.height - 200.h) {
        menuTop = chatPosition.dy - 150.h;
        // If still off screen at top, use default top position
        if (menuTop < 20.w) {
          menuTop = 20.w;
        }
      }
    }

    return Positioned(
      top: menuTop,
      left: 20.w,
      right: 20.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chat Preview with Animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              final clampedValue = value.clamp(0.0, 1.0);
              return Transform.scale(
                scale: clampedValue,
                child: Opacity(
                  opacity: clampedValue,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.whiteFFFFFF, borderRadius: BorderRadius.circular(20.r)),
                    padding: EdgeInsets.all(15.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CommonProfileImage(
                                imageUrl: chat.otherUser?.profileImage?.toString(),
                                width: 56.w,
                                height: 56.w,
                              ),
                              Gap(12.w),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      chat.otherUser?.username ?? '',
                                      style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Gap(4.h),
                                    Text(
                                      chat.lastMessage ?? "",
                                      style: TextStyles.medium(14.sp, fontColor: AppColors.g707070ray),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /*   Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(color: AppColors.primaryColor, shape: BoxShape.circle),
                            ),
                            Gap(8.w),*/
                            Text(
                              chat.timeAgo ?? '',
                              style: TextStyles.medium(
                                14.sp,
                                fontColor: /*chat.isUnread ? AppColors.black2F3039 :*/ AppColors.grayA4A4A4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Gap(15.h),
          // Delete Option with Animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              final clampedValue = value.clamp(0.0, 1.0);
              return Transform.scale(
                scale: clampedValue,
                child: Opacity(
                  opacity: clampedValue,
                  child: GestureDetector(
                    onTap: controller.deleteSelectedChat,
                    child: Container(
                      width: Get.width * 0.5,
                      decoration: BoxDecoration(
                        color: AppColors.whiteFFFFFF,
                        borderRadius: BorderRadius.circular(17.r),
                      ),
                      padding: EdgeInsets.all(15.h),
                      child: Row(
                        children: [
                          Text('Delete', style: TextStyles.medium(15.sp, fontColor: AppColors.redFF5353)),
                          const Spacer(),
                          Assets.icons.icDelete.svg(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildBottomNavigation() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          PressScaleButton(
            onTap: () => controller.onMessagesTap(context),
            child: Text(
              'Messages',
              style: TextStyles.medium(
                16.sp,
                fontColor: controller.isMessageTab.value ? AppColors.black2F3039 : AppColors.g707070ray
              ),
            ),
          ),
          Gap(40.w),
          PressScaleButton(
            onTap: () => controller.onCameraTap(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 85.h,
                  height: 85.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryColor, width: 3),
                  ),
                ),
                Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    gradient: LinearGradient(
                      colors: const [AppColors.primaryColor, AppColors.primaryDark],
                      stops: const [-0.0864, 0.798],
                      transform: GradientRotation((320.33 - 90) * math.pi / 180),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Wrap(children: [Assets.icons.icCamera.svg(height: 28, width: 28, fit: BoxFit.contain)]),
                ),
              ],
            ),
          ),
          Gap(40.w),
          PressScaleButton(
            onTap: () => controller.onRequestsTap(context),
            child: Text(
              'Requests',
              style: TextStyles.medium(
                16.sp,
                fontColor: controller.isMessageTab.value ? AppColors.g707070ray : AppColors.black2F3039,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
