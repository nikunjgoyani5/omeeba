import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';
import 'package:omeeba_new/core/widgets/common_app_bar.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/core/widgets/common_post_detail_widget.dart';
import 'package:omeeba_new/core/widgets/common_write_post_item.dart';
import 'package:omeeba_new/core/widgets/poll_card.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import 'package:omeeba_new/presentation/main/zeals/widget/comments_bottom_sheet.dart';

import '../../../../core/helper/like_helper.dart';
import '../../home/widgets/share_bottom_sheet.dart';
import '../../report/controller/report_controller.dart';
import '../../report/view/report_bottom_sheet.dart';
import '../../zeals/views/zeal_detail_screen.dart';
import '../controller/settings_controller.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/explore_grid_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/explore_list_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/poll_list_shimmer.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _selectedViewIndex = 0;
  late PageController _pageController;
  late SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedViewIndex);
    _controller = Get.find<SettingsController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadSavedContent(0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_selectedViewIndex == index) return;
    setState(() => _selectedViewIndex = index);
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    _controller.loadSavedContent(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      appBar: CommonAppBar(title: "Saved", bottomLine: false),
      body: Column(
        children: [
          _SavedFilterBar(selectedIndex: _selectedViewIndex, onTabTapped: _onTabTapped),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (_selectedViewIndex != index) {
                  setState(() => _selectedViewIndex = index);
                  _controller.loadSavedContent(index);
                }
              },
              children: [
                _SavedTabView(tabIndex: 0),
                _SavedTabView(tabIndex: 1),
                _SavedTabView(tabIndex: 2),
                _SavedTabView(tabIndex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedFilterBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabTapped;

  const _SavedFilterBar({required this.selectedIndex, required this.onTabTapped});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        border: Border(bottom: BorderSide(color: AppColors.whiteEAEAEA, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _FilterIcon(
              icon: Assets.icons.icSavePost,
              index: 0,
              isSelected: selectedIndex == 0,
              onTap: () => onTabTapped(0),
            ),
          ),
          Expanded(
            child: _FilterIcon(
              icon: Assets.icons.icSaveZeals,
              index: 1,
              isSelected: selectedIndex == 1,
              onTap: () => onTabTapped(1),
            ),
          ),
          Expanded(
            child: _FilterIcon(
              icon: Assets.icons.icSaveWrite,
              index: 2,
              isSelected: selectedIndex == 2,
              onTap: () => onTabTapped(2),
            ),
          ),
          Expanded(
            child: _FilterIcon(
              icon: Assets.icons.icSavePolls,
              index: 3,
              isSelected: selectedIndex == 3,
              onTap: () => onTabTapped(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterIcon extends StatelessWidget {
  final SvgGenImage icon;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterIcon({required this.icon, required this.index, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? AppColors.black000000 : Colors.transparent, width: 2)),
        ),
        child: icon.svg(
          colorFilter: ColorFilter.mode(isSelected ? AppColors.black000000 : AppColors.gray8C9499, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _SavedTabView extends StatelessWidget {
  final int tabIndex;

  const _SavedTabView({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SettingsController>();
    return Obx(() {
      final list = tabIndex == 0
          ? c.savedPosts
          : tabIndex == 1
          ? c.savedZeals
          : tabIndex == 2
          ? c.savedWrites
          : c.savedPolls;
      final loading = tabIndex == 0
          ? c.savedPostsLoading.value
          : tabIndex == 1
          ? c.savedZealsLoading.value
          : tabIndex == 2
          ? c.savedWritesLoading.value
          : c.savedPollsLoading.value;
      final loadMore = tabIndex == 0
          ? c.savedPostsLoadMoreLoading.value
          : tabIndex == 1
          ? c.savedZealsLoadMoreLoading.value
          : tabIndex == 2
          ? c.savedWritesLoadMoreLoading.value
          : c.savedPollsLoadMoreLoading.value;

      if (loading && list.isEmpty) {
        if (tabIndex == 3) return const PollListShimmer();
        if (tabIndex == 2) return const ExploreListShimmer();
        return const ExploreGridShimmer();
      }
      if (!loading && list.isEmpty) {
        return _EmptyState(message: _emptyMessageForTab(tabIndex), icon: _emptyIconForTab(tabIndex));
      }

      if (tabIndex == 0) {

        return RefreshIndicator(
          onRefresh: () => c.loadSavedContent(tabIndex, refresh: true),
          color: AppColors.primaryColor,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification n) {
              if (n is ScrollEndNotification  && !loadMore) {
                final m = n.metrics;
                if (m.pixels >= m.maxScrollExtent - 200) {
                  c.loadMoreSavedContent(tabIndex);
                }
              }
              return false;
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: GridView.builder(
                padding: EdgeInsets.only(bottom: 80.h),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5.w,
                  mainAxisSpacing: 5.w,
                  childAspectRatio: 0.7,
                ),
                itemCount: list.length + (loadMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= list.length) {
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
                  final post = list[index];
                  return _SavedThumbnail(post: post, tabIndex: tabIndex);
                },
              ),
            ),
          ),
        );
      }

      if(tabIndex == 1){
        return RefreshIndicator(
          onRefresh: () => c.loadSavedContent(tabIndex, refresh: true),
          color: AppColors.primaryColor,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification n) {
              if (n is ScrollEndNotification  && !loadMore) {
                final m = n.metrics;
                if (m.pixels >= m.maxScrollExtent - 200) {
                  c.loadMoreSavedContent(tabIndex);
                }
              }
              return false;
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.h),
              child: GridView.builder(
                padding: EdgeInsets.only(bottom: 80.h),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5.w,
                  mainAxisSpacing: 5.w,
                  childAspectRatio:  0.7,
                ),
                itemCount: list.length + (loadMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= list.length) {
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
                  return _ZealThumbnail(
                    post: list[index],
                    onTap: () {
                      Get.to(() => ZealDetailScreen(savePage: true, indexOnSave: index), arguments: list[index],);

                    },
                  );
                },
              ),
            ),
          ),
        );

      }

      if (tabIndex == 2) {
        return RefreshIndicator(
          onRefresh: () => c.loadSavedContent(tabIndex, refresh: true),
          color: AppColors.primaryColor,
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 80.h),
            itemCount: list.length + (loadMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= list.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Center(
                    child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              }
              final post = list[index];
              return CommonWritePostItem(
                key: ValueKey('saved_write_${post.id}_$index'),
                isLiked: post.isLiked ?? false,
                isBookmarked: true,
                userId: post.userId,
                onLike: (){
                  LikeHelper.toggleLike(
                    contentId: post.id ?? '',
                    contentType: post.contentType ?? 'Write Post',
                    isLiked: post.isLiked ?? false,
                    likeCount: post.likeCount ?? 0,
                    onLocalUpdate: (liked, count) {
                      post.isLiked = liked;
                      post.likeCount = count;
                    },
                  );
                },
                onComment: () {
                  CommentsBottomSheet.show(
                    postId: post.id ?? '',
                    commentsCount: post.commentCount ?? 0,
                    contentType: post.contentType ?? '',
                    onCommentAdded: (newCount) {
                      post.commentCount = newCount;
                      c.savedWrites.refresh();
                    },
                  );
                },
                onReport: () {
                  Get.find<ReportController>().reset();
                  Get.find<ReportController>().getReportsCategories(context);
                  ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Post');
                },

                onSave: () {
                  c.unsaveAndRemoveFromList(context, post.contentType ?? '', post.id ?? '', c.savedWrites, index);
                },
                onShare: () {
                  ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
                },

                onBookmark: () {
                  c.unsaveAndRemoveFromList(context, post.contentType ?? '', post.id ?? '', c.savedWrites, index);
                },
                onDelete: () => c.savedWrites.removeWhere((p) => p.id == post.id),
                postData: post,
              );
            },
          ),
        );
      }

      // tabIndex == 3: Polls
      return RefreshIndicator(
        onRefresh: () => c.loadSavedContent(tabIndex, refresh: true),
        color: AppColors.primaryColor,
        child: ListView.builder(
          padding: EdgeInsets.only(bottom: 80.h),
          itemCount: list.length + (loadMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= list.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Center(
                  child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            final post = list[index];
            return PollCard(
              key: ValueKey('saved_poll_${post.id}_$index'),
              isSaved: true,

              hasVoted: post.displayHasVoted,
              votedOptionId: post.displayVotedOptionId,
              isExpired: post.isPollExpired,
              onReport: () {
                Get.find<ReportController>().reset();
                Get.find<ReportController>().getReportsCategories(context);
                ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Poll');
              },
              onOptionTap: (optionId) => c.submitPollVote(post.id!, optionId),
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
              onBookmark: () {
                c.unsaveAndRemoveFromList(context, post.contentType ?? 'Poll', post.id ?? '', c.savedPolls, index);
              },
              onCopyLink: () {
                Clipboard.setData(ClipboardData(text: post.shareableLink ?? "demo"));
              },
              onSave: () {
                c.unsaveAndRemoveFromList(context, post.contentType ?? '', post.id ?? '', c.savedPolls, index);
              },
              onComment: () {
                CommentsBottomSheet.show(
                  postId: post.id ?? '',
                  commentsCount: post.commentCount ?? 0,
                  contentType: post.contentType ?? '',
                  onCommentAdded: (newCount) {
                    post.commentCount = newCount;
                    c.savedPolls.refresh();
                  },
                );
              },
              onShare: () {
                ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
              },
              onDelete: () => c.savedPolls.removeWhere((p) => p.id == post.id),
              postData: post,
            );
          },
        ),
      );
    });
  }

  static String _emptyMessageForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'No saved posts yet';
      case 1:
        return 'No saved zeals yet';
      case 2:
        return 'No saved writes yet';
      case 3:
        return 'No saved polls yet';
      default:
        return 'Nothing saved yet';
    }
  }

  static Widget _emptyIconForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return Assets.icons.icSavePost.svg();
      case 1:
        return Assets.icons.icSaveZeals.svg();
      case 2:
        return Assets.icons.icSaveWrite.svg();
      case 3:
        return Assets.icons.icSavePolls.svg();
      default:
        return Assets.icons.icSavePost.svg();
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final Widget icon;

  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
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
            style: TextStyles.semiBold(18.sp, fontColor: AppColors.black2F3039),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ZealThumbnail extends StatelessWidget {
  final PostData post;
  final VoidCallback? onTap;

  const _ZealThumbnail({required this.post, this.onTap});

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
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _thumbnailUrl != null
                ? CommonNetworkImage(
              imageUrl: _thumbnailUrl!,
              fit: BoxFit.cover,
              memCacheWidth: 250,
              memCacheHeight: 350,
            )
                : Container(
              color: AppColors.grayEDF1F4,
              child: Assets.icons.icImgPlaceholder.image(fit: BoxFit.cover),
            ),
            Positioned(top: 8.h, right: 8.w, child: Assets.icons.icZealsFill.svg()),
          ],
        ),
      ),
    );
  }
}

