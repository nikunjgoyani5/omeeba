import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import '../models/post_list_response_model.dart';
import '../utils/app_constant.dart';
import '../utils/exports.dart';
import 'common_popup_menu.dart';
import 'liked_by_bottom_sheet.dart';

/// Reusable widget for displaying a write post item
/// Matches the Figma design with profile, content, and engagement icons
class CommonWritePostItem extends StatelessWidget {
  final PostData postData;
  final UserId? userId;
  final bool isLiked;
  final bool isBookmarked;
  final bool isNavigation;
  final VoidCallback? onSave;
  final VoidCallback? onReport;
  final VoidCallback? onDelete;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;
  final VoidCallback? onMoreOptions;

  CommonWritePostItem({
    super.key,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onBookmark,
    this.isLiked = false,
    this.isBookmarked = false,
    this.onMoreOptions,
    this.onSave,
    this.onReport,

    this.onDelete,
    required this.postData,
    this.userId,
    this.isNavigation =true,
  });

  final GlobalKey moreOptionsKey = GlobalKey();
  final ValueNotifier<int> likeCount = ValueNotifier(0);
  final ValueNotifier<bool> isLike = ValueNotifier(false);

  void _init() {
    likeCount.value = postData.likeCount ?? 0;
    isLike.value = postData.isLiked ?? false;
  }

  @override
  Widget build(BuildContext context) {
    _init();
    return Container(
      color: AppColors.whiteFFFFFF,
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right:  16.w,left:   16.w,bottom: 10.h,top: 5.h),
            child: Row(
              children: [
                /// Profile + name section
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final targetUserId = postData.userId?.id?.trim() ?? '';
                      if (targetUserId.isEmpty) return;
                      if(!isNavigation) return;
                      Get.toNamed(
                        AppRoutes.otherUserProfile,
                        arguments: {'userId': targetUserId},
                        preventDuplicates: false,
                      );
                    },
                    child: Row(
                      children: [
                        CommonProfileImage(
                          imageUrl: postData.userId?.profileImage is String
                              ? postData.userId!.profileImage as String?
                              : null,
                          width: 35.w,
                          height: 35.h,
                        ),

                        SizedBox(width: 12.w),

                        /// Username
                        Flexible(
                          child: Text(
                            postData.userId?.name ?? postData.userId?.username ?? 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.medium(16.sp, fontColor: AppColors.gray707070),
                          ),
                        ),

                        Gap(3.w),
                        if (postData.userId?.isVerifiedBadge == true) ...[
                          Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                          Gap(5.w),
                        ],
                        Container(
                          height: 6.h,
                          width: 6.w,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.whiteEAEAEA),
                        ),

                        Gap(5.w),

                        Text(
                          _timeAgo(postData.createdAt),
                          style: TextStyles.medium(16.sp, fontColor: AppColors.gray707070),
                        ),
                        Gap(5.w),
                      ],
                    ),
                  ),
                ),

                /// More options button
                PressScaleButton(
                  onTap: () {
                    final isCurrentUserPost = postData.userId?.id == PrefService.getString(PrefKeys.userId);
                    final isSave = postData.isSaved ?? true;
                    String shareableLink = postData.shareableLink ?? "Unavailable";

                    CommonPopupMenu.show(
                      context: context,
                      anchorKey: moreOptionsKey,
                      isSave: isSave,
                      onSave: onSave ?? () {},
                      onReport: onReport ?? () {},
                      onCopyLink: () => Clipboard.setData(ClipboardData(text: shareableLink)),
                      onShare: onShare ?? () {},
                      onDelete: onDelete ?? () {},
                      showDelete: isCurrentUserPost,
                      deleteContentId: postData.id,
                      deleteContentType: postData.contentType,
                      post: postData
                    );
                  },
                  child: KeyedSubtree(
                    key: moreOptionsKey,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.h, vertical: 8.w),
                      child: Icon(Icons.more_horiz, color: AppColors.black2F3039, size: 20.sp),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 1.h),
          // Post Content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Post Title with @mentions highlighted and tappable + "Read more / Read less"
                _ExpandableCaptionWithMentions(
                  text: getTitle(),
                  mentionedUsers: postData.mentionedUsers,
                  fontSize: 16.sp,
                ),
                // SizedBox(height: 8.h),
                // Bullet Points
                // ...bulletPoints.map(
                //   (point) => Padding(
                //     padding: EdgeInsets.only(bottom: 4.h),
                //     child: Row(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         Text('• ', style: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039)),
                //         Expanded(
                //           child: Text(point, style: TextStyles.regular(14.sp, fontColor: AppColors.black2F3039)),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // Engagement Icons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                // Like
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (isLike.value) {
                          likeCount.value = likeCount.value - 1;
                          isLike.value = false;
                        } else {
                          likeCount.value = likeCount.value + 1;
                          isLike.value = true;
                        }
                        onLike?.call();
                      },
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isLike,
                        builder: (_, liked, __) {
                          return liked ? Assets.icons.icLike.svg() : Assets.icons.icLikeBorder.svg();
                        },
                      ),
                    ),
                    SizedBox(width: 4.w),
                    PressScaleButton(
                      onTap: () {
                        LikedByBottomSheet.show(
                          context: context,
                          contentId: postData.id ?? '',
                          contentType: postData.contentType ?? 'Write Post',
                        );
                      },
                      child: ValueListenableBuilder<int>(
                        valueListenable: likeCount,
                        builder: (_, value, __) {
                          return Text(
                            formatCount(value),
                            style: TextStyles.regular(14.sp, fontColor: AppColors.black2F3039),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 20.w),
                // Comment
                PressScaleButton(
                  onTap: onComment,
                  child: Row(
                    children: [
                      Assets.icons.icComment.svg(),
                      SizedBox(width: 4.w),
                      Text(
                        "${postData.commentCount ?? 0}",
                        style: TextStyles.regular(14.sp, fontColor: AppColors.black2F3039),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20.w),
                // Share
                PressScaleButton(onTap: onShare, child: Assets.icons.icShare.svg()),
                const Spacer(),
                // Bookmark
                PressScaleButton(
                  onTap: onBookmark,
                  child: (postData.isSaved ?? false)
                      ? Assets.icons.icSaveFill.svg()
                      : Assets.icons.icSave.svg(),
                ),
              ],
            ),
          ),
          Gap(2),
          Container(height: 5, width: double.infinity, color: AppColors.grayEDF1F4),
        ],
      ),
    );
  }

  String getTitle() {
    final caption = postData.caption ?? postData.content ?? '';
    return caption.trim();
  }

  static String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final d = DateTime.now().difference(date);
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }
}

