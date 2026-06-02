import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/presentation/main/chat/controller/chat_details_controller.dart';
import 'package:omeeba_new/presentation/main/chat/models/api_message_model.dart';
import 'package:omeeba_new/presentation/main/take_snap/views/view_snap.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/widgets/poll_card.dart';
import '../../explore/controller/explore_controller.dart';
import '../../myprofile/controller/my_profile_controller.dart';
import '../../zeals/views/zeal_detail_screen.dart';

class ChatDetailsScreen extends GetView<ChatDetailsController> {
  const ChatDetailsScreen({super.key});

  Future<bool> _handleMessageLinkTap(Uri uri, String rawText) async {
    final host = uri.host.toLowerCase();
    if (host == 'omeeba.co.in' || host == 'www.omeeba.co.in') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 3 && segments[0].toLowerCase() == 'share') {
        final shareType = segments[1].toLowerCase();
        final contentId = segments[2].trim();
        if (contentId.isEmpty) return false;

        if (shareType == 'zeal') {
          Get.to(() => const ZealDetailScreen(), arguments: <String, dynamic>{'contentId': contentId});
          return true;
        }

        if (shareType == 'post' || shareType == 'write-post' || shareType == 'poll') {
          final contentType = shareType == 'write-post' ? 'write' : shareType;
          Get.toNamed(AppRoutes.postContentDetail, arguments: {'contentId': contentId, 'contentType': contentType});
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChatDetailsController>(
      init: ChatDetailsController(),
      builder: (controller) {
        final statusBarHeight = MediaQuery.paddingOf(context).top;
        final topContentPadding = statusBarHeight + 65.h + 1.h;

        return Scaffold(
          backgroundColor: AppColors.white,
          body: Stack(
            children: [
              Column(
                children: [
                  Obx(() {
                    return controller.isLoadingMessages.value && controller.messages.isEmpty
                        ? Expanded(child: _buildShimmerLoading(context))
                        : Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (controller.mainScrollController is PaginationScrollController &&
                                    (controller.mainScrollController as PaginationScrollController)
                                        .isRestoringScrollPosition) {
                                  return true;
                                }
                                final metrics = notification.metrics;
                                const loadMoreThreshold = 200.0;
                                // In reverse: true list, pixels=0 is bottom (newest), pixels=maxScrollExtent is top (oldest)
                                if (notification is ScrollUpdateNotification &&
                                    metrics.maxScrollExtent - metrics.pixels <= loadMoreThreshold &&
                                    metrics.maxScrollExtent > loadMoreThreshold) {
                                  controller.loadMoreMessages();
                                }
                                return false;
                              },
                              child: Obx(() {
                                final messages = controller.messages;
                                final isTyping = controller.isOtherUserTyping.value;
                                final isLoadingMore = controller.isLoadingMessages.value && messages.isNotEmpty;
                                final showHeader = !controller.hasMoreMessages.value && messages.isNotEmpty;

                                // Total count: messages + typing + loading_more + header
                                final int itemCount =
                                    messages.length +
                                    (isTyping ? 1 : 0) +
                                    (isLoadingMore ? 1 : 0) +
                                    (showHeader ? 1 : 0);

                                if (messages.isEmpty && !controller.isLoadingMessages.value) {
                                  return _buildEmptyStateHeader(context, topContentPadding);
                                }

                                return ListView.builder(
                                  controller: controller.mainScrollController,
                                  reverse: true,
                                  physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                  padding: EdgeInsets.only(
                                    left: 16.w,
                                    right: 16.w,
                                    top: topContentPadding + 12.h,
                                    bottom: 12.h,
                                  ),
                                  itemCount: itemCount,
                                  itemBuilder: (context, index) {
                                    int currentOffset = 0;

                                    // 1. Typing Indicator at the very bottom (index 0)
                                    if (isTyping) {
                                      if (index == 0) {
                                        return _buildListItemTypingIndicator();
                                      }
                                      currentOffset++;
                                    }

                                    // 2. Messages
                                    final int messageIndex = index - currentOffset;
                                    if (messageIndex >= 0 && messageIndex < messages.length) {
                                      final message = messages[messageIndex];
                                      return _buildListItemMessage(message, controller);
                                    }
                                    currentOffset += messages.length;

                                    // 3. Loading More Shimmer/Spinner
                                    if (isLoadingMore) {
                                      final int loaderIndex = index - currentOffset;
                                      if (loaderIndex == 0) {
                                        return _buildListItemLoader();
                                      }
                                      currentOffset++;
                                    }

                                    // 4. User Info Header at the very top (end of list)
                                    if (showHeader) {
                                      final int headerIndex = index - currentOffset;
                                      if (headerIndex == 0) {
                                        return _buildListItemHeader(controller);
                                      }
                                    }

                                    return const SizedBox.shrink();
                                  },
                                );
                              }),
                            ),
                          );
                  }),

                  Obx(() {
                    return controller.isRequest.value
                        ? Padding(
                            padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 10.h),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      controller.rejectMessageRequest();
                                    },
                                    child: Container(
                                      height: 40.h,
                                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                                      decoration: BoxDecoration(
                                        color: AppColors.greyF5F5F5,
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Reject',
                                          style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Gap(12.w),
                                // Expanded(
                                //   child: GestureDetector(
                                //     onTap: () {
                                //       controller.blockMessageRequest();
                                //     },
                                //     child: Container(
                                //       height: 40.h,
                                //       padding: EdgeInsets.symmetric(horizontal: 16.w),
                                //       decoration: BoxDecoration(
                                //         color: AppColors.greyF5F5F5,
                                //         borderRadius: BorderRadius.circular(6.r),
                                //       ),
                                //       child: Center(
                                //         child: Text(
                                //           'Block',
                                //           style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                // ),
                                // Gap(12.w),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      controller.acceptMessageRequest();
                                    },
                                    child: Container(
                                      height: 40.h,
                                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: const [AppColors.primaryColor, AppColors.primaryDark],
                                          stops: const [-0.0864, 0.798],
                                          transform: GradientRotation((320.33 - 90) * math.pi / 180),
                                        ),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Accept',
                                          style: TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container();
                  }),
                  Obx(() {
                    if (controller.isRequest.value || !controller.showPendingSentToast.value) {
                      return const SizedBox();
                    }
                    return Container(
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(horizontal: 16.w).copyWith(bottom: 8.h),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: AppColors.grayEDF1F4,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.whiteE5E5E5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22.w,
                            height: 22.w,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lightPrimaryColor),
                            child: Icon(Icons.info_outline_rounded, size: 14.sp, color: AppColors.primaryColor),
                          ),
                          Gap(10.w),
                          Expanded(
                            child: Text(
                              'Message sent, it will appear once accepted.',
                              style: TextStyles.regular(13.sp, fontColor: AppColors.black2F3039),
                            ),
                          ),
                          Gap(10.w),
                          GestureDetector(
                            onTap: controller.dismissPendingSentToast,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: const [AppColors.primaryColor, AppColors.primaryDark],
                                  stops: const [-0.0864, 0.798],
                                  transform: GradientRotation((320.33 - 90) * math.pi / 180),
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text('OK', style: TextStyles.medium(12.sp, fontColor: AppColors.whiteFFFFFF)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Obx(() {
                    return controller.isRequest.value
                        ? SizedBox()
                        : Container(
                            padding: EdgeInsets.only(left: 16.w),
                            decoration: BoxDecoration(color: AppColors.grayEDF1F4),
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 20, top: 13),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(25.r),
                                      ),
                                      child: TextField(
                                        controller: controller.messageController,
                                        maxLines: 6,
                                        minLines: 1,
                                        decoration: InputDecoration(
                                          hintText: 'Message...',
                                          hintStyle: TextStyles.regular(15.sp, fontColor: AppColors.gray707070),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                        ),
                                        style: TextStyles.regular(15.sp, fontColor: AppColors.black2F3039),

                                        textInputAction: TextInputAction.send,
                                        onSubmitted: (_) => controller.sendMessage(),
                                        onChanged: (_) => controller.onMessageChanged(),
                                      ),
                                    ),
                                  ),

                                  IconButton(
                                    onPressed: controller.sendMessage,
                                    icon: Assets.icons.icSend.svg(),
                                    highlightColor: AppColors.lightPrimaryColor,
                                  ),
                                ],
                              ),
                            ),
                          );
                  }),
                ],
              ),

