import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/models/notification_response_model.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/presentation/main/notification/controller/notification_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/views/zeal_detail_screen.dart';
import 'package:omeeba_new/presentation/main/notification/widgets/notification_shimmer.dart';
import 'package:omeeba_new/presentation/main/notification/widgets/notification_unfollow_sheet.dart';

// ─── Notification type constants (match API `type` field exactly) ────────────
class _NType {
  static const postComment = 'Post Comment';
  static const writeComment = 'Write Comment';
  static const commentReply = 'Comment Reply';
  static const zealComment = 'Zeal Comment';
  static const newFollower = 'New Follower';
  static const postLiked = 'Post Liked';
  static const writeLiked = 'Write Liked';
  static const zealLiked = 'Zeal Liked';
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<NotificationController>();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _controller.loadMoreNotifications();
    }
  }

  static String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final d = DateTime.now().difference(date);
    if (d.inDays >= 365) return '${(d.inDays / 365).floor()}y';
    if (d.inDays >= 30) return '${(d.inDays / 30).floor()}mo';
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with optional "Mark all read" button.
            Obx(() {
              final hasUnread = _controller.hasUnread;
              final marking = _controller.isMarkingAllRead.value;
              return Padding(
                padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 20.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Notifications', style: TextStyles.semiBold(28.sp, fontColor: AppColors.black2F3039)),
                    if (hasUnread)
                      GestureDetector(
                        onTap: marking ? null : _controller.markAllAsRead,
                        child: marking
                            ? SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('Mark all read', style: TextStyles.medium(14.sp, fontColor: AppColors.primaryColor)),
                      ),
                  ],
                ),
              );
            }),
            Expanded(
              child: Obx(() {
                // Shimmer on first load.
                if (_controller.isLoading.value && !_controller.hasLoadedOnce.value) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: const NotificationShimmer(),
                  );
                }

                // Shimmer on pull-to-refresh (list already cleared by controller).
                if (_controller.isRefreshing.value) {
                  return RefreshIndicator(
                    onRefresh: _controller.refreshNotifications,
                    color: AppColors.primaryColor,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: const NotificationShimmer(),
                    ),
                  );
                }

                final items = _controller.notifications;

                if (!_controller.isLoading.value && items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _controller.refreshNotifications,
                    color: AppColors.primaryColor,
                    child: _buildEmptyNotificationsState(context),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _controller.refreshNotifications,
                  color: AppColors.primaryColor,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    child: ListView.separated(
                      controller: _scrollController,
                      primary: false,
                      padding: EdgeInsets.zero,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length + (_controller.isLoadMoreLoading.value ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.5, color: AppColors.grayEDF1F4),
                      itemBuilder: (context, index) {
                        if (index >= items.length) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Center(
                              child: SizedBox(
                                width: 24.w,
                                height: 24.h,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        return _NotificationItem(
                          notification: items[index],
                          timeAgo: _timeAgo(items[index].createdAt),
                          onTap: () => _controller.onNotificationTap(items[index]),
                          notificationController: _controller,
                        );
                      },
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNotificationsState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 18.w),
                    decoration: BoxDecoration(
                      color: AppColors.whiteFFFFFF,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.grayEDF1F4),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 78.w,
                          height: 78.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AppColors.primaryColor, AppColors.primaryDark]),
                          ),
                          child: Center(
                            child: Assets.icons.icNotificationSelected.svg(
                              width: 38.w,
                              height: 38.h,
                              // The original SVG uses a dark fill; recolor for contrast.
                              colorFilter: ColorFilter.mode(AppColors.whiteFFFFFF, BlendMode.srcIn),
                            ),
                          ),
                        ),
                        SizedBox(height: 14.h),
                        Text(
                          'You are all caught up',
                          textAlign: TextAlign.center,
                          style: TextStyles.semiBold(18.sp, fontColor: AppColors.black2F3039),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'New likes, comments, and follows will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyles.regular(13.sp, fontColor: AppColors.gray8C9499),
                        ),
                        SizedBox(height: 18.h),
                        TextButton.icon(
                          onPressed: _controller.refreshNotifications,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: AppColors.whiteFFFFFF,
                            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Single notification row ──────────────────────────────────────────────────
class _NotificationItem extends StatelessWidget {
  final NotificationData notification;
  final String timeAgo;
  final VoidCallback onTap;
  final NotificationController notificationController;

  const _NotificationItem({
    required this.notification,
    required this.timeAgo,
    required this.onTap,
    required this.notificationController,
  });

  String get _type => notification.type ?? '';

  bool get _isUnread => (notification.status ?? '').toLowerCase() == 'unread';

  // ── Badge icon per exact type ──────────────────────────────────────────────
  Widget _badgeIcon(double size) {
    IconData icon;
    switch (_type) {
      case _NType.postComment:
      case _NType.writeComment:
      case _NType.zealComment:
        icon = Icons.chat_bubble;
        break;
      case _NType.newFollower:
        icon = Icons.person_add;
        break;
      case _NType.postLiked:
      case _NType.writeLiked:
      case _NType.zealLiked:
        icon = Icons.favorite;
        break;
      default:
        // Handle any future types gracefully with a fallback
        if (_type.toLowerCase().contains('like') || _type.toLowerCase().contains('liked')) {
          icon = Icons.favorite;
        } else if (_type.toLowerCase().contains('comment')) {
          icon = Icons.chat_bubble;
        } else if (_type.toLowerCase().contains('follow')) {
          icon = Icons.person_add;
        } else {
          icon = Icons.notifications;
        }
    }
    return Icon(icon, size: size, color: AppColors.whiteFFFFFF);
  }

  // ── Right-side widget per exact type ───────────────────────────────────────
  //  • Comment on Post / Zeal → square or tall thumbnail placeholder
  //  • Comment on Write       → nothing (write posts have no image)
  //  • Like on Post / Zeal    → square or tall thumbnail placeholder
  //  • Like on Write          → nothing
  //  • New Follower           → "Follow Back" gradient button
  Widget? _rightWidget(BuildContext context) {
    switch (_type) {
      case _NType.postComment:
      case _NType.postLiked:
        return _contentThumbnail(isZeal: false);

      case _NType.zealComment:
      case _NType.zealLiked:
        return _contentThumbnail(isZeal: true);

      case _NType.writeComment:
      case _NType.writeLiked:
        // Write posts are text-only — no thumbnail.
        return null;

      case _NType.newFollower:
        return _followBackButton(context, notificationController);

      case _NType.commentReply:
        final ct = (notification.contentType ?? '').toLowerCase();
        if (ct.contains('write')) return null;
        if (ct.contains('poll')) return null;
        if (ct.contains('zeal')) return _contentThumbnail(isZeal: true);
        if (ct.contains('post')) return _contentThumbnail(isZeal: false);
        return null;
      default:
        // Unknown future type — show thumbnail if contentType suggests content
        final ct = (notification.contentType ?? '').toLowerCase();
        if (ct.contains('write')) return null;
        if (ct.contains('poll')) return null;
        if (ct.contains('zeal')) return _contentThumbnail(isZeal: true);
        if (ct.contains('post')) return _contentThumbnail(isZeal: false);
        return null;
    }
  }

  Widget _contentThumbnail({required bool isZeal}) {
    final content = notification.content;
    String? imageUrl;

    if (content != null) {
      if (isZeal) {
        // For zealComment or zealLiked: use thumbnail
        if (content.images != null && content.images!.isNotEmpty) {
          imageUrl = content.images!.first;
        }
      } else {
        // For postComment or postLiked: use first image from images array
        if (content.images != null && content.images!.isNotEmpty) {
          imageUrl = content.images!.first;
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? CommonNetworkImage(
              imageUrl: imageUrl,
              width: 50.w,
              height: isZeal ? 65.w : 50.w,
              fit: BoxFit.cover,
              memCacheWidth: 100,
              memCacheHeight: isZeal ? 130 : null,
            )
          : Assets.icons.icImgPlaceholder.image(width: 50.w, height: isZeal ? 65.w : 50.w, fit: BoxFit.cover),
    );
  }

  Widget _followBackButton(BuildContext context, NotificationController controller) {
    final sender = notification.sender;
    final userId = sender?.id;
    final currentUserId = PrefService.getString(PrefKeys.userId);
    if (userId == null || userId.isEmpty || userId == currentUserId) {
      return const SizedBox.shrink();
    }
    final following = notification.isFollowingSender == true;
    return Container(
      width: 100.w,
      height: 32.h,
      decoration: BoxDecoration(
        gradient: following ? null : const LinearGradient(colors: [AppColors.primaryColor, AppColors.primaryDark]),
        color: following ? AppColors.grayEDF1F4 : null,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: TextButton(
        onPressed: () {
          if (following) {
            NotificationUnfollowSheet.show(controller: controller, userId: userId);
          } else {
            controller.followUser(userId, onError: (msg) => AppFunctions().showToast(msg, bgColor: AppColors.red));
          }
        },
        style: TextButton.styleFrom(
          minimumSize: Size(0, 32.h),
          maximumSize: Size(double.infinity, 32.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          backgroundColor: AppColors.transparentColor,
          surfaceTintColor: AppColors.transparentColor,
          foregroundColor: following ? AppColors.black2F3039 : AppColors.whiteFFFFFF,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
        ),
        child: Text(
          following ? 'Following' : 'Follow',
          style: TextStyles.medium(12.sp, fontColor: following ? AppColors.black2F3039 : AppColors.whiteFFFFFF),
        ),
      ),
    );
  }

  void _handleNavigation() {
    notificationController.navigateForNotification(
      notification,
      onPost: (post, contentType, commentId) {
        final contentId = notification.contentId ?? notification.content?.id ?? post.id ?? '';
        if (contentId.isEmpty) return;
        Get.toNamed(
          AppRoutes.postContentDetail,
          arguments: {'contentId': contentId, 'contentType': contentType, 'commentId': commentId},
        );
      },
      onZeal: (post, contentType, commentId) {
        final contentId = notification.contentId ?? notification.content?.id ?? post.id ?? '';
        if (contentId.isEmpty) return;
        // Navigate directly to ZealDetailScreen with contentId.
        // The screen fetches full data itself in initState — no intermediate route.
        Get.to(() => ZealDetailScreen(), arguments: {'contentId': contentId, 'commentId': commentId});
      },
      onProfile: (userId) {
        Get.toNamed(AppRoutes.otherUserProfile, arguments: userId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sender = notification.sender;
    final profileImage = sender?.profileImage;
    final isVerifiedBeach = sender?.isVerifiedBadge ?? false;
    final senderName = sender?.username ?? sender?.name ?? 'User';
    final senderId = sender?.id ?? '';
    final message = notification.message ?? '';
    final right = _rightWidget(context);

    return InkWell(
      onTap: () {
        onTap(); // mark as read
        _handleNavigation(); // navigate to the relevant screen
      },
      child: Container(
        color: _isUnread ? AppColors.grayEDF1F4.withValues(alpha: 0.5) : Colors.transparent,
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Gap(4.h),
            if (_isUnread == true) ...[
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(color: AppColors.primaryColor, shape: BoxShape.circle),
              ),
              Gap(4.h),
            ],
            // ── Avatar + badge ─────────────────────────────────────────────
            Stack(
              children: [
                Container(
                  width: 60.w,
                  height: 60.w,
                  padding: EdgeInsets.all(5.sp),
                  child: CommonProfileImage(imageUrl: profileImage, width: 48.w, height: 48.w),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22.w,
                    height: 22.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.whiteFFFFFF, width: 2),
                      gradient: LinearGradient(
                        colors: const [AppColors.primaryColor, AppColors.primaryDark],
                        stops: const [-0.0864, 0.798],
                        transform: GradientRotation((320.33 - 90) * math.pi / 180),
                      ),
                    ),
                    child: Center(child: _badgeIcon(11.sp)),
                  ),
                ),
              ],
            ),
            Gap(12.w),
            // ── Message text + time ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExpandableRichText(
                    senderName: senderName,
                    senderId: senderId,
                    message: message,
                    isVerified: isVerifiedBeach == true,
                  ),
                  // Row(
                  //   children: [
                  //     Text(
                  //       senderName,
                  //       maxLines: 1,
                  //       overflow: TextOverflow.ellipsis,
                  //       style: TextStyles.semiBold(14.sp, fontColor: AppColors.black2F3039),
                  //     ),
                  //
                  //     if (isVerifiedBeach == true) ...[
                  //       Gap(3.h),
                  //       Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                  //     ],
                  //   ],
                  // ),
                  // Gap(4.h),
                  // Text(
                  //   message,
                  //   maxLines: 3,
                  //   overflow: TextOverflow.ellipsis,
                  //   style: TextStyles.medium(14.sp, fontColor: AppColors.gray8C9499),
                  // ),

                  ///  unread message ui update
                  // Row(
                  //   mainAxisAlignment: .start,
                  //   children: [
                  //     Flexible(
                  //       child: Text(
                  //         message,
                  //         maxLines: 3,
                  //         overflow: TextOverflow.ellipsis,
                  //         style: TextStyles.medium(14.sp, fontColor: AppColors.gray8C9499),
                  //       ),
                  //     ),
                  //     Gap(4.h),
                  //     _isUnread == true
                  //         ? Container(
                  //       width: 8.w,
                  //       height: 8.w,
                  //       decoration: BoxDecoration(color: AppColors.primaryColor, shape: BoxShape.circle),
                  //     )
                  //         : SizedBox(),
                  //   ],
                  // ),
                  Gap(4.h),
                  Text(timeAgo, style: TextStyles.medium(12.sp, fontColor: AppColors.gray8C9499)),
                ],
              ),
            ),
            // ── Right side: thumbnail or follow button ─────────────────────
            if (right != null) ...[Gap(12.w), Align(alignment: .centerRight, child: right)],
          ],
        ),
      ),
    );
  }
}