class _SavedThumbnail extends StatelessWidget {
  final PostData post;
  final int tabIndex;

  const _SavedThumbnail({required this.post, required this.tabIndex});

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
    final c = Get.find<SettingsController>();
    final list = tabIndex == 0 ? c.savedPosts : c.savedZeals;
    return GestureDetector(
      onTap: () {
        Get.to(
          () => Builder(
            builder: (modalContext) => Scaffold(
              backgroundColor: AppColors.whiteFFFFFF,
              appBar: AppBar(
                backgroundColor: AppColors.whiteFFFFFF,
                elevation: 0,
                leading: IconButton(
                  icon: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
                  onPressed: () => Get.back(),
                ),
              ),
              body: SingleChildScrollView(
                child: Obx(() {
                  final index = list.indexWhere((p) => p.id == post.id);

                  if (index == -1) {
                    return const SizedBox();
                  }

                  return CommonPostDetailWidget(
                    post: list[index],
                    onComment: () {
                      CommentsBottomSheet.show(
                        postId: post.id ?? '',
                        commentsCount: post.commentCount ?? 0,
                        contentType: post.contentType ?? '',
                        onCommentAdded: (newCount) {
                          post.commentCount = newCount;
                          list.refresh();
                        },
                      );
                    },
                    onBookmark: () {

                      final idx = list.indexWhere((p) => p.id == post.id);
                      if (idx >= 0) {
                        c.unsaveAndRemoveFromList(modalContext, post.contentType ?? '', post.id ?? '', list, idx);
                        Get.back();
                      }
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
                    onReport: () {
                      Get.find<ReportController>().reset();
                      Get.find<ReportController>().getReportsCategories(context);
                      ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Post');
                    },

                    onSave: () {
                      final idx = list.indexWhere((p) => p.id == post.id);
                      if (idx >= 0) {
                        c.unsaveAndRemoveFromList(modalContext, post.contentType ?? '', post.id ?? '', list, idx);
                        Get.back();
                      }
                    },
                    onShare: () {
                      ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
                    },

                    onDelete: () {
                      list.removeWhere((p) => p.id == post.id);
                      Get.back();
                    },
                  );
                }),
              ),
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _thumbnailUrl != null
              ?  CommonNetworkImage(imageUrl: _thumbnailUrl!, fit: BoxFit.cover, memCacheWidth: 250, memCacheHeight: null)
              : Container(
                  color: AppColors.grayEDF1F4,
                  child: Assets.icons.icImgPlaceholder.image(fit: BoxFit.cover),
                ),
          if (tabIndex == 1) Positioned(top: 8.h, right: 8.w, child: Assets.icons.icZealsFill.svg()),
          if (post.images != null && post.images!.length > 1)
            Positioned(
              top: 8.h,
              right: 8.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.black000000.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${post.images!.length}',
                  style: TextStyles.regular(10.sp, fontColor: AppColors.whiteFFFFFF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
