import 'package:omeeba_new/core/widgets/common_app_bar.dart';
import '../../../../core/models/post_list_response_model.dart';
import '../../../../core/utils/exports.dart';
import '../../../../core/widgets/common_network_image.dart';
import '../../explore/widgets/explore_grid_shimmer.dart';
import '../../myprofile/controller/my_profile_controller.dart';

class PostActivityScreen extends StatelessWidget {
  PostActivityScreen({super.key});

  // final Set<int> _selectedIndices = {};
  final controller = Get.find<MyProfileController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const CommonAppBar(title: "Posts"),
      body: StreamBuilder<PostDataResponse?>(
        stream: controller.myPostsData.stream,
        builder: (context, asyncSnapshot) {
          final posts = controller.myPostsData.value?.posts ?? [];
          final isLoading = controller.myPostsLoading.value;
          final isLoadMore = controller.myPostsLoadMoreLoading.value;

          if (isLoading && posts.isEmpty) {
            return Padding(padding: EdgeInsets.all(8.w), child: const ExploreGridShimmer());
          }

          if (!isLoading && posts.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: () => controller.loadMyPosts(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 1.sh - kToolbarHeight.h,
                    child: Center(
                      child: _emptyState(
                        icon: Assets.icons.icPostPlaceholder.svg(),
                        message: 'No post yet',

                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (scroll) {
              if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 300) {
                controller.loadMoreMyPosts();
              }
              return false;
            },
            child: RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: () => controller.loadMyPosts(force: true),
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(3.w),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2.w,
                  mainAxisSpacing: 2.w,
                  childAspectRatio: 0.8,
                ),
                itemCount: posts.length + (isLoadMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= posts.length) {
                    return const Center(
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  final post = posts[index];
                  final images = post.images ?? [];
                  final imageCount = images.length;
                  //    final isSelected = _selectedIndices.contains(index);
                  final isPostType = post.contentType == null || post.contentType == 'Post';
                  return GestureDetector(
                    onTap: () => _navigateToPostDetail(post, index, isPostType ? 'profile_post_$index' : null),
                    // onLongPress: () {
                    //   isSelected ? _selectedIndices.remove(index) : _selectedIndices.add(index);
                    // },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ProfileSquareGridItem(
                          post: post,
                          index: index,
                          heroTagPrefix: isPostType ? 'profile_post_$index' : null,
                          onTap: () => _navigateToPostDetail(post, index, isPostType ? 'profile_post_$index' : null),
                        ),

                        // if (isSelected)
                        //   Container(
                        //     color: AppColors.black000000.withValues(alpha: 0.3),
                        //     child: Center(
                        //       child: Container(
                        //         width: 24.w,
                        //         height: 24.w,
                        //         decoration: BoxDecoration(
                        //           color: AppColors.primaryColor,
                        //           shape: BoxShape.circle,
                        //           border: Border.all(color: AppColors.whiteFFFFFF, width: 2.w),
                        //         ),
                        //         child: Icon(Icons.check, size: 16.sp, color: AppColors.whiteFFFFFF),
                        //       ),
                        //     ),
                        //   ),
                        if (imageCount > 1)
                          Positioned(
                            top: 8.h,
                            right: 8.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: AppColors.black000000.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(15.r),
                              ),
                              child: Text(
                                '1/$imageCount+',
                                style: TextStyles.regular(10.sp, fontColor: AppColors.whiteFFFFFF),
                              ),
                            ),
                          ),
                      ],
                    ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }

  void _navigateToPostDetail(PostData post, [int? index, String? heroTagPrefix]) {
    final c = controller;
    Get.toNamed(
      AppRoutes.postContentDetail,
      arguments: {'post': post, if (heroTagPrefix != null && heroTagPrefix.isNotEmpty) 'heroTagPrefix': heroTagPrefix},
    )?.then((result) {
      if (result is String) {
        c.removePostById(result);
        c.removeTaggedPostById(result);
      }
    });
  }
}

class _ProfileSquareGridItem extends StatelessWidget {
  final PostData post;
  final int index;
  final String? heroTagPrefix;
  final VoidCallback onTap;

  const _ProfileSquareGridItem({required this.post, required this.onTap, required this.index, this.heroTagPrefix});

  String? get _thumbnailUrl {
    final images = post.images;
    if (images != null && images.isNotEmpty) return images.first;
    if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty) return post.thumbnailUrl;
    if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) return post.mediaUrl;
    final videos = post.videos;
    if (videos != null && videos.isNotEmpty) return videos.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageTag = heroTagPrefix != null ? '${heroTagPrefix!}_image_0' : null;
    final imageWidget = _thumbnailUrl != null
        ? CommonNetworkImage(imageUrl: _thumbnailUrl!, fit: BoxFit.cover, memCacheWidth: 250, memCacheHeight: null)
        : Container(
            color: AppColors.grayEDF1F4,
            child: Assets.icons.icImgPlaceholder.image(fit: BoxFit.cover),
          );
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [imageTag != null ? Hero(tag: imageTag, child: imageWidget) : imageWidget],
      ),
    );
  }
}