class ExpandableRichText extends StatefulWidget {
  final String senderName;
  final String senderId;
  final String message;
  final bool isVerified;

  const ExpandableRichText({
    super.key,
    required this.senderName,
    required this.message,
    required this.isVerified,
    required this.senderId,
  });

  @override
  State<ExpandableRichText> createState() => _ExpandableRichTextState();
}

class _ExpandableRichTextState extends State<ExpandableRichText> {
  bool isExpanded = false;

  /// Text-only span for measuring overflow. [TextPainter] cannot lay out
  /// [WidgetSpan] (verify badge) — that triggers `dimensions != null` asserts.
  /// Approximate badge + padding width with an em-space after the name.
  TextSpan _measureSpan(TextStyle nameStyle, TextStyle messageStyle) {
    return TextSpan(
      children: [
        TextSpan(text: widget.senderName, style: nameStyle),
        if (widget.isVerified) TextSpan(text: '\u2003', style: nameStyle),
        TextSpan(text: ' ${widget.message}', style: messageStyle),
      ],
    );
  }

  TextSpan _displaySpan(TextStyle nameStyle, TextStyle messageStyle) {
    return TextSpan(
      children: [
        TextSpan(
          text: widget.senderName,
          style: nameStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Get.toNamed(AppRoutes.otherUserProfile, arguments: widget.senderId);
            },
        ),
        if (widget.isVerified)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
            ),
          ),
        TextSpan(text: ' ${widget.message}', style: messageStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameStyle = TextStyles.semiBold(14.sp, fontColor: AppColors.black2F3039);
    final messageStyle = TextStyles.medium(14.sp, fontColor: AppColors.gray8C9499);
    final displaySpan = _displaySpan(nameStyle, messageStyle);
    final measureSpan = _measureSpan(nameStyle, messageStyle);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final tp = TextPainter(
          text: measureSpan,
          maxLines: 3,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: maxW);

        final isOverflowing = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: displaySpan,
              maxLines: isExpanded ? null : 3,
              overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (isOverflowing)
              GestureDetector(
                onTap: () => setState(() => isExpanded = !isExpanded),
                child: Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Text(
                    isExpanded ? 'Read less' : 'Read more',
                    style: TextStyles.medium(12.sp, fontColor: AppColors.primaryColor),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
