import 'package:omeeba_new/core/widgets/common_app_bar.dart';
import 'package:omeeba_new/core/widgets/common_write_post_item.dart';
import '../../../../core/helper/like_helper.dart';
import '../../../../core/models/post_list_response_model.dart';
import '../../../../core/utils/exports.dart';
import '../../explore/widgets/explore_list_shimmer.dart';
import '../../home/widgets/share_bottom_sheet.dart';
import '../../myprofile/controller/my_profile_controller.dart';
import '../../report/controller/report_controller.dart';
import '../../report/view/report_bottom_sheet.dart';
import '../../zeals/widget/comments_bottom_sheet.dart';

class WritesActivityScreen extends StatelessWidget {
  WritesActivityScreen({super.key});

  final MyProfileController controller = Get.find<MyProfileController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      appBar: CommonAppBar(title: 'Writes'),
      body: StreamBuilder<PostDataResponse?>(
        stream: controller.myWritesData.stream,
        builder: (context, asyncSnapshot) {
          final writes = controller.myWritesData.value?.posts ?? [];
          final isLoading = controller.myWritesLoading.value;
          final isLoadMore = controller.myWritesLoadMoreLoading.value;

          if (isLoading && writes.isEmpty) {
            return const ExploreListShimmer();
          }

          if (!isLoading && writes.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: () => controller.loadMyWrites(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 1.sh - kToolbarHeight.h, // Full screen height using ScreenUtil
                    child: Center(
                      child: _emptyState(
                        icon: Assets.icons.icSaveWrite.svg(),
                        message: 'No writes yet',
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
                controller.loadMoreMyWrites();
              }
              return false;
            },
            child: RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: () => controller.loadMyWrites(force: true),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: writes.length + (isLoadMore ? 1 : 0),
                itemBuilder: (context, index) {
                  /// Pagination loader
                  if (index >= writes.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  final post = writes[index];

                  return CommonWritePostItem(
                    postData: post,
                    onReport: () {
                      Get.find<ReportController>().reset();
                      Get.find<ReportController>().getReportsCategories(context);
                      ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Post');
                    },

                    onSave: () {
                      controller.saveUnSavePost(
                        context,
                        post.contentType ?? '',
                        post.id ?? '',
                        controller.myWritesData,
                        index,
                      );
                    },
                    onComment: () {
                      CommentsBottomSheet.show(
                        postId: post.id ?? '',
                        commentsCount: post.commentCount ?? 0,
                        contentType: post.contentType ?? '',
                        onCommentAdded: (newCount) {
                          controller.myWritesData.update((data) {
                            data!.posts![index].commentCount = newCount;
                          });
                        },
                      );
                    },
                    onBookmark: () {
                      controller.saveUnSavePost(
                        context,
                        post.contentType ?? '',
                        post.id ?? '',
                        controller.myWritesData,
                        index,
                      );
                    },
                    onShare: () {
                      ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
                    },
                    onDelete: () {
                      controller.removeWritePostById(post.id ?? '');
                    },
                    onLike: () {
                      LikeHelper.toggleLike(
                        contentId: post.id ?? '',
                        contentType: post.contentType ?? 'Post',
                        isLiked: post.isLiked ?? false,
                        likeCount: post.likeCount ?? 0,
                        onLocalUpdate: (liked, count) {
                          post.isLiked = liked;
                          post.likeCount = count;
                        },
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState({required Widget icon, required String message, String? subtitle}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(color: AppColors.orangeF8F1EB, shape: BoxShape.circle),
          child: icon,
        ),
        Gap(15.h),
        Text(message, style: TextStyles.semiBold(22.sp, fontColor: AppColors.black2F3039)),
        if (subtitle != null) ...[
          Gap(8.h),
          Text(subtitle, style: TextStyles.medium(15.sp, fontColor: AppColors.blue3382FF)),
        ],
      ],
    );
  }
}

/// Data model for write post
class WritePostData {
  final String authorName;
  final String timeAgo;
  final String? profileImageUrl;
  final String postTitle;
  final List<String> bulletPoints;
  int likesCount;
  final int commentsCount;
  bool isLiked;
  bool isBookmarked;

  WritePostData({
    required this.authorName,
    required this.timeAgo,
    this.profileImageUrl,
    required this.postTitle,
    required this.bulletPoints,
    required this.likesCount,
    required this.commentsCount,
    this.isLiked = false,
    this.isBookmarked = false,
  });
}
