import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import '../models/post_list_response_model.dart';
import '../utils/app_constant.dart';
import '../utils/exports.dart';
import 'common_popup_menu.dart';
import 'liked_by_bottom_sheet.dart';

/// Curve that stays at 0 for [delayFraction] of the duration, then eases in out over the rest.
class _DelayedCurve extends Curve {
  const _DelayedCurve({this.delayFraction = 0.2});

  final double delayFraction;

  @override
  double transformInternal(double t) {
    if (t <= delayFraction) return 0.0;
    final t2 = (t - delayFraction) / (1.0 - delayFraction);
    return Curves.easeInOutCubic.transform(t2);
  }
}

/// Represents a single option in a poll
class PollOption {
  final String optionId;
  final String text;
  final int percentage;
  final bool isSelected;

  const PollOption({required this.optionId, required this.text, required this.percentage, required this.isSelected});
}

/// A reusable widget that displays a poll card with author information,
/// poll question, options, and interaction buttons.
class PollCard extends StatelessWidget {
  final PostData postData;
  final VoidCallback? onSave;
  final VoidCallback? onReport;
  final VoidCallback? onCopyLink;
  final VoidCallback? onDelete;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;
  final VoidCallback? onMoreOptions;

  /// Called with [optionId] when user taps an option (only when [hasVoted] is false and not [isExpired]).
  final void Function(String optionId)? onOptionTap;
  final bool hasVoted;
  final String? votedOptionId;

  /// When true, voting is disabled and results are shown (like after vote); optional "Poll ended" label.
  final bool isExpired;
  final bool isSaved;
  final bool isNavigation;

