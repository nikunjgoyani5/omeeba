import 'package:flutter/services.dart';

import '../../../../core/helper/like_helper.dart';
import '../../../../core/models/post_list_response_model.dart';
import '../../../../core/utils/exports.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/poll_card.dart';
import '../../explore/widgets/poll_list_shimmer.dart';
import '../../home/widgets/share_bottom_sheet.dart';
import '../../myprofile/controller/my_profile_controller.dart';
import '../../report/controller/report_controller.dart';
import '../../report/view/report_bottom_sheet.dart';
import '../../zeals/widget/comments_bottom_sheet.dart';

class PollsActivityScreen extends StatelessWidget {
  PollsActivityScreen({super.key});

  final controller = Get.find<MyProfileController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      appBar: const CommonAppBar(title: "Polls"),
      body: StreamBuilder<PostDataResponse?>(
        stream: controller.myPollsData.stream,
        builder: (context, asyncSnapshot) {
          final isLoading = controller.myPollsLoading.value;
          final polls = controller.myPollsData.value?.posts ?? [];
          final isLoadMore = controller.myPollsLoadMoreLoading.value;

          if (isLoading && polls.isEmpty) {
            return const PollListShimmer();
          }

          if (!isLoading && polls.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: () => controller.loadMyPolls(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 1.sh - kToolbarHeight.h,
                    child: Center(
                      child: _emptyState(
                        icon: Assets.icons.icSavePolls.svg(),
                        message: 'No polls yet',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (scroll) {
              if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200) {
                controller.loadMoreMyPolls();
              }
              return false;
            },
            child: RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: () => controller.loadMyPolls(force: true),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: polls.length + (isLoadMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == polls.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  final post = polls[index];
                  return _pollItem(post, context, index);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pollItem(PostData post, BuildContext context, int index) {
    final pollOptions = post.options ?? [];

    int maxPercent = 0;
    for (final o in pollOptions) {
      final p = o.votePercentage ?? 0;
      if (p > maxPercent) maxPercent = p;
    }

    return PollCard(
      key: ValueKey('explore_poll_${post.id}'),
      postData: post,
      onLike: () {
        LikeHelper.toggleLike(
          contentId: post.id ?? '',
          contentType: post.contentType ?? 'Poll',
          isLiked: post.isLiked ?? false,
          likeCount: post.likeCount ?? 0,
          onLocalUpdate: (liked, count) {
            post.isLiked = liked;
            post.likeCount = count;
          },
        );
      },
      onSave: () {
        controller.saveUnSavePost(context, post.contentType ?? 'Poll', post.id ?? '', controller.myPollsData, index);
      },
      onComment: () {
        CommentsBottomSheet.show(
          postId: post.id ?? '',
          commentsCount: post.commentCount ?? 0,
          contentType: post.contentType ?? 'Poll',
          onCommentAdded: (newCount) {
            controller.myPollsData.update((data) {
              data!.posts![index].commentCount = newCount;
            });
          },
        );
      },
      onBookmark: () {
        controller.saveUnSavePost(context, post.contentType ?? 'Poll', post.id ?? '', controller.myPollsData, index);
      },
      onShare: () {
        ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
      },
      onCopyLink: () {
        Clipboard.setData(ClipboardData(text: post.shareableLink ?? "demo"));
      },
      onDelete: () {
        controller.removePollPostById(post.id ?? '');
      },
      hasVoted: post.displayHasVoted,
      votedOptionId: post.displayVotedOptionId,
      isExpired: post.isPollExpired,
      onReport: () {
        Get.find<ReportController>().reset();
        Get.find<ReportController>().getReportsCategories(context);
        ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Poll');
      },
      onOptionTap: (optionId) => controller.submitPollVote(post.id!, optionId),
    );
  }

  Widget _emptyState({required Widget icon, required String message, String? subtitle}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(color: AppColors.orangeF8F1EB, shape: BoxShape.circle),
          child: icon,
        ),
        Gap(15.h),
        Text(
          message,
          style: TextStyles.semiBold(22.sp, fontColor: AppColors.black2F3039),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          Gap(8.h),
          Text(subtitle, style: TextStyles.medium(15.sp, fontColor: AppColors.blue3382FF)),
        ],
      ],
    );
  }
}