class _ExpandableCaptionWithMentions extends StatefulWidget {
  final String text;
  final List<UserId>? mentionedUsers;
  final double fontSize;

  const _ExpandableCaptionWithMentions({
    required this.text,
    required this.mentionedUsers,
    required this.fontSize,
  });

  @override
  State<_ExpandableCaptionWithMentions> createState() => _ExpandableCaptionWithMentionsState();
}

class _ExpandableCaptionWithMentionsState extends State<_ExpandableCaptionWithMentions> {
  static const int _collapsedMaxLines = 6;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (text.isEmpty) return const SizedBox.shrink();

    final baseStyle = TextStyles.regular(widget.fontSize, fontColor: AppColors.black2F3039);
    final mentionStyle = TextStyles.regular(widget.fontSize, fontColor: AppColors.primaryColor);
    final list = widget.mentionedUsers ?? [];
    final List<InlineSpan> spans = [];
    final mentionRegex = RegExp(r'@(\w+)');
    int lastIndex = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: baseStyle));
      }
      final username = match.group(1) ?? '';
      UserId? matchedUser;
      for (final u in list) {
        if (u.username == username) {
          matchedUser = u;
          break;
        }
      }
      if (matchedUser != null && (matchedUser.id ?? '').isNotEmpty) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: mentionStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => Get.toNamed(
                AppRoutes.otherUserProfile,
                arguments: {'userId': matchedUser!.id},
                preventDuplicates: false,
              ),
          ),
        );
      } else {
        spans.add(TextSpan(text: match.group(0), style: baseStyle));
      }
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Always measure with collapsed line limit. If we use maxLines: null here,
        // didExceedMaxLines is false when expanded — the "Read less" row vanishes.
        final collapsePainter = TextPainter(
          text: TextSpan(children: spans, style: baseStyle),
          maxLines: _collapsedMaxLines,
          textDirection: Directionality.of(context),
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);

        final needsToggle = collapsePainter.didExceedMaxLines;
        final displayMaxLines = _isExpanded ? null : _collapsedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(children: spans, style: baseStyle),
              maxLines: displayMaxLines,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (needsToggle)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    _isExpanded ? 'Read less' : 'Read more',
                    style: TextStyles.semiBold(
                      14.sp,
                      fontColor: AppColors.gray707070,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
