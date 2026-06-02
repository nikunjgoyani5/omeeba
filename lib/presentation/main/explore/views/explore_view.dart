import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/core/widgets/common_write_post_item.dart';
import 'package:omeeba_new/core/widgets/press_scale_button.dart';
import 'package:omeeba_new/core/widgets/poll_card.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import 'package:omeeba_new/presentation/main/explore/controller/explore_controller.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/explore_grid_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/explore_list_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/poll_list_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/search_view.dart';
import 'package:omeeba_new/presentation/main/zeals/views/zeal_detail_screen.dart';
import '../../../../core/helper/like_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../home/widgets/share_bottom_sheet.dart';
import '../../report/controller/report_controller.dart';
import '../../report/view/report_bottom_sheet.dart';
import '../../zeals/widget/comments_bottom_sheet.dart';

class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  int _selectedTabIndex = 0; // 0: Explore, 1: Trending, 2: Polls
  late PageController _pageController;
  late ExploreController _controller;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTabIndex);
    _controller = Get.find<ExploreController>();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            Hero(
              tag: 'search_field',
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding: EdgeInsets.only(
                    top: statusBarHeight + 16.h,
                    right: 16.w,
                    bottom: 16.h,
                  ),
                  color: AppColors.whiteFFFFFF,
                  child: _buildSearchBar(),
                ),
              ),
            ),
            _buildTabBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  if (_selectedTabIndex != index) {
                    setState(() => _selectedTabIndex = index);
                    _controller.onTabSelected(index);
                  }
                },
                children: const [
                  _ExploreTabView(),
                  _TrendingTabView(),
                  _PollsTabView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        PressScaleButton(
          onTap: () {
            FocusScope.of(context).unfocus();
            Get.back();
          },
          child: Padding(
            padding: EdgeInsets.all(8.w),
            child: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
          ),
        ),
        Expanded(
          child: PressScaleButton(
            onTap: () => Get.to(() => SearchView()),
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
                  Text(
                    'Search ',
                    style: TextStyles.medium(
                      16.sp,
                      fontColor: AppColors.gray707070,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaryColor,
                          AppColors.primaryDark,
                          AppColors.primaryColor,
                        ],
                      ).createShader(bounds);
                    },
                    child: Text(
                      _selectedTabIndex == 0
                          ? 'Explore'
                          : _selectedTabIndex == 1
                          ? 'Trending'
                          : 'Polls',
                      style: TextStyles.medium(
                        17.sp,
                      ).copyWith(color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.close, size: 20.sp, color: AppColors.gray707070),
                  SizedBox(width: 16.w),
                ],
              ),
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
              icon: Assets.icons.icExplore,
              name: 'Explore',
            ),
          ),
          Expanded(
            child: _buildTabItem(
              index: 1,
              icon: Assets.icons.icTrending,
              name: 'Trending',
            ),
          ),
          Expanded(
            child: _buildTabItem(
              index: 2,
              icon: Assets.icons.icSavePolls,
              name: 'Polls',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required dynamic icon,
    required String name,
  }) {
    final isSelected = _selectedTabIndex == index;

    return PressScaleButton(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _controller.onTabSelected(index);
      },
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
            icon.svg(
              height: name == 'Trending' ? 12.0 : 20.h,
              width: name == 'Trending' ? 12.0 : 20.w,
              colorFilter: ColorFilter.mode(
                isSelected ? AppColors.black000000 : AppColors.gray8C9499,
                BlendMode.srcIn,
              ),
            ),
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
}

class _ExploreTabView extends StatefulWidget {
  const _ExploreTabView();

  @override
  State<_ExploreTabView> createState() => _ExploreTabViewState();
}

