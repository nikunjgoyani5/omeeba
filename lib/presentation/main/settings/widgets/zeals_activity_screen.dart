import 'package:omeeba_new/core/widgets/common_app_bar.dart';
import '../../../../core/models/post_list_response_model.dart';
import '../../../../core/utils/exports.dart';
import '../../../../core/widgets/common_network_image.dart';
import '../../explore/widgets/explore_grid_shimmer.dart';
import '../../myprofile/controller/my_profile_controller.dart';
import '../../zeals/views/zeal_detail_screen.dart';

class ZealsActivityScreen extends StatelessWidget {
  ZealsActivityScreen({super.key});

  final controller = Get.find<MyProfileController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const CommonAppBar(title: "Zeals"),
      body: StreamBuilder<PostDataResponse?>(
        stream: controller.myZealsData.stream,
        builder: (context, asyncSnapshot) {
          final zeals = controller.myZealsData.value?.posts ?? [];
          final isLoading = controller.myZealsLoading.value;
          final isLoadMore = controller.myZealsLoadMoreLoading.value;

          /// ===== Loading =====
          if (isLoading && zeals.isEmpty) {
            return Padding(padding: EdgeInsets.all(8.w), child: const ExploreGridShimmer());
          }

          /// ===== Empty =====
          if (!isLoading && zeals.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: () => controller.loadMyZeals(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 1.sh - kToolbarHeight.h,
                    child: Center(child: _emptyState()),
                  ),
                ],
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (scroll) {
              if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 300) {
                controller.loadMoreMyZeals();
              }
              return false;
            },
            child: RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: () => controller.loadMyZeals(force: true),
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(3.w),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2.w,
                  mainAxisSpacing: 2.w,
                  childAspectRatio: 0.7,
                ),
                itemCount: zeals.length + (isLoadMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= zeals.length) {
                    return const Center(
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  final zeal = zeals[index];

                  return _ZealGridItem(
                    post: zeal,
                    onTap: () {
                      Get.to(() => ZealDetailScreen(), arguments: zeal)?.then((result) {
                        if (result is String) {
                          controller.removeZealById(result);
                        }
                      });
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

  /// ===============================
  /// Empty State
  /// ===============================
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(color: AppColors.orangeF8F1EB, shape: BoxShape.circle),
            child: Assets.icons.icPlaceholderZeel.svg(),
          ),
          Gap(15.h),
          Text('No zeals yet', style: TextStyles.semiBold(22.sp, fontColor: AppColors.black2F3039)),
        ],
      ),
    );
  }
}

/// ===============================
/// Zeal Grid Item
/// ===============================
class _ZealGridItem extends StatelessWidget {
  final PostData post;
  final VoidCallback onTap;

  const _ZealGridItem({required this.post, required this.onTap});

  String? get _thumbnailUrl {
    final images = post.images;
    if (images != null && images.isNotEmpty) return images.first;
    if (post.thumbnailUrl?.isNotEmpty == true) {
      return post.thumbnailUrl;
    }
    if (post.mediaUrl?.isNotEmpty == true) {
      return post.mediaUrl;
    }
    final videos = post.videos;
    if (videos != null && videos.isNotEmpty) return videos.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = _thumbnailUrl != null
        ? CommonNetworkImage(imageUrl: _thumbnailUrl!, fit: BoxFit.cover, memCacheWidth: 250, memCacheHeight: null)
        : Container(
            color: AppColors.grayEDF1F4,
            child: Assets.icons.icImgPlaceholder.image(fit: BoxFit.cover),
          );

    return GestureDetector(onTap: onTap, child: imageWidget);
  }
}
