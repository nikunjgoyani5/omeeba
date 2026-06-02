import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/models/search_user_model.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/core/widgets/common_post_detail_widget.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/presentation/main/explore/controller/search_controller.dart'
    as search_ctrl;
import 'package:omeeba_new/presentation/main/explore/widgets/explore_grid_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/explore_list_shimmer.dart';

import '../../../../core/helper/like_helper.dart';
import '../../../../core/utils/exports.dart';
import '../../report/controller/report_controller.dart';
import '../../report/view/report_bottom_sheet.dart';
import '../../zeals/views/zeal_detail_screen.dart';
import '../controller/explore_controller.dart';

class SearchView extends StatefulWidget {
  /// When set, opens with this hashtag prefilled (with #) and loads results via explore/hashtag API.
  final String? initialHashtag;

  /// When set, a dedicated controller is looked up/deleted by this tag (used for hashtag navigation).
  final String? controllerTag;

  const SearchView({super.key, this.initialHashtag, this.controllerTag});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTabIndex = 0; // 0: Account, 1: Posts, 2: Zeals, 3: Tag
  /// true only after user submits (presses enter) — shows tab bar and results
  bool _hasSubmitted = false;
  bool _hasText = false;
  late search_ctrl.ExploreSearchController _searchCtrl;

  @override
  void initState() {
    super.initState();
    // If a dedicated tag was provided (hashtag navigation), use that controller instance.
    _searchCtrl = widget.controllerTag != null
        ? Get.find<search_ctrl.ExploreSearchController>(
            tag: widget.controllerTag,
          )
        : Get.find<search_ctrl.ExploreSearchController>();
    final tag = widget.initialHashtag?.trim();
    if (tag != null && tag.isNotEmpty) {
      final displayTag = tag.startsWith('#') ? tag : '#$tag';
      _searchController.text = displayTag;
      _hasText = true;
      _hasSubmitted = true;
      _selectedTabIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchCtrl.setInitialHashtag(tag);
        _searchCtrl.searchHashtagByType(
          search_ctrl.ExploreSearchController.contentTypeWrite,
        );
      });
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    // Clean up the dedicated controller created for hashtag navigation.
    if (widget.controllerTag != null) {
      Get.delete<search_ctrl.ExploreSearchController>(
        tag: widget.controllerTag,
      );
    }
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    final hasText = _searchController.text.isNotEmpty;
    if (query.isEmpty) {
      setState(() {
        _hasText = false;
        if (_hasSubmitted) {
          _hasSubmitted = false;
          _selectedTabIndex = 0;
          _searchCtrl.searchByType(
            search_ctrl.ExploreSearchController.typeUsers,
          );
        }
      });
      _searchCtrl.users.clear();
      _searchCtrl.lastSearchQuery.value = '';
      return;
    }
    setState(() => _hasText = hasText);
    // While typing (before submit): debounce and fetch users — no tab bar
    _searchCtrl.onQueryChanged(_searchController.text, submit: false);
  }

  void _onSubmitted(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _hasSubmitted = true;
      _selectedTabIndex = 0;
      _searchCtrl.searchByType(search_ctrl.ExploreSearchController.typeUsers);
    });
    _searchCtrl.onQueryChanged(value, submit: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _hasSubmitted = false;
      _selectedTabIndex = 0;
      _searchCtrl.searchByType(search_ctrl.ExploreSearchController.typeUsers);
    });
    _searchCtrl.clearSearch();
  }

  void _onTabSelected(int index) {
    setState(() => _selectedTabIndex = index);
    if (index == 0) {
      _searchCtrl.searchByType(search_ctrl.ExploreSearchController.typeUsers);
    } else if (index == 1) {
      _searchCtrl.searchByType(search_ctrl.ExploreSearchController.typePosts);
    } else if (index == 2) {
      _searchCtrl.searchByType(search_ctrl.ExploreSearchController.typeZeals);
    } else if (index == 3) {
      _searchCtrl.searchByType(search_ctrl.ExploreSearchController.typeHashtag);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                top: statusBarHeight + 16.h,
                right: 16.w,
                bottom: 16.h,
              ),
              color: AppColors.whiteFFFFFF,
              child: _buildSearchBar(),
            ),
            if (_hasSubmitted) _buildTabBar(),
            Expanded(
              child: _hasSubmitted
                  ? _buildSearchResults()
                  : _buildTypingResults(),
            ),
          ],
        ),
      ),
    );
  }

  /// Before submit: show results as user types (debounce) or empty state.
  Widget _buildTypingResults() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    if (!hasQuery) return _buildEmptyState();
    return _buildAccountResults();
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.all(8.w),
          constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
          splashColor: AppColors.grayEDF1F4,
          highlightColor: AppColors.grayEDF1F4.withValues(alpha: 0.45),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          icon: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
          onPressed: () => Get.back(),
        ),
        Expanded(
          child: Container(
            height: 52.h,
            decoration: BoxDecoration(
              color: AppColors.grayEDF1F4,
              borderRadius: BorderRadius.circular(500.r),
            ),
            child: Row(
              children: [
                SizedBox(width: 12.w),
                Assets.icons.icSearch.svg(),
                SizedBox(width: 8.w),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyles.medium(
                      16.sp,
                      fontColor: AppColors.black000000,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyles.medium(
                        16.sp,
                        fontColor: AppColors.gray707070,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    autofocus: true,
                    onSubmitted: _onSubmitted,
                  ),
                ),
                if (_hasText)
                  GestureDetector(
                    onTap: _clearSearch,
                    child: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Icon(
                        Icons.close,
                        size: 20.sp,
                        color: AppColors.gray707070,
                      ),
                    ),
                  )
                else
                  SizedBox(width: 16.w),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48.h,
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        border: Border(
          bottom: BorderSide(color: AppColors.grayEDF1F4, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildTabItem(
              index: 0,
              icon: Assets.icons.icAccount,
              name: 'Account',
            ),
          ),
          Expanded(
            child: _buildTabItem(
              index: 1,
              icon: Assets.icons.icSavePost,
              name: 'Posts',
              isMaterialIcon: false,
            ),
          ),
          Expanded(
            child: _buildTabItem(
              index: 2,
              icon: Assets.icons.icZealsFill,
              name: 'Zeals',
            ),
          ),
          Expanded(
            child: _buildTabItem(
              index: 3,
              icon: Assets.icons.icHas,
              name: 'Tag',
              isMaterialIcon: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    dynamic icon,
    required String name,
    bool isMaterialIcon = false,
    IconData? materialIcon,
  }) {
    final isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () => _onTabSelected(index),
      child: Container(
        height: 48.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.black000000 : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isMaterialIcon && materialIcon != null)
              Icon(
                materialIcon,
                size: 20.sp,
                color: isSelected
                    ? AppColors.black000000
                    : AppColors.gray8C9499,
              )
            else if (icon != null)
              icon.svg(
                height: 20.h,
                width: 20.w,
                colorFilter: ColorFilter.mode(
                  isSelected ? AppColors.black000000 : AppColors.gray8C9499,
                  BlendMode.srcIn,
                ),
              ),
            SizedBox(height: 4.h),
            Text(
              name,
              style: TextStyles.medium(
                12,
                fontColor: isSelected
                    ? AppColors.black000000
                    : AppColors.gray8C9499,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          'Search for accounts, posts, zeals, or tags',
          style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildAccountResults();
      case 1:
        return _buildPostsResults();
      case 2:
        return _buildZealsResults();
      case 3:
        return _buildTagResults();
      default:
        return _buildAccountResults();
    }
  }

  Widget _buildAccountResults() {
    return Obx(() {
      if (_searchCtrl.isLoading.value) {
        return const ExploreListShimmer();
      }
      final users = _searchCtrl.users;
      if (users.isEmpty) {
        return Center(
          child: Text(
            'No users found',
            style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
          ),
        );
      }
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return _buildUserAccountItem(user: user);
        },
      );
    });
  }

  Widget _buildUserAccountItem({required SearchUserData user}) {
    final profileImageUrl = user.profileImageUrl;

    return InkWell(
      onTap: () {
        final userId = user.id;
        if (userId != null && userId.isNotEmpty) {
          Get.toNamed(AppRoutes.otherUserProfile, arguments: userId);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            CommonProfileImage(
              imageUrl: profileImageUrl,
              width: 48.w,
              height: 48.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name ?? user.username ?? 'User',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyles.medium(
                            18.sp,
                            fontColor: AppColors.black2F3039,
                          ),
                        ),
                      ),
                      SizedBox(width: 5.w),
                      if (user.isVerifiedBadge == true) ...[
                        Assets.icons.icVerifyBadgeSmallSize.svg(
                          width: 16.w,
                          height: 16.h,
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: 2.h),
                  Text(
                    '@${user.username ?? ''}',
                    style: TextStyles.medium(
                      14.sp,
                      fontColor: AppColors.gray707070,
                    ),
                  ),
                  // if (user.bio != null && user.bio!.isNotEmpty) ...[
                  //   SizedBox(height: 4.h),
                  //   Text(
                  //     user.bio!,
                  //     style: TextStyles.regular(
                  //       12.sp,
                  //       fontColor: AppColors.gray8C9499,
                  //     ),
                  //     maxLines: 2,
                  //     overflow: TextOverflow.ellipsis,
                  //   ),
                  // ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsResults() {
    return Obx(() {
      if (_searchCtrl.isLoading.value && _selectedTabIndex == 1) {
        return const ExploreGridShimmer();
      }
      final posts = _searchCtrl.posts;
      if (posts.isEmpty) {
        return Center(
          child: Text(
            'No posts found',
            style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
          ),
        );
      }
      final itemWidth = (MediaQuery.of(context).size.width - 32.w - 8.w) / 3;
      return Padding(
        padding: EdgeInsets.all(4.w),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4.w,
            mainAxisSpacing: 4.w,
            childAspectRatio: 0.95,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final thumbnailUrl = _postThumbnailUrl(post);
            final isMultiImage = (post.images?.length ?? 0) > 1;
            return GestureDetector(
              onTap: () => _openPostDetail(post),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnailUrl != null && thumbnailUrl.isNotEmpty
                      ? CommonNetworkImage(
                          imageUrl: thumbnailUrl,
                          width: itemWidth,
                          height: itemWidth * 0.95,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          memCacheHeight: null,
                        )
                      : Container(
                          color: AppColors.grayEDF1F4,
                          child: Assets.icons.icImgPlaceholder.image(
                            fit: BoxFit.cover,
                          ),
                        ),
                  if (isMultiImage)
                    Positioned(
                      top: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.black000000.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '1/${post.images!.length}+',
                          style: TextStyles.regular(
                            10.sp,
                            fontColor: AppColors.whiteFFFFFF,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  String? _postThumbnailUrl(PostData post) {
    final images = post.images;
    if (images != null && images.isNotEmpty) return images.first;
    if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty) {
      return post.thumbnailUrl;
    }
    if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) {
      return post.mediaUrl;
    }
    final videos = post.videos;
    if (videos != null && videos.isNotEmpty) return videos.first;
    return null;
  }

  void _openPostDetail(PostData post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.whiteFFFFFF,
          appBar: AppBar(
            backgroundColor: AppColors.whiteFFFFFF,
            elevation: 0,
            leading: IconButton(
              icon: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            child: CommonPostDetailWidget(
              post: post,
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
              onComment: () {},
              onShare: () {},
              onBookmark: () {},
              onSave: () {},
              onReport: () {
                Get.find<ReportController>().reset();
                Get.find<ReportController>().getReportsCategories(context);
                ReportBottomSheet.show(
                  postId: post.id ?? '',
                  postType: post.contentType ?? 'Post',
                );
              },
              onDelete: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToZealDetailScreen(PostData post) {
    Get.to(() => ZealDetailScreen(), arguments: post)?.then((result) {
      if (result is String) {
        Get.find<ExploreController>().removePostById(result);
      }
    });
  }

  Widget _buildZealsResults() {
    return Obx(() {
      if (_searchCtrl.isLoading.value && _selectedTabIndex == 2) {
        return const ExploreGridShimmer();
      }
      final zealsList = _searchCtrl.zeals;
      if (zealsList.isEmpty) {
        return Center(
          child: Text(
            'No zeals found',
            style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
          ),
        );
      }
      final itemWidth = (MediaQuery.of(context).size.width - 32.w - 8.w) / 3;
      return Padding(
        padding: EdgeInsets.all(4.w),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4.w,
            mainAxisSpacing: 4.w,
            childAspectRatio: 0.7,
          ),
          itemCount: zealsList.length,
          itemBuilder: (context, index) {
            final post = zealsList[index];
            final thumbnailUrl = _postThumbnailUrl(post);
            return GestureDetector(
              onTap: () => _navigateToZealDetailScreen(post),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnailUrl != null && thumbnailUrl.isNotEmpty
                      ? CommonNetworkImage(
                          imageUrl: thumbnailUrl,
                          width: itemWidth,
                          height: itemWidth / 0.7,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          memCacheHeight: null,
                        )
                      : Container(
                          color: AppColors.grayEDF1F4,
                          child: Assets.icons.icImgPlaceholder.image(
                            fit: BoxFit.cover,
                          ),
                        ),
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Assets.icons.icZealsFill.svg(),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildTagResults() {
    return Obx(() {
      if (_searchCtrl.isLoading.value && _selectedTabIndex == 3) {
        return const ExploreListShimmer();
      }
      final hashtagsList = _searchCtrl.hashtags;
      if (hashtagsList.isEmpty) {
        return Center(
          child: Text(
            'No tags found',
            style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
          ),
        );
      }
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: hashtagsList.length,
        itemBuilder: (context, index) {
          final item = hashtagsList[index];
          return _buildTagItem(
            tag: item.tag ?? '',
            contentCount: item.contentCount ?? 0,
          );
        },
      );
    });
  }

  Widget _buildTagItem({required String tag, required int contentCount}) {
    final displayTag = tag.startsWith('#') ? tag : '#$tag';
    return InkWell(
      onTap: () {
        final rawTag = tag.startsWith('#') ? tag.substring(1) : tag;
        if (rawTag.isEmpty) return;
        final ctrlTag = rawTag;
        // Register a fresh controller so it doesn't collide with the parent SearchView's singleton.
        Get.put(search_ctrl.ExploreSearchController(), tag: ctrlTag);
        Get.to(
          () => SearchView(initialHashtag: rawTag, controllerTag: ctrlTag),
          preventDuplicates: false,
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: AppColors.grayEDF1F4,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Assets.icons.icHas.svg(
                  colorFilter: ColorFilter.mode(
                    AppColors.primaryDark,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTag,
                    style: TextStyles.medium(
                      18.sp,
                      fontColor: AppColors.black2F3039,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '$contentCount post${contentCount != 1 ? 's' : ''}',
                    style: TextStyles.medium(
                      14.sp,
                      fontColor: AppColors.gray707070,
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
}