              _buildBlurredChatAppBar(context, controller),

              // WhatsApp-style: scroll to bottom FAB when user is above (viewing older messages)
              Obx(
                () => controller.showScrollToBottomFAB.value
                    ? Positioned(
                        right: 16.w,
                        bottom: 100.h,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(28.r),
                          color: AppColors.whiteFFFFFF,
                          child: InkWell(
                            onTap: () => controller.scrollToBottom(),
                            borderRadius: BorderRadius.circular(28.r),
                            child: Container(
                              width: 48.w,
                              height: 48.w,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 28.sp,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),

              // Context Menu Overlay
              Obx(
                () => controller.isContextMenuVisible.value
                    ? GestureDetector(
                        onTap: controller.hideContextMenu,
                        child: AnimatedOpacity(
                          opacity: controller.isContextMenuVisible.value ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.15),
                              child: Stack(children: [_buildContextMenu(controller, context)]),
                            ),
                          ),
                        ),
                      )
                    // GestureDetector(
                    //         onTap: controller.hideContextMenu,
                    //         child: AnimatedOpacity(
                    //           opacity: controller.isContextMenuVisible.value ? 1.0 : 0.0,
                    //           duration: const Duration(milliseconds: 200),
                    //           child: BackdropFilter(
                    //             filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    //             child: Container(
                    //              height: Get.height, width: Get.width,
                    //               color: Colors.black.withValues(alpha: 0.10),
                    //               child: _buildContextMenu(controller, context),
                    //             ),
                    //           ),
                    //         ),
                    //       )
                    : const SizedBox(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Frosted header matching [HomeScreen] — chat scrolls underneath so messages show through the blur.
  Widget _buildBlurredChatAppBar(BuildContext context, ChatDetailsController controller) {
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final totalHeight = statusBarHeight + 65.h + 1.h;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            height: totalHeight,
            decoration: BoxDecoration(
              color: AppColors.whiteFFFFFF.withValues(alpha: 0.72),
              border: Border(bottom: BorderSide(color: AppColors.grayEAEAEA, width: 1)),
            ),
            padding: EdgeInsets.only(top: statusBarHeight),
            child: SizedBox(
              height: 65.h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40.w,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        controller.hideContextMenu();
                        Get.back();
                      },
                      icon: Image.asset(Assets.icons.icArrowBack.path, scale: 3.5),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Get.toNamed(AppRoutes.otherUserProfile, arguments: controller.chatModel?.userId ?? '');
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 45.w,
                            height: 45.h,
                            padding: EdgeInsets.all(5.sp),
                            child: CommonProfileImage(
                              imageUrl: controller.chatModel?.userProfileImage ?? "",
                              width: 45.w,
                              height: 45.h,
                            ),
                          ),
                          Gap(10.w),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    controller.chatModel?.userName ?? '',
                                    style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Gap(5.h),
                                if (controller.chatModel?.isVerifiedBeach ?? false == true) ...[
                                  Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                                ],
                              ],
                            ),
                          ),
                          Gap(8.w),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top + 65.h + 1.h;
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: EdgeInsets.only(left: 16.w, right: 16.w, top: topPad + 12.h, bottom: 12.h),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Simulate received message shimmer
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: Get.width * 0.75),
                  child: Container(
                    width: 200.w,
                    height: 40.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // Simulate sent message shimmer
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: BoxConstraints(maxWidth: Get.width * 0.7),
                  child: Container(
                    width: 150.w,
                    height: 40.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // Another received message shimmer
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: Get.width * 0.75),
                  child: Container(
                    width: 180.w,
                    height: 40.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // Simulate sent message shimmer
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: BoxConstraints(maxWidth: Get.width * 0.7),
                  child: Container(
                    width: 250.w,
                    height: 60.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // Another received message shimmer
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: Get.width * 0.75),
                  child: Container(
                    width: 200.w,
                    height: 80.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // Simulate sent message shimmer
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: BoxConstraints(maxWidth: Get.width * 0.7),
                  child: Container(
                    width: 150.w,
                    height: 40.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ),
              SizedBox(height: 15.h),
              // Simulate sent message shimmer
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: BoxConstraints(maxWidth: Get.width * 0.7),
                  child: Container(
                    width: 200.w,
                    height: 40.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // Simulate sent message shimmer
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: BoxConstraints(maxWidth: Get.width * 0.7),
                  child: Container(
                    width: 270.w,
                    height: 90.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // Another received message shimmer
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: Get.width * 0.75),
                  child: Container(
                    width: 100.w,
                    height: 40.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextMenu(ChatDetailsController controller, BuildContext context) {
    if (controller.selectedMessageId?.value == null) return const SizedBox();

    // Get message position if possible
    RenderBox? messageBox;
    Offset? messagePosition;

    if (controller.selectedMessageKey?.currentContext != null) {
      messageBox = controller.selectedMessageKey!.currentContext!.findRenderObject() as RenderBox?;
      if (messageBox != null) {
        messagePosition = messageBox.localToGlobal(Offset.zero);
      }
    }

    // Calculate menu position - above the message
    double menuTop = messagePosition != null ? messagePosition.dy - 170.h : Get.height * 0.4;

    // Ensure menu stays within screen bounds
    if (menuTop < 100.h) {
      menuTop = 100.h;
    }
    if (menuTop > Get.height - 200.h) {
      menuTop = Get.height - 200.h;
    }

    return Positioned(
      top: menuTop,
      left: 20.w,
      right: 20.w,
      child: Column(
        crossAxisAlignment: controller.isSelectedSender.value ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              // Clamp values to ensure they stay within valid range
              final clampedValue = value.clamp(0.0, 1.0);
              return Transform.scale(
                scale: clampedValue,
                child: Opacity(opacity: clampedValue, child: controller.selectedWidget),
              );
            },
          ),
          Gap(15.h),

          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              // Clamp values to ensure they stay within valid range
              final clampedValue = value.clamp(0.0, 1.0);
              return Transform.scale(
                scale: clampedValue,
                child: Opacity(
                  opacity: clampedValue,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 200),
                    decoration: BoxDecoration(
                      color: AppColors.whiteFFFFFF,
                      borderRadius: BorderRadius.circular(15.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.messageData?.messageType == 'Text')
                          _buildMenuItem(
                            icon: Assets.icons.icCopy.svg(),
                            title: 'Copy Text',
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: controller.messageData?.message ?? ''));
                              controller.hideContextMenu();
                            },
                            isRed: false,
                          ),

                        if (controller.messageData?.messageType == 'Text' &&
                            controller.messageData?.sender?.id == PrefService.getString(PrefKeys.userId))
                          Divider(height: 1, color: AppColors.grayEDF1F4),

                        if (controller.messageData?.sender?.id == PrefService.getString(PrefKeys.userId))
                          _buildMenuItem(
                            icon: Assets.icons.icDelete.svg(),
                            title: 'Delete',
                            onTap: () {
                              controller.deleteMessage();
                            },
                            isRed: true,
                          ),
                      ],
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

  Widget _buildMenuItem({
    required SvgPicture icon,
    required String title,
    required VoidCallback onTap,
    required bool isRed,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyles.medium(16.sp, fontColor: isRed ? AppColors.redFF5353 : AppColors.black2F3039),
            ),
            const Spacer(),
            icon,
          ],
        ),
      ),
    );
  }

  Widget buildSnapMessage(
    MessageData message,
    GlobalKey messageKey,
    bool isSelected,
    ChatDetailsController controller,
  ) {
    return GestureDetector(
      onTap: () {
        final isMine = message.sender?.id == PrefService.getString(PrefKeys.userId);
        if (isMine) return;
        // Socket `new_snap` often omits status; treat as openable until seen.
        final alreadySeen = message.status?.toLowerCase() == 'seen';
        if (alreadySeen) return;
        Get.to(() => ViewSnapScreen(image: message.mediaUrl ?? ''))?.then((value) {
          controller.viewSnap(message.id ?? '');
        });
      },
      child: message.sender?.id == PrefService.getString(PrefKeys.userId)
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 200.w,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(12.r)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.camera_alt, color: AppColors.grey9EAABD, size: 18),
                      Gap(7),
                      Flexible(
                        child: Text(
                          'you shared a byte!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyles.regular(16, fontColor: AppColors.grey9EAABD),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formatDateTime(message.createdAt ?? ''),
                    style: TextStyles.regular(16, fontColor: AppColors.grey9EAABD),
                  ),
                ],
              ),
            )
          : AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: message.status?.toLowerCase() == 'seen' ? 177.w : 153.w,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(12.r)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  message.status?.toLowerCase() == 'seen'
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.camera_alt, color: AppColors.grey9EAABD, size: 18),
                            Gap(7),
                            Flexible(
                              child: Text(
                                'shared a byte!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyles.regular(16, fontColor: AppColors.grey9EAABD),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.camera_alt, color: AppColors.blue3382FF),
                            Gap(7),
                            Flexible(
                              child: Text(
                                'Tap to view',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyles.regular(16, fontColor: AppColors.blue3382FF),
                              ),
                            ),
                          ],
                        ),
                  Text(
                    formatDateTime(message.createdAt ?? ''),
                    style: TextStyles.regular(
                      16,
                      fontColor: message.status?.toLowerCase() == 'seen' ? AppColors.grey9EAABD : AppColors.blue3382FF,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextMessage(
    MessageData message,
    GlobalKey messageKey,
    bool isSelected,
    ChatDetailsController controller,
  ) {
    return GestureDetector(
      onLongPress: () {
        // if (message.sender?.id != PrefService.getString(PrefKeys.userId)) {
        //   return;
        // }

        controller.selectedWidget = Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            gradient: message.sender?.id == PrefService.getString(PrefKeys.userId)
                ? LinearGradient(
                    colors: const [AppColors.primaryColor, AppColors.primaryDark],
                    stops: const [-0.0864, 0.798],
                  )
                : LinearGradient(colors: [AppColors.greyE5E4DC, AppColors.white], stops: const [-0.0864, 0.798]),
            color: isSelected
                ? (message.sender?.id == PrefService.getString(PrefKeys.userId)
                      ? AppColors.primaryColor
                      : AppColors.whiteFFFFFF)
                : (message.sender?.id == PrefService.getString(PrefKeys.userId)
                      ? AppColors.primaryColor
                      : AppColors.whiteFFFFFF),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: LinkifiedText(
            text: message.message ?? '',
            style: TextStyles.regular(
              15.sp,
              fontColor: message.sender?.id == PrefService.getString(PrefKeys.userId)
                  ? AppColors.whiteFFFFFF
                  : AppColors.black2F3039,
            ),
            onLinkTap: _handleMessageLinkTap,
          ),
        );
        controller.onMessageLongPress(
          data: message,
          widget: Container(),
          messageId: message.id ?? '',

          messageKey: messageKey,
          isSender: message.sender?.id == PrefService.getString(PrefKeys.userId),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: (message.sender?.id == PrefService.getString(PrefKeys.userId))
              ? LinearGradient(
                  colors: const [AppColors.primaryColor, AppColors.primaryDark],
                  stops: const [-0.0864, 0.798],
                  transform: GradientRotation((320.33 - 90) * math.pi / 180),
                )
              : null,
          color: isSelected
              ? (message.sender?.id == PrefService.getString(PrefKeys.userId)
                    ? AppColors.primaryColor
                    : AppColors.grayEDF1F4)
              : (message.sender?.id == PrefService.getString(PrefKeys.userId)
                    ? AppColors.primaryColor
                    : AppColors.grayEDF1F4),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: LinkifiedText(
          text: message.message ?? '',
          style: TextStyles.regular(
            15.sp,
            fontColor: message.sender?.id == PrefService.getString(PrefKeys.userId)
                ? AppColors.whiteFFFFFF
                : AppColors.black2F3039,
          ),
          onLinkTap: _handleMessageLinkTap,
        ),
      ),
    );
  }

  String formatDateTime(String dateString) {
    DateTime dateTime = DateTime.parse(dateString).toLocal();
    DateTime now = DateTime.now();

    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(Duration(days: 1));
    DateTime messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String time =
        "${dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}";

    if (messageDate == today) {
      return "Today, $time";
    } else if (messageDate == yesterday) {
      return "Yesterday, $time";
    } else {
      return "${dateTime.day.toString().padLeft(2, '0')} "
          "${_monthName(dateTime.month)} "
          "${dateTime.year}, $time";
    }
  }

  String _monthName(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }

  Widget _buildImageMessage(
    MessageData message,
    GlobalKey messageKey,
    bool isSelected,
    ChatDetailsController controller,
  ) {
    return GestureDetector(
      onLongPress: () {
        if (message.sender?.id != PrefService.getString(PrefKeys.userId)) {
          return;
        }
        controller.selectedWidget = Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (message.sender?.id == PrefService.getString(PrefKeys.userId)
                      ? AppColors.primaryColor.withValues(alpha: 0.9)
                      : AppColors.greyEDEDED.withValues(alpha: 0.9))
                : (message.sender?.id == PrefService.getString(PrefKeys.userId)
                      ? AppColors.primaryColor
                      : AppColors.greyEDEDED),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: _buildImageMessageContent(message, false, controller),
          ),
        );
        controller.onMessageLongPress(
          widget: Container(),
          messageId: message.id ?? '',
          messageKey: messageKey,
          isSender: message.sender?.id == PrefService.getString(PrefKeys.userId),
          data: message,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: /* isSelected
              ? (message.sender?.id == PrefService.getString(PrefKeys.userId)
                    ? AppColors.primaryColor
                    : AppColors.whiteFFFFFF)
              : (message.sender?.id == PrefService.getString(PrefKeys.userId)
                    ? AppColors.primaryColor
                    :*/
              AppColors.greyEDEDED,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: _buildImageMessageContent(message, false, controller),
        ),
      ),
    );
  }

  Widget _buildImageMessageContent(MessageData message, bool isSelected, ChatDetailsController controller) {
    return Container(
      constraints: BoxConstraints(maxWidth: Get.width * 0.75),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile picture and username
          if (message.contentCreator != null)
            InkWell(
              onTap: () {
                Get.toNamed(AppRoutes.otherUserProfile, arguments: message.contentCreator?.id ?? '');
              },
              child: Container(
                padding: EdgeInsets.all(12.w),
                color: AppColors.grayEDF1F4,
                child: Row(
                  children: [
                    CommonProfileImage(imageUrl: message.contentCreator?.profileImage, width: 24.w, height: 24.w),
                    Gap(8.w),
                    Flexible(
                      child: Text(
                        message.contentCreator?.username ?? '',
                        style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039),
                      ),
                    ),
                    Gap(5.h),
                    if (message.contentCreator?.isVerifiedBadge ?? false == false) ...[
                      Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                    ],
                  ],
                ),
              ),
            ),

          // Image - load hone ke baad scroll to bottom
          GestureDetector(
            onTap: () {
              Get.toNamed(
                AppRoutes.postContentDetail,
                arguments: {'contentId': message.contentId, 'contentType': message.contentType, 'commentId': ""},
              );
            },
            child: Column(
              children: [
                if (message.thumbnailUrl != null)
                  CachedNetworkImage(
                    imageUrl: message.thumbnailUrl!,
                    width: Get.width * 0.75,
                    height: 300,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(width: Get.width * 0.75, height: 300, color: AppColors.greyEDEDED),
                    errorWidget: (context, url, error) => Container(
                      width: Get.width * 0.75,
                      height: 200.h,
                      color: AppColors.greyEDEDED,
                      child: Icon(Icons.error_outline, color: AppColors.gray707070, size: 40.sp),
                    ),
                  ),
                // Text below image if exists
                // if (message.message?.isNotEmpty ?? false)
                //   Container(
                //     color: AppColors.whiteFFFFFF,
                //     padding: EdgeInsets.all(12.w),
                //     child: Text(
                //       message.message ?? '',
                //       style: TextStyles.regular(
                //         15.sp,
                //         fontColor: message.sender?.id == PrefService.getString(PrefKeys.userId)
                //             ? AppColors.whiteFFFFFF
                //             : AppColors.black2F3039,
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostMessage(
    MessageData message,
    GlobalKey messageKey,
    bool isSelected,
    ChatDetailsController controller,
  ) {
    return GestureDetector(
      onTap: () {
        /// Navigate to details screen
        Get.toNamed(
          AppRoutes.postContentDetail,
          arguments: {'contentId': message.contentId, 'contentType': message.contentType},
        );
      },

      onLongPress: () {
        if (message.sender?.id != PrefService.getString(PrefKeys.userId)) {
          return;
        }

        controller.selectedWidget = Container(
          decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(16.r)),
          child: ClipRRect(borderRadius: BorderRadius.circular(16.r), child: _buildPostMessageContent(message)),
        );

        controller.onMessageLongPress(
          widget: Container(),
          messageId: message.id ?? '',
          messageKey: messageKey,
          isSender: message.sender?.id == PrefService.getString(PrefKeys.userId),
          data: message,
        );
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(color: AppColors.greyEDEDED, borderRadius: BorderRadius.circular(16.r)),
        child: ClipRRect(borderRadius: BorderRadius.circular(16.r), child: _buildPostMessageContent(message)),
      ),
    );
  }

  Widget _buildPostMessageContent(MessageData message) {
    final String content = message.contentData["content"] ?? '';
    final bool showReadMore = content.length > 45;
    return Container(
      decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(16.r)),
      constraints: BoxConstraints(maxWidth: Get.width * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.contentCreator != null)
            InkWell(
              onTap: () => Get.toNamed(AppRoutes.otherUserProfile, arguments: message.contentCreator?.id ?? ''),
              child: Container(
                padding: EdgeInsets.all(10.w),
                color: AppColors.grayEDF1F4,
                child: Row(
                  children: [
                    CommonProfileImage(imageUrl: message.contentCreator?.profileImage, width: 24.w, height: 24.w),
                    Gap(8.w),

                    Flexible(
                      child: Text(
                        message.contentCreator?.username ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039),
                      ),
                    ),
                    Gap(5.w),
                    if (message.contentCreator?.isVerifiedBadge == true)
                      Assets.icons.icVerifyBadgeSmallSize.svg(width: 14.w, height: 14.h),
                  ],
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.regular(14.sp, fontColor: AppColors.black2F3039),
                ),

                if (showReadMore) ...[
                  SizedBox(height: 4.h),
                  GestureDetector(
                    onTap: () {
                      // Open full message / expand text
                    },
                    child: Text("Read More", style: TextStyles.regular(13.sp, fontColor: AppColors.textPrimary)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollMessage(
    MessageData message,
    GlobalKey messageKey,
    bool isSelected,
    ChatDetailsController controller,
  ) {
    return GestureDetector(
      onLongPress: () {
        if (message.sender?.id != PrefService.getString(PrefKeys.userId)) {
          return;
        }

        controller.selectedWidget = Container(
          decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(16.r)),
          child: ClipRRect(borderRadius: BorderRadius.circular(16.r), child: _buildPollMessageContent(message)),
        );

        controller.onMessageLongPress(
          widget: Container(),
          messageId: message.id ?? '',
          messageKey: messageKey,
          isSender: message.sender?.id == PrefService.getString(PrefKeys.userId),
          data: message,
        );
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(color: AppColors.greyEDEDED, borderRadius: BorderRadius.circular(16.r)),
        child: ClipRRect(borderRadius: BorderRadius.circular(16.r), child: _buildPollMessageContent(message)),
      ),
    );
  }

  Widget _buildPollMessageContent(MessageData message) {
    final Map<String, dynamic> poll = message.contentData ?? <String, dynamic>{};

    List getOptions() {
      final pollOptions = poll["options"];
      final optionsList = pollOptions is List ? pollOptions : const [];
      return optionsList.isEmpty
          ? [
              const PollOption(optionId: '', text: 'Option 1', percentage: 0, isSelected: false),
              const PollOption(optionId: '', text: 'Option 2', percentage: 0, isSelected: false),
            ]
          : optionsList.map((o) {
              final option = o is Map ? o : const {};
              return PollOption(
                optionId: option["optionId"] ?? '',
                text: option["optionText"] ?? '',
                percentage: option["votePercentage"] ?? 0,
                isSelected: poll["userVoted"] == true && poll["selectedOptionId"] == option["optionId"],
              );
            }).toList();
    }

    return Container(
      constraints: BoxConstraints(maxWidth: Get.width * 0.75),
      color: AppColors.grayEDF1F4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // USER HEADER
          if (message.contentCreator != null)
            GestureDetector(
              onTap: () {
                Get.toNamed(AppRoutes.otherUserProfile, arguments: message.contentCreator?.id ?? '');
              },
              child: Container(
                padding: EdgeInsets.all(10.w),
                color: AppColors.grayEDF1F4,
                child: Row(
                  children: [
                    CommonProfileImage(imageUrl: message.contentCreator?.profileImage, width: 24.w, height: 24.w),
                    Gap(8.w),

                    Flexible(
                      child: Text(
                        message.contentCreator?.username ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039),
                      ),
                    ),

                    if (message.contentCreator?.isVerifiedBadge == true) ...[
                      Gap(5.w),
                      Assets.icons.icVerifyBadgeSmallSize.svg(width: 14.w, height: 14.h),
                    ],
                  ],
                ),
              ),
            ),

          // QUESTION
          GestureDetector(
            onTap: () {
              Get.toNamed(
                AppRoutes.postContentDetail,
                arguments: {'contentId': message.contentId, 'contentType': message.contentType, 'commentId': ""},
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Text(
                    (poll["question"] ?? '').toString(),
                    style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039),
                  ),
                ),
                // OPTIONS LIST (FROM API)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Column(
                    children: getOptions().map((option) {
                      return _buildPollOption(option);
                    }).toList(),
                  ),
                ),

                // TIME LEFT
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  child: Text(
                    (poll["expiresAt"] != null && DateTime.tryParse((poll["expiresAt"] ?? '').toString()) != null)
                        ? timeRemaining(DateTime.parse((poll["expiresAt"] ?? '').toString()))
                        : '',
                    style: TextStyles.regular(12.sp, fontColor: AppColors.gray707070),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollOption(PollOption option) {
    final double fraction = option.percentage / 100;
    final isSelected = option.isSelected;
    final usePrimary = isSelected;
    final useUnselectedColor = !isSelected;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.whiteE5E5E5),
        borderRadius: BorderRadius.circular(10.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // STATIC BAR (NO ANIMATION)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * fraction,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      gradient: usePrimary
                          ? LinearGradient(
                              colors: const [AppColors.primaryColor, AppColors.primaryDark],
                              stops: const [-0.0864, 0.798],
                              transform: GradientRotation((320.33 - 90) * math.pi / 180),
                            )
                          : null,
                      color: useUnselectedColor ? AppColors.lightPrimaryColor : null,
                    ),
                  ),
                );
              },
            ),
          ),

          // CONTENT
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            child: Row(
              children: [
                // Selected
                if (option.isSelected) ...[Assets.icons.icCheck.svg(width: 18.w, height: 18.h), SizedBox(width: 8.w)],

                // TEXT
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyles.regular(
                      14.sp,
                      fontColor: isSelected
                          ? option.percentage < 30
                                ? AppColors.black2F3039
                                : AppColors.whiteEAEAEA
                          : AppColors.black2F3039,
                      fontWeight: option.isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),

                // PERCENTAGE
                Text(
                  "${option.percentage}%",
                  style: TextStyles.regular(
                    14.sp,
                    fontColor: isSelected
                        ? option.percentage < 90
                              ? AppColors.black2F3039
                              : AppColors.whiteEAEAEA
                        : AppColors.black2F3039,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String timeRemaining(DateTime targetTime) {
    final now = DateTime.now();
    Duration diff = targetTime.difference(now);

    if (diff.isNegative) return "Poll ended";

    final int days = diff.inDays;
    final int hours = diff.inHours % 24;
    final int minutes = diff.inMinutes % 60;

    List<String> parts = [];

    if (days > 0) {
      parts.add("${days}d");
      parts.add("${hours}h left");
    } else if (hours > 0) {
      parts.add("${hours}h");
      parts.add("${minutes}m left");
    } else {
      parts.add("${minutes}m left");
    }

    return parts.join(" ");
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAnimatedDot(0),
        SizedBox(width: 4.w),
        _buildAnimatedDot(200),
        SizedBox(width: 4.w),
        _buildAnimatedDot(400),
      ],
    );
  }

  Widget _buildAnimatedDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800),
      builder: (context, value, child) {
        // Create a repeating animation with delay
        final animationValue = (value + (delayMs / 800.0)) % 1.0;
        final scale = 0.5 + (animationValue * 0.5);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 4.w,
            height: 4.w,
            decoration: BoxDecoration(color: AppColors.gray707070, shape: BoxShape.circle),
          ),
        );
      },
    );
  }

  ///zeal post in chat

  Widget _buildZealMessage(
    MessageData message,
    GlobalKey messageKey,
    bool isSelected,
    ChatDetailsController controller,
  ) {
    return GestureDetector(
      onLongPress: () {
        if (message.sender?.id != PrefService.getString(PrefKeys.userId)) {
          return;
        }
        controller.selectedWidget = Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (message.sender?.id == PrefService.getString(PrefKeys.userId)
                      ? AppColors.primaryColor.withValues(alpha: 0.9)
                      : AppColors.greyEDEDED.withValues(alpha: 0.9))
                : (message.sender?.id == PrefService.getString(PrefKeys.userId)
                      ? AppColors.primaryColor
                      : AppColors.greyEDEDED),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: _buildZealMessageContent(message, false, controller),
          ),
        );
        controller.onMessageLongPress(
          widget: Container(),
          data: message,
          messageId: message.id ?? '',
          messageKey: messageKey,
          isSender: message.sender?.id == PrefService.getString(PrefKeys.userId),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected
              ? (message.sender?.id == PrefService.getString(PrefKeys.userId)
                    ? AppColors.primaryColor
                    : AppColors.whiteFFFFFF)
              : (message.sender?.id == PrefService.getString(PrefKeys.userId)
                    ? AppColors.primaryColor
                    : AppColors.greyEDEDED),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: _buildZealMessageContent(message, false, controller),
        ),
      ),
    );
  }

  Widget _buildZealMessageContent(MessageData message, bool isSelected, ChatDetailsController controller) {
    return Container(
      constraints: BoxConstraints(maxWidth: Get.width * 0.50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.thumbnailUrl != null)
            Stack(
              alignment: AlignmentGeometry.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Get.to(
                      () => ZealDetailScreen(),
                      arguments: {'contentId': message.contentId, 'commentId': null},
                    )?.then((result) {
                      if (result is String) Get.find<ExploreController>().removePostById(result);
                      return;
                    });
                  },
                  child: CachedNetworkImage(
                    imageUrl: message.thumbnailUrl!,
                    width: Get.width * 0.50,
                    height: 300,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(width: Get.width * 0.50, height: 300, color: AppColors.greyEDEDED),
                    errorWidget: (context, url, error) => Container(
                      width: Get.width * 0.75,
                      height: 200.h,
                      color: AppColors.greyEDEDED,
                      child: Icon(Icons.error_outline, color: AppColors.gray707070, size: 40.sp),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Get.to(
                      () => ZealDetailScreen(),
                      arguments: {'contentId': message.contentId, 'commentId': null},
                    )?.then((result) {
                      if (result is String) Get.find<ExploreController>().removePostById(result);
                      return;
                    });
                  },
                  child: Icon(Icons.play_arrow_rounded, color: AppColors.white, size: 50),
                ),
                Positioned(
                  top: 15,
                  left: 15,
                  child: GestureDetector(
                    onTap: () {
                      Get.toNamed(AppRoutes.otherUserProfile, arguments: message.contentCreator?.id ?? '');
                    },
                    child: Row(
                      children: [
                        CommonProfileImage(imageUrl: message.contentCreator?.profileImage, width: 24.w, height: 24.w),
                        Gap(8.w),
                        SizedBox(
                          width: 130.w,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  message.contentCreator?.username ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyles.medium(14.sp, fontColor: AppColors.white),
                                ),
                              ),
                              Gap(5.h),
                              if (message.contentCreator?.isVerifiedBadge == true) ...[
                                Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  bottom: 15,
                  left: 10,
                  child: GestureDetector(
                    onTap: () {
                      Get.to(
                        () => ZealDetailScreen(),
                        arguments: {'contentId': message.contentId, 'commentId': null},
                      )?.then((result) {
                        if (result is String) Get.find<ExploreController>().removePostById(result);
                        return;
                      });
                    },
                    child: Icon(Icons.videocam_outlined, size: 30, color: AppColors.white),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildListItemMessage(MessageData message, ChatDetailsController controller) {
    final messageKey = controller.getMessageKey(message.id ?? '');
    final isSelected = controller.selectedMessageId!.value == message.id;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      key: messageKey,
      child: Align(
        alignment: message.sender?.id == PrefService.getString(PrefKeys.userId)
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          constraints: message.sender?.id == PrefService.getString(PrefKeys.userId)
              ? BoxConstraints(maxWidth: Get.width * 0.7)
              : BoxConstraints(maxWidth: Get.width * 0.75),
          child: _buildRelevantMessageContent(message, messageKey, isSelected, controller),
        ),
      ),
    );
  }

  Widget _buildRelevantMessageContent(
    MessageData message,
    GlobalKey messageKey,
    bool isSelected,
    ChatDetailsController controller,
  ) {
    final type = message.messageType?.toLowerCase() ?? '';
    switch (type) {
      case 'zeal':
        return _buildZealMessage(message, messageKey, isSelected, controller);
      case 'post':
        return _buildImageMessage(message, messageKey, isSelected, controller);
      case 'snap':
        return buildSnapMessage(message, messageKey, isSelected, controller);
      case 'text':
        return _buildTextMessage(message, messageKey, isSelected, controller);
      case 'write post':
        return _buildPostMessage(message, messageKey, isSelected, controller);
      case 'poll':
        return _buildPollMessage(message, messageKey, isSelected, controller);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildListItemTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(16.r)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('typing', style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070)),
              Gap(4.w),
              _buildTypingDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItemLoader() {
    return SizedBox(
      height: 60.h,
      child: Center(
        child: SizedBox(
          width: 24.w,
          height: 24.w,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildListItemHeader(ChatDetailsController controller) {
    final username =
        Get.find<MyProfileController>().profile.value?.username ?? PrefService.getString(PrefKeys.userName);
    final isVerifiedBeach =
        Get.find<MyProfileController>().profile.value?.isVerifiedBadge ?? PrefService.getBool(PrefKeys.isVerifiedBeach);

    return Container(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 65.0),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: controller.chatModel?.userProfileImage ?? '',
                        width: 80.w,
                        height: 80.w,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildAvatarPlaceholder(),
                        errorWidget: (context, error, stackTrace) => _buildAvatarPlaceholder(),
                      ),
                    ),
                  ),
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: PrefService.getString(PrefKeys.userProfile),
                      width: 80.w,
                      height: 80.w,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildAvatarPlaceholder(),
                      errorWidget: (context, error, stackTrace) => _buildAvatarPlaceholder(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Gap(12.h),
          _buildHeaderText(
            controller.chatModel?.userName.toUpperCase().split(' ').first ?? '',
            controller.chatModel?.isVerifiedBeach ?? false,
          ),
          _buildHeaderText(username.toUpperCase(), isVerifiedBeach),
          Gap(4.h),
          Text(
            '${controller.chatModel?.followers ?? 0} followers',
            style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderText(String text, bool isVerified) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.extraBold(26.sp, fontColor: AppColors.black2F3039),
          ),
        ),
        Gap(3.h),
        if (isVerified) Assets.icons.icVerifyBadgeSmallSize.svg(width: 18.w, height: 18.h),
      ],
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 80.w,
      height: 80.w,
      color: AppColors.greyEDEDED,
      child: Icon(Icons.person, color: AppColors.gray8C9499, size: 40.sp),
    );
  }

  Widget _buildEmptyStateHeader(BuildContext context, double topContentPadding) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(top: topContentPadding),
        child: Column(
          children: [
            SizedBox(height: 100.h),
            _buildListItemHeader(controller),
            Obx(() {
              if (controller.isRequest.value || !controller.showPendingSentToast.value) {
                return const SizedBox();
              }
              return Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 16.w).copyWith(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.grayEDF1F4,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.whiteE5E5E5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22.w,
                      height: 22.w,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lightPrimaryColor),
                      child: Icon(Icons.info_outline_rounded, size: 14.sp, color: AppColors.primaryColor),
                    ),
                    Gap(10.w),
                    Expanded(
                      child: Text(
                        'Message sent, it will appear once accepted.',
                        style: TextStyles.regular(13.sp, fontColor: AppColors.black2F3039),
                      ),
                    ),
                    Gap(10.w),
                    GestureDetector(
                      onTap: controller.dismissPendingSentToast,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: const [AppColors.primaryColor, AppColors.primaryDark],
                            stops: const [-0.0864, 0.798],
                            transform: GradientRotation((320.33 - 90) * math.pi / 180),
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text('OK', style: TextStyles.medium(12.sp, fontColor: AppColors.whiteFFFFFF)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