  PollCard({
    super.key,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onBookmark,
    this.onMoreOptions,
    this.onOptionTap,
    this.hasVoted = false,
    this.votedOptionId,
    this.isExpired = false,
    this.onSave,
    this.onReport,
    this.onCopyLink,
    this.onDelete,
    required this.postData,
    this.isSaved = false,
    this.isNavigation = true,
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
          // User Header
          Padding(
            padding: EdgeInsets.only(right: 16.w, left: 16.w, bottom: 10.h, top: 5.h),
            child: Row(
              children: [
                /// Profile + name section
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final targetUserId = postData.userId?.id?.trim() ?? '';
                      if (targetUserId.isEmpty) return;
                      if (!isNavigation) return;
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
                GestureDetector(
                  key: moreOptionsKey,
                  onTap: () {
                    final isCurrentUserPost = postData.userId?.id == PrefService.getString(PrefKeys.userId);
                    final isSaved = postData.isSaved ?? false;
                    CommonPopupMenu.show(
                      post: postData,
                      context: context,
                      anchorKey: moreOptionsKey,
                      isSave: isSaved,
                      onSave: onSave ?? () {},
                      onReport: onReport ?? () {},
                      onCopyLink: onCopyLink ?? () {},
                      onShare: onShare ?? () {},
                      onDelete: onDelete ?? () {},
                      showDelete: isCurrentUserPost,
                      deleteContentId: postData.id,
                      deleteContentType: postData.contentType ?? 'Poll',
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.h, vertical: 8.w),
                    child: Icon(Icons.more_horiz, color: AppColors.black2F3039, size: 20.sp),
                  ),
                ),
              ],
            ),
          ),
          Gap(5.h),
          // Poll Question
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCaptionWithMentions(
                  postData.caption ?? postData.content ?? 'Poll',
                  postData.mentionedUsers,
                  16.sp,
                ),
                // if (isExpired) ...[
                //   Gap(6.h),
                //   Text('Poll ended', style: TextStyles.regular(12.sp, fontColor: AppColors.gray707070)),
                // ],
              ],
            ),
          ),
          Gap(16.h),
          // Poll Options
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: getOptions().map((option) {
                return _buildPollOption(option);
              }).toList(),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              postData.duration != null && DateTime.tryParse(postData.duration!) != null
                  ? timeRemaining(DateTime.parse(postData.duration!))
                  : '',
              style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
            ),
          ),
          Gap(16.h),
          // Interaction Icons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                          contentType: postData.contentType ?? 'Poll',
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
                      Assets.icons.icComment.svg(width: 20.w, height: 20.h),
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
                PressScaleButton(
                  onTap: onShare,
                  child: Assets.icons.icShare.svg(width: 20.w, height: 20.h),
                ),
                const Spacer(),
                // Bookmark
                PressScaleButton(
                  onTap: onBookmark,
                  child: (postData.isSaved ?? false) ? Assets.icons.icSaveFill.svg() : Assets.icons.icSave.svg(),
                ),
              ],
            ),
          ),
          Gap(14.h),
          // Divider
          Container(height: 5.h, width: double.infinity, color: AppColors.grayEDF1F4),
        ],
      ),
    );
  }

  /// Builds caption text with @mentions highlighted and tappable.
  Widget _buildCaptionWithMentions(String text, List<UserId>? mentionedUsers, double fontSize) {
    if (text.isEmpty) return const SizedBox.shrink();

    final baseStyle = TextStyles.regular(fontSize, fontColor: AppColors.black2F3039);
    final mentionStyle = TextStyles.regular(fontSize, fontColor: AppColors.primaryColor);
    final list = mentionedUsers ?? [];
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
              ..onTap = () => Get.toNamed(AppRoutes.otherUserProfile, arguments: matchedUser!.id),
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

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  /// Duration for the selected option bar fill animation (slower for a clear filling feel).
  static const _selectedBarDuration = Duration(milliseconds: 1800);

  /// Duration for unselected option bars (slightly longer so they animate after selected).
  static const _unselectedBarDuration = Duration(milliseconds: 2200);

  /// Delay before unselected options start filling (selected animates first).
  static const _unselectedDelayFraction = 0.25;

  /// Fill color for unselected options when answer is already filled (clearly different from primary).
  static const _unselectedBarColor = AppColors.lightPrimaryColor;

  Widget _buildPollOption(PollOption option) {
    final isSelected = option.optionId == votedOptionId;
    final showResults = hasVoted || isExpired; // Show percentages and bars when voted or poll ended
    final canTap = !hasVoted && !isExpired && onOptionTap != null;
    // When already voted or poll expired: show bar at final percentage, no animation.
    // When not voted and active: bar at 0; after tap we animate to percentage.
    final endFraction = showResults ? (option.percentage / 100) : 0.0;
    final skipAnimation = showResults; // No animation when showing final state (voted or expired)

    final duration = skipAnimation ? Duration.zero : (isSelected ? _selectedBarDuration : _unselectedBarDuration);
    final curve = skipAnimation
        ? Curves.linear
        : (isSelected ? Curves.easeInOutCubic : const _DelayedCurve(delayFraction: _unselectedDelayFraction));

    return GestureDetector(
      onTap: canTap ? () => onOptionTap!(option.optionId) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.whiteE5E5E5),
          borderRadius: BorderRadius.circular(10.r),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Bar layer (behind): Positioned.fill gets Stack size from the content child below
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return TweenAnimationBuilder<double>(
                    key: ValueKey('${option.optionId}_${option.percentage}_${hasVoted}_$isExpired'),
                    tween: Tween(begin: 0, end: endFraction),
                    duration: duration,
                    curve: curve,
                    builder: (context, value, child) {
                      final showBar = value > 0;
                      // When answer is filled: selected option = primary gradient, other options = distinct fill color
                      final usePrimary = isSelected && showBar;
                      final useUnselectedColor = !isSelected && showBar;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * value,
                          height: constraints.maxHeight,
                          decoration: BoxDecoration(
                            gradient: usePrimary
                                ? LinearGradient(
                                    colors: const [AppColors.primaryColor, AppColors.primaryDark],
                                    stops: const [-0.0864, 0.798],
                                    transform: GradientRotation((320.33 - 90) * math.pi / 180),
                                  )
                                : null,
                            color: useUnselectedColor ? _unselectedBarColor : null,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Content on top (defines Stack size)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Row(
                children: [
                  if (isSelected) Assets.icons.icCheck.svg(width: 20.w, height: 20.h),
                  if (isSelected) SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      option.text,
                      style: TextStyles.regular(
                        14.sp,
                        fontColor: isSelected ? AppColors.whiteEAEAEA : AppColors.black2F3039,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (showResults)
                    Text(
                      '${option.percentage}%',
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
      ),
    );
  }

  List getOptions() {
    final pollOptions = postData.options ?? [];
    return pollOptions.isEmpty
        ? [
            const PollOption(optionId: '', text: 'Option 1', percentage: 0, isSelected: false),
            const PollOption(optionId: '', text: 'Option 2', percentage: 0, isSelected: false),
          ]
        : pollOptions
              .map(
                (o) => PollOption(
                  optionId: o.optionId ?? '',
                  text: o.optionText ?? '',
                  percentage: o.votePercentage ?? 0,
                  isSelected: o.selectedByAuthUser == true,
                ),
              )
              .toList();
  }

  String getTitle() {
    final caption = postData.caption ?? postData.content ?? '';
    final lines = caption.split('\n').where((e) => e.trim().isNotEmpty).toList().first;
    return lines;
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

  static String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final d = DateTime.now().difference(date);
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }
}