class _ExploreTabViewState extends State<_ExploreTabView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;
  bool likeInProgress = false;

  OverlayEntry? _postPreviewEntry;
  AnimationController? _postPreviewController;
  bool _suppressGridTap = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _removePostPreview(immediate: true);
    _postPreviewController?.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo';
    final years = (diff.inDays / 365).floor();
    return '${years}y';
  }

  void _releaseTapSuppressionSoon() {
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _suppressGridTap = false;
    });
  }

  void _removePostPreview({bool immediate = false}) {
    final entry = _postPreviewEntry;
    if (entry == null) return;

    if (immediate) {
      _postPreviewController?.stop();
      entry.remove();
      _postPreviewEntry = null;
      _releaseTapSuppressionSoon();
      return;
    }

    final controller = _postPreviewController;
    if (controller == null) {
      entry.remove();
      _postPreviewEntry = null;
      _releaseTapSuppressionSoon();
      return;
    }

    controller.reverse().whenComplete(() {
      if (_postPreviewEntry == entry) {
        entry.remove();
        _postPreviewEntry = null;
        _releaseTapSuppressionSoon();
      }
    });
  }

  String? _getPostPreviewUrl(PostData post) {
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

  void _showPostPreviewFromKey(GlobalKey key, PostData post) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox) return;
    final fromOffset = renderObject.localToGlobal(Offset.zero);
    final fromRect = fromOffset & renderObject.size;

    final mediaUrl = _getPostPreviewUrl(post);
    if (mediaUrl == null || mediaUrl.isEmpty) return;

    final authorName = post.userId?.name ?? post.userId?.username ?? 'User';
    final profileImageUrl = post.userId?.profileImage is String
        ? post.userId!.profileImage as String?
        : null;
    final timeAgo = _timeAgo(post.createdAt);
    final mediaAspectRatio =
        (post.imageAspectRatio != null && post.imageAspectRatio! > 0)
        ? post.imageAspectRatio!
        : 1.0;

    _removePostPreview(immediate: true);

    _postPreviewController?.dispose();
    _postPreviewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 120),
    );

    HapticFeedback.lightImpact();

    final entry = OverlayEntry(
      builder: (context) {
        return _ExplorePostLongPressPreviewOverlay(
          controller: _postPreviewController!,
          fromRect: fromRect,
          imageUrl: mediaUrl,
          authorName: authorName,
          timeAgo: timeAgo,
          profileImageUrl: profileImageUrl,
          mediaAspectRatio: mediaAspectRatio,
          onDismiss: () => _removePostPreview(),
        );
      },
    );
    _postPreviewEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
    _postPreviewController!.forward();
  }

  void _onScroll() {
    final c = Get.find<ExploreController>();
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) c.loadMoreExplore();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = Get.find<ExploreController>();

    return Obx(() {
      final isLoading = controller.exploreLoading.value;
      final posts = controller.exploreData.value?.posts ?? [];
      final showShimmer = isLoading && posts.isEmpty;
      final isRefreshing = isLoading && posts.isNotEmpty;

      if (showShimmer) {
        return const ExploreGridShimmer();
      }

      return WillPopScope(
        onWillPop: () async {
          if (_postPreviewEntry != null) {
            _removePostPreview();
            return false;
          }
          return true;
        },
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: controller.refreshExplore,
              color: AppColors.primaryColor,
              child: MasonryGridView.count(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                padding: EdgeInsets.all(4.w),
                crossAxisCount: 3,
                mainAxisSpacing: 4.w,
                crossAxisSpacing: 4.w,
                itemCount:
                    posts.length +
                    (controller.exploreLoadMoreLoading.value ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= posts.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Center(
                        child: SizedBox(
                          width: 24.w,
                          height: 24.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  }
                  final post = posts[index];
                  final pattern = [
                    1.2,
                    1.0,
                    1.3,
                    1.1,
                    1.4,
                    1.0,
                    1.2,
                    1.3,
                    1.1,
                    1.2,
                    1.0,
                    1.3,
                  ];
                  final patternValue = pattern[index % pattern.length];
                  final baseHeight = MediaQuery.of(context).size.width / 3;
                  final height = baseHeight * patternValue;
                  final isZealPost = (post.contentType ?? '')
                      .toLowerCase()
                      .contains('zeal');
                  final isPostType =
                      post.contentType == null || post.contentType == 'Post';
                  final isSquareCell = patternValue == 1.0;
                  final tileKey = GlobalKey();

                  return RepaintBoundary(
                    key: ValueKey('explore_${post.id}_$index'),
                    child: _ExploreMediaGridItem(
                      key: tileKey,
                      post: post,
                      height: height,
                      isSquareCell: isSquareCell,
                      showFlameIcon: isZealPost,
                      heroTagPrefix: isPostType ? 'explore_post_$index' : null,
                      onTap: () {
                        if (_suppressGridTap || _postPreviewEntry != null) {
                          return;
                        }
                        _navigateToPostDetail(post, index);
                      },
                      onLongPress: () {
                        _suppressGridTap = true;
                        _showPostPreviewFromKey(tileKey, post);
                      },
                    ),
                  );
                },
              ),
            ),
            if (isRefreshing)
              Positioned.fill(
                child: Container(
                  color: AppColors.whiteFFFFFF,
                  child: const ExploreGridShimmer(),
                ),
              ),
          ],
        ),
      );
    });
  }

  bool _isZealWithVideo(PostData post) {
    if ((post.contentType ?? '').toLowerCase().contains('zeal') &&
        post.mediaUrl != null &&
        post.mediaUrl!.toString().trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  void _navigateToPostDetail(PostData post, [int? index]) {
    if (_isZealWithVideo(post)) {
      Get.to(() => ZealDetailScreen(), arguments: post)?.then((result) {
        if (result is String) {
          Get.find<ExploreController>().removePostById(result);
        }
      });
      return;
    }
    final isPostType = post.contentType == null || post.contentType == 'Post';
    Get.toNamed(
      AppRoutes.postContentDetail,
      arguments: {
        'post': post,
        if (isPostType && index != null) 'heroTagPrefix': 'explore_post_$index',
      },
    );
  }
}

class _ExploreMediaGridItem extends StatelessWidget {
  final PostData post;
  final double? height;

  /// Use [BoxFit.cover] for all grid shapes to avoid stretched media.
  final bool isSquareCell;
  final bool showFlameIcon;
  final String? heroTagPrefix;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ExploreMediaGridItem({
    super.key,
    required this.post,
    this.height,
    this.isSquareCell = false,
    this.showFlameIcon = false,
    this.heroTagPrefix,
    required this.onTap,
    this.onLongPress,
  });

  String? get _thumbnailUrl {
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

  @override
  Widget build(BuildContext context) {
    final itemWidth = (MediaQuery.of(context).size.width - 32.w - 8.w) / 3;
    final itemHeight = height ?? itemWidth;
    final imageTag = heroTagPrefix != null ? '${heroTagPrefix!}_image_0' : null;

    final imageFit = BoxFit.cover;
    Widget imageWidget = _thumbnailUrl != null
        ? ClipRect(
            child: CommonNetworkImage(
              imageUrl: _thumbnailUrl!,
              fit: imageFit,
              // Keep only width hint; forcing both width+height to a square can distort source ratio.
              memCacheWidth: 400,
            ),
          )
        : Container(
            color: AppColors.grayEDF1F4,
            child: Assets.icons.icImgPlaceholder.image(fit: BoxFit.cover),
          );

    if (imageTag != null) {
      imageWidget = Hero(tag: imageTag, child: imageWidget);
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: itemWidth,
        height: itemHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: imageWidget),
            if (showFlameIcon)
              Positioned(
                top: 8.h,
                right: 8.w,
                child: Assets.icons.icZealsFill.svg(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExplorePostLongPressPreviewOverlay extends StatefulWidget {
  const _ExplorePostLongPressPreviewOverlay({
    required this.controller,
    required this.fromRect,
    required this.imageUrl,
    required this.authorName,
    required this.timeAgo,
    this.profileImageUrl,
    required this.mediaAspectRatio,
    required this.onDismiss,
  });

  final AnimationController controller;
  final Rect fromRect;
  final String imageUrl;
  final String authorName;
  final String timeAgo;
  final String? profileImageUrl;
  final double mediaAspectRatio; // width / height
  final VoidCallback onDismiss;

  @override
  State<_ExplorePostLongPressPreviewOverlay> createState() =>
      _ExplorePostLongPressPreviewOverlayState();
}

class _ExplorePostLongPressPreviewOverlayState
    extends State<_ExplorePostLongPressPreviewOverlay> {
  Offset _dragOffset = Offset.zero;

  Rect _targetRect(Size screen, EdgeInsets padding) {
    final maxW = screen.width - 24.w;
    final maxH = screen.height - padding.top - padding.bottom - 90.h;

    final headerH = 56.h;
    final ar = widget.mediaAspectRatio <= 0 ? 1.0 : widget.mediaAspectRatio;

    double cardW = maxW;
    double mediaH = cardW / ar;
    double cardH = headerH + mediaH;

    if (cardH > maxH) {
      final scale = maxH / cardH;
      cardW *= scale;
      mediaH = cardW / ar;
      cardH = headerH + mediaH;
    }

    final left = (screen.width - cardW) / 2;
    final top =
        padding.top +
        (screen.height - padding.top - padding.bottom - cardH) / 2;
    return Rect.fromLTWH(left, top, cardW, cardH);
  }

  double _dragProgress() {
    final d = _dragOffset.distance;
    return (d / 140.0).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rectTween = RectTween(
      begin: widget.fromRect,
      end: _targetRect(screen, padding),
    );
    final ease = CurvedAnimation(
      parent: widget.controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: ease,
        builder: (context, _) {
          final t = ease.value;
          final rect = rectTween.lerp(t)!;
          final dragT = _dragProgress();
          final blurSigma = lerpDouble(0, 14, t)! * (1 - dragT);
          final dimOpacity =
              lerpDouble(0.0, isDark ? 0.55 : 0.35, t)! * (1 - dragT);
          final scale = lerpDouble(0.96, 1.0, t)! * (1 - (dragT * 0.06));

          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                onPanUpdate: (d) {
                  setState(() => _dragOffset += d.delta);
                },
                onPanEnd: (_) {
                  if (_dragOffset.distance > 90) {
                    widget.onDismiss();
                  } else {
                    setState(() => _dragOffset = Offset.zero);
                  }
                },
                onPanCancel: () {
                  setState(() => _dragOffset = Offset.zero);
                },
                child: Stack(
                  children: [
                    if (blurSigma > 0)
                      BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    Container(
                      color: Colors.black.withValues(alpha: dimOpacity),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: rect.left + _dragOffset.dx,
                top: rect.top + _dragOffset.dy,
                width: rect.width,
                height: rect.height,
                child: Transform.scale(
                  scale: scale,
                  child: RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.55 : 0.25,
                            ),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: ColoredBox(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 56.h,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                  ),
                                  child: Row(
                                    children: [
                                      CommonProfileImage(
                                        imageUrl: widget.profileImageUrl,
                                        width: 32.w,
                                        height: 32.w,
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.authorName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyles.semiBold(
                                                14.sp,
                                                fontColor:
                                                    AppColors.black2F3039,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              widget.timeAgo,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyles.regular(
                                                12.sp,
                                                fontColor: AppColors.gray707070,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return CommonNetworkImage(
                                      imageUrl: widget.imageUrl,
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 1400,
                                      memCacheHeight: 1400,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrendingTabView extends StatefulWidget {
  const _TrendingTabView();

  @override
  State<_TrendingTabView> createState() => _TrendingTabViewState();
}

class _TrendingTabViewState extends State<_TrendingTabView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final c = Get.find<ExploreController>();
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      c.loadMoreTrending();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = Get.find<ExploreController>();

    return Obx(() {
      final isLoading = controller.trendingLoading.value;
      final posts = controller.trendingData.value?.posts ?? [];
      final showShimmer = isLoading && posts.isEmpty;
      final isRefreshing = isLoading && posts.isNotEmpty;

      if (showShimmer) {
        return const ExploreListShimmer();
      }

      return RefreshIndicator(
        onRefresh: controller.refreshTrending,
        color: AppColors.primaryColor,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          padding: EdgeInsets.zero,
          itemCount:
              posts.length +
              (isRefreshing ? 1 : 0) +
              (controller.trendingLoadMoreLoading.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (isRefreshing && index == 0) {
              return const ExploreListShimmer();
            }
            final topOffset = isRefreshing ? 1 : 0;
            final adjustedIndex = index - topOffset;
            if (adjustedIndex >= posts.length) {
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
            final post = posts[adjustedIndex];

            return CommonWritePostItem(
              postData: post,
              onReport: () {
                Get.find<ReportController>().reset();
                Get.find<ReportController>().getReportsCategories(context);
                ReportBottomSheet.show(
                  postId: post.id ?? '',
                  postType: post.contentType ?? 'Post',
                );
              },

              onSave: () {
                controller.saveUnSavePost(
                  context,
                  post.contentType ?? '',
                  post.id ?? "",
                  adjustedIndex,
                  false,
                );
              },
              onBookmark: () {
                controller.saveUnSavePost(
                  context,
                  post.contentType ?? '',
                  post.id ?? "",
                  adjustedIndex,
                  false,
                );
              },
              onComment: () {
                CommentsBottomSheet.show(
                  postId: post.id ?? '',
                  commentsCount: post.commentCount ?? 0,
                  contentType: post.contentType ?? '',
                  onCommentAdded: (newCount) {
                    post.commentCount = newCount;
                    controller.refreshTrendingData();
                  },
                );
              },
              onShare: () {
                ShareBottomSheet.show(
                  postId: post.id,
                  postType: post.contentType,
                  shareUrl: post.shareableLink,
                );
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
              onDelete: () => controller.removePostById(post.id ?? ''),
            );
          },
        ),
      );
    });
  }
}

class _PollsTabView extends StatefulWidget {
  const _PollsTabView();

  @override
  State<_PollsTabView> createState() => _PollsTabViewState();
}

class _PollsTabViewState extends State<_PollsTabView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final c = Get.find<ExploreController>();
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      c.loadMorePolls();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = Get.find<ExploreController>();

    return Obx(() {
      final isLoading = controller.pollLoading.value;
      final posts = controller.pollData.value?.posts ?? [];
      final showShimmer = isLoading && posts.isEmpty;
      final isRefreshing = isLoading && posts.isNotEmpty;

      if (showShimmer) {
        return const PollListShimmer();
      }

      return RefreshIndicator(
        onRefresh: controller.refreshPolls,
        color: AppColors.primaryColor,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          padding: EdgeInsets.zero,
          itemCount:
              posts.length +
              (isRefreshing ? 1 : 0) +
              (controller.pollLoadMoreLoading.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (isRefreshing && index == 0) {
              return const PollListShimmer();
            }
            final topOffset = isRefreshing ? 1 : 0;
            final adjustedIndex = index - topOffset;
            if (adjustedIndex >= posts.length) {
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
            final post = posts[adjustedIndex];
            return StreamBuilder<PostDataResponse?>(
              stream: controller.pollData.stream,
              builder: (context, asyncSnapshot) {
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
                  onCopyLink: () {
                    Clipboard.setData(
                      ClipboardData(text: post.shareableLink ?? "demo"),
                    );
                  },
                  onSave: () {
                    controller.saveUnSavePost(
                      context,
                      post.contentType ?? 'Poll',
                      post.id ?? "",
                      adjustedIndex,
                      true,
                    );
                  },
                  onBookmark: () {
                    controller.saveUnSavePost(
                      context,
                      post.contentType ?? 'Poll',
                      post.id ?? "",
                      adjustedIndex,
                      true,
                    );
                  },
                  onComment: () {
                    CommentsBottomSheet.show(
                      postId: post.id ?? '',
                      commentsCount: post.commentCount ?? 0,
                      contentType: post.contentType ?? 'Poll',
                      onCommentAdded: (newCount) {
                        post.commentCount = newCount;
                        controller.refreshPollData();
                      },
                    );
                  },
                  onShare: () {
                    ShareBottomSheet.show(
                      postId: post.id,
                      postType: post.contentType,
                      shareUrl: post.shareableLink,
                    );
                  },
                  onDelete: () => controller.removePostById(post.id ?? ''),
                  hasVoted: post.displayHasVoted,
                  votedOptionId: post.displayVotedOptionId,
                  isExpired: post.isPollExpired,
                  onReport: () {
                    Get.find<ReportController>().reset();
                    Get.find<ReportController>().getReportsCategories(context);
                    ReportBottomSheet.show(
                      postId: post.id ?? '',
                      postType: post.contentType ?? 'Poll',
                    );
                  },
                  onOptionTap: (optionId) =>
                      controller.submitPollVote(post.id!, optionId),
                );
              },
            );
          },
        ),
      );
    });
  }
}
