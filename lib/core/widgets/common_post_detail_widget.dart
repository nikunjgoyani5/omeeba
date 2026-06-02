import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/core/widgets/delete_confirmation_dialog.dart';
import 'package:omeeba_new/core/widgets/liked_by_bottom_sheet.dart';
import 'package:omeeba_new/core/widgets/press_scale_button.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import 'package:omeeba_new/presentation/main/home/controller/home_controller.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

/// Cache of resolved aspect ratios by post id when not provided by API.
final Map<String, double> _postAspectRatioCache = {};

class CommonPostDetailWidget extends StatefulWidget {
  /// Full post object for rendering (single source of truth).
  final PostData post;
  final bool isBookmarked;
  final bool isNavigation;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;
  final VoidCallback? onSave;
  final VoidCallback? onReport;
  final VoidCallback? onCopyLink;
  final VoidCallback? onDelete;
  final String? heroTagPrefix;

  const CommonPostDetailWidget({
    super.key,
    required this.post,
    this.isBookmarked = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onBookmark,
    this.onSave,
    this.onReport,
    this.onCopyLink,
    this.onDelete,
    this.heroTagPrefix,
    this.isNavigation = true,
  });

  @override
  State<CommonPostDetailWidget> createState() => _CommonPostDetailWidgetState();
}

class _CommonPostDetailWidgetState extends State<CommonPostDetailWidget> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  final GlobalKey _moreOptionsKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  NavigatorState? _menuNavigator;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Like animation (Instagram-style: quick pop-in, slight bounce, fade out)
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;
  late Animation<double> _likeOpacityAnimation;
  final ValueNotifier<bool> _showHeartNotifier = ValueNotifier<bool>(false);
  bool _isLiked = false;

  // Pinch-to-zoom overlay (Instagram-style: detach, full-screen zoom, dark barrier, smooth return)
  static const double _minZoomScale = 1.0;
  static const double _maxZoomScale = 4.0;
  final GlobalKey _zoomImageKey = GlobalKey();
  OverlayEntry? _zoomOverlayEntry;
  final ValueNotifier<double> _zoomScaleNotifier = ValueNotifier<double>(1.0);
  Rect? _zoomStartRect;
  double _zoomScaleAtReturnStart = 1.0;
  late AnimationController _zoomReturnController;
  late Animation<double> _zoomReturnAnimation;

  // Unique hero tag for this post
  late String _heroTag;

  String get _displayUserName {
    final p = widget.post;
    return p.userId?.name ?? p.userId?.username ?? 'User';
  }

  String get _displayTimeAgo {
    final p = widget.post;
    if (p.createdAt == null) return '';
    final d = DateTime.now().difference(p.createdAt!);
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }

  String get _displayCaption {
    final p = widget.post;
    final text = (p.caption?.isNotEmpty == true)
        ? p.caption!
        : (p.content?.isNotEmpty == true)
        ? p.content!
        : '';
    return text;
  }

  int get _displayCommentsCount => widget.post.commentCount ?? 0;

  String? get _profileImageUrl {
    final img = widget.post.userId?.profileImage;
    return img is String && img.isNotEmpty ? img : null;
  }

  List<String> get _networkImages {
    final list = widget.post.images;
    if (list == null || list.isEmpty) return const [];
    return list.where((e) => e.isNotEmpty).toList();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _isLiked = widget.post.isLiked ?? false;

    // Generate unique hero tag
    _heroTag = widget.heroTagPrefix != null
        ? 'like_hero_${widget.heroTagPrefix}'
        : 'like_hero_${_displayUserName}_${_displayTimeAgo}_${widget.key?.hashCode ?? hashCode}';

    // Menu animation controller
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    // Like animation: quick pop-in (0→1.2), slight bounce (1.2→1.0), then fade out
    _likeAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _likeScaleAnimation =
        TweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.2), weight: 1),
          TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: _likeAnimationController,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
          ),
        );
    _likeOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
      ),
    );

    // Zoom return animation (smooth animate back to feed position)
    _zoomReturnController = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _zoomReturnAnimation = CurvedAnimation(parent: _zoomReturnController, curve: Curves.easeOutCubic);
    _zoomReturnController.addStatusListener(_onZoomReturnStatus);

    // _resolveFirstImageAspectRatio();
  }

  void _onZoomReturnStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _removeZoomOverlay();
      _zoomReturnController.reset();
    }
  }

  void _removeZoomOverlay() {
    _zoomOverlayEntry?.remove();
    _zoomOverlayEntry = null;
    _zoomStartRect = null;
  }

  @override
  void didUpdateWidget(CommonPostDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update like state if widget.isLiked changes from parent
    final newLiked = widget.post.isLiked ?? false;
    final oldLiked = oldWidget.post.isLiked ?? false;
    if (oldLiked != newLiked) {
      _isLiked = newLiked;
    }
  }

  @override
  void dispose() {
    _closeMenu();
    _removeZoomOverlay();
    _zoomReturnController.removeStatusListener(_onZoomReturnStatus);
    _zoomReturnController.dispose();
    _zoomScaleNotifier.dispose();
    _showHeartNotifier.dispose();
    _animationController.dispose();
    _likeAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onDoubleTap(TapDownDetails details) {
    // Instant UI update: like state and count (no wait for API)
    if (!_isLiked) {
      setState(() {
        _isLiked = true;
        //       widget.post.likeCount = (widget.post.likeCount ?? 0) + 1;
      });
      widget.onLike?.call();
    }

    // Show heart animation (ValueNotifier avoids rebuilding entire feed item)
    _showHeartNotifier.value = true;
    _likeAnimationController.forward().then((_) {
      if (mounted) {
        _showHeartNotifier.value = false;
        _likeAnimationController.reset();
      }
    });
  }

  bool get _isMultiImage {
    if (_networkImages.isNotEmpty) return _networkImages.length > 1;
    return false;
  }

  void _showMenu() {
    if (_overlayEntry != null) return;

    final RenderBox? renderBox = _moreOptionsKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final isCurrentUserPost = widget.post.userId?.id == PrefService.getString(PrefKeys.userId);
    final isSave = widget.post.isSaved ?? true;
    String shareableLink = widget.post.shareableLink ?? 'Unavailable';

    _overlayEntry = OverlayEntry(
      builder: (context) => PopupMenuOverlay(
        post: widget.post,
        position: position,
        size: size,
        isSave: isSave,
        scaleAnimation: _scaleAnimation,
        opacityAnimation: _opacityAnimation,
        showDelete: isCurrentUserPost,
        onSave: () {
          _closeMenu(then: () => widget.onSave?.call());
        },
        onReport: () {
          _closeMenu(then: () => widget.onReport?.call());
        },
        onCopyLink: () {
          _closeMenu(then: () => Clipboard.setData(ClipboardData(text: shareableLink)));
        },
        onShare: () {
          _closeMenu(then: () => widget.onShare?.call());
        },
        onDelete: () {
          _closeMenu(then: _performDelete);
        },
        onDismiss: () => _closeMenu(),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();

    // Push a transparent route so system back closes the popup instead of the screen
    _menuNavigator = Navigator.of(context);
    _menuNavigator!.push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _closeMenu();
          },
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// Closes the more-options overlay; runs [then] only after the route is popped and the overlay is removed
  /// so parent actions (e.g. [Get.back], bottom sheets) do not run while the overlay is still visible.
  void _closeMenu({VoidCallback? then}) {
    if (_overlayEntry != null) {
      _menuNavigator?.pop();
      _menuNavigator = null;
      _animationController.reverse().then((_) {
        if (!mounted) return;
        _overlayEntry?.remove();
        _overlayEntry = null;
        then?.call();
      });
    } else {
      then?.call();
    }
  }

  Future<void> _performDelete() async {
    final confirmed = await showDeleteConfirmationDialog(context);
    if (!confirmed) return;
    final contentId = widget.post.id;
    if (contentId == null || contentId.isEmpty) {
      AppFunctions().showToast('Invalid post', bgColor: AppColors.red);
      return;
    }
    final repo = Get.isRegistered<NotificationRepository>()
        ? Get.find<NotificationRepository>()
        : Get.put(NotificationRepository());
    repo.deleteContentByTypeAndId(
      contentId: contentId,
      contentType: widget.post.contentType ?? 'Post',
      onSuccess: (response) {
        AppFunctions().showToast(response.message ?? "Content deleted successfully", bgColor: AppColors.green);
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().feedData.value!.posts!.removeWhere((element) => element.id == contentId);
          Get.find<HomeController>().feedData.refresh();
        }
        widget.onDelete?.call();
      },
      onError: (AppException e) {
        AppFunctions().showToast(e.message, bgColor: AppColors.red);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.whiteFFFFFF,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                /// Profile + name section
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final targetUserId = widget.post.userId?.id?.trim() ?? '';
                      if (targetUserId.isEmpty) return;
                      if (!widget.isNavigation) return;
                      Get.toNamed(
                        AppRoutes.otherUserProfile,
                        arguments: {'userId': targetUserId},
                        preventDuplicates: false,
                      );
                    },
                    child: Row(
                      children: [
                        CommonProfileImage(imageUrl: _profileImageUrl, width: 40.r, height: 40.r),

                        SizedBox(width: 12.w),

                        /// Username
                        Flexible(
                          child: Text(
                            _displayUserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.medium(16.sp, fontColor: AppColors.gray707070),
                          ),
                        ),

                        Gap(3.w),
                        if (widget.post.userId?.isVerifiedBadge == true) ...[
                          Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                          Gap(5.w),
                        ],
                        Container(
                          height: 6.h,
                          width: 6.w,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.whiteEAEAEA),
                        ),

                        Gap(5.w),

                        Text(_displayTimeAgo, style: TextStyles.medium(16.sp, fontColor: AppColors.gray707070)),
                        Gap(5.w),
                      ],
                    ),
                  ),
                ),

                /// More options button
                PressScaleButton(
                  onTap: _showMenu,
                  child: KeyedSubtree(
                    key: _moreOptionsKey,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                      child: Icon(Icons.more_horiz, color: AppColors.black2F3039, size: 20.sp),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Caption with @mentions highlighted and tappable
          if (_displayCaption.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: _ExpandableCaptionWithMentions(
                    text: _displayCaption,
                    mentionedUsers: widget.post.mentionedUsers,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 4.h),
              ],
            ),
          // Post Image with Carousel
          _buildImageCarousel(context),
          // Interaction Bar
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
                        setState(() {
                          _isLiked = !_isLiked;
                        });
                        widget.onLike?.call();
                      },
                      child: Hero(
                        tag: _heroTag,
                        child: widget.post.isLiked ?? false
                            ? Assets.icons.icLike.svg()
                            : Assets.icons.icLikeBorder.svg(),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    PressScaleButton(
                      onTap: () {
                        LikedByBottomSheet.show(
                          context: context,
                          contentId: widget.post.id ?? '',
                          contentType: widget.post.contentType ?? 'Post',
                        );
                      },
                      child: Text(
                        _formatCount(widget.post.likeCount ?? 0),
                        style: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 20.w),
                // Comment
                PressScaleButton(
                  onTap: widget.onComment,
                  child: Row(
                    children: [
                      Assets.icons.icComment.svg(),
                      SizedBox(width: 4.w),
                      Text(
                        _formatCount(_displayCommentsCount),
                        style: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20.w),
                // Share
                PressScaleButton(onTap: widget.onShare, child: Assets.icons.icShare.svg()),
                const Spacer(),
                // Bookmark — outline always black; fill interior only when saved
                PressScaleButton(
                  onTap: widget.onBookmark,
                  child: (widget.post.isSaved ?? false) ? Assets.icons.icSaveFill.svg() : Assets.icons.icSave.svg(),
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

  double _zoomScaleStart = 1.0;

  void _onImageScaleStart(ScaleStartDetails details) {
    if (details.pointerCount >= 2 && _networkImages.isNotEmpty) {
      final box = _zoomImageKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        _zoomStartRect = box.localToGlobal(Offset.zero) & box.size;
        _zoomScaleNotifier.value = 1.0;
        _zoomScaleStart = 1.0;
        _showZoomOverlay();
      }
    }
  }

  void _onImageScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2 && _zoomOverlayEntry != null) {
      final newScale = (_zoomScaleStart * details.scale).clamp(_minZoomScale, _maxZoomScale);
      _zoomScaleNotifier.value = newScale;
    }
  }

  void _onImageScaleEnd(ScaleEndDetails details) {
    if (_zoomOverlayEntry == null || _zoomReturnController.isAnimating) return;
    _zoomScaleAtReturnStart = _zoomScaleNotifier.value;
    if (_zoomScaleAtReturnStart > 1.0) {
      _zoomReturnController.forward();
    } else {
      _removeZoomOverlay();
    }
  }

  void _showZoomOverlay() {
    if (_zoomStartRect == null || _zoomOverlayEntry != null) return;
    final imageUrl = _networkImages[_currentPage];
    final screenSize = MediaQuery.sizeOf(context);
    _zoomOverlayEntry = OverlayEntry(
      builder: (context) => _FeedImageZoomOverlay(
        imageUrl: imageUrl,
        startRect: _zoomStartRect!,
        screenSize: screenSize,
        scaleNotifier: _zoomScaleNotifier,
        returnAnimation: _zoomReturnAnimation,
        scaleAtReturnStart: () => _zoomScaleAtReturnStart,
        minScale: _minZoomScale,
        maxScale: _maxZoomScale,
        onScaleEnd: () {
          _zoomScaleAtReturnStart = _zoomScaleNotifier.value;
          if (_zoomScaleAtReturnStart > 1.0) {
            _zoomReturnController.forward();
          } else {
            _removeZoomOverlay();
          }
        },
      ),
    );
    Overlay.of(context).insert(_zoomOverlayEntry!);
  }

  Widget _buildImageCarousel(BuildContext context) {
    // Use aspect ratio from PostData (set when API sends it) or from cache (resolved on first image load).
    final postId = widget.post.id ?? '';
    final aspectRatio = widget.post.imageAspectRatio ?? _postAspectRatioCache[postId] ?? 1.0;

    // Generate unique hero tag prefix using widget key hashCode or provided prefix
    final uniquePrefix =
        widget.heroTagPrefix ?? 'post_${widget.key?.hashCode ?? hashCode}_${_displayUserName}_$_displayTimeAgo';

    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(color: AppColors.grayEDF1F4),
          clipBehavior: Clip.hardEdge,
          child: GestureDetector(
            onDoubleTapDown: _onDoubleTap,
            onScaleStart: _onImageScaleStart,
            onScaleUpdate: _onImageScaleUpdate,
            onScaleEnd: _onImageScaleEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_networkImages.isNotEmpty)
                  RepaintBoundary(
                    key: _zoomImageKey,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: _networkImages.length,
                      physics: const ClampingScrollPhysics(),
                      pageSnapping: true,
                      itemBuilder: (context, index) {
                        final needResolveRatio =
                            index == 0 &&
                            widget.post.imageAspectRatio == null &&
                            !_postAspectRatioCache.containsKey(postId);
                        return Hero(
                          tag: '${uniquePrefix}_image_$index',
                          child: CommonNetworkImage(
                            imageUrl: _networkImages[index],
                            fit: BoxFit.contain,
                            useShimmerPlaceholder: true,
                            onImageLoaded: needResolveRatio
                                ? (Size size) {
                                    if (size.height > 0 && mounted) {
                                      final ratio = size.width / size.height;
                                      _postAspectRatioCache[postId] = ratio;
                                      setState(() {});
                                    }
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
                  )
                else
                  Center(child: Assets.icons.icImgPlaceholder.image()),

                // Heart animation overlay: quick pop-in, slight bounce, fade out (Instagram-style)
                ValueListenableBuilder<bool>(
                  valueListenable: _showHeartNotifier,
                  builder: (context, showHeart, _) {
                    if (!showHeart) return const SizedBox.shrink();
                    return RepaintBoundary(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _likeAnimationController,
                          builder: (context, _) {
                            return Opacity(
                              opacity: _likeOpacityAnimation.value,
                              child: Transform.scale(
                                scale: _likeScaleAnimation.value,
                                child: Assets.icons.icLike.svg(height: 88, width: 88),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),

                // Image counter overlay (top right)
                if (_isMultiImage)
                  Positioned(
                    top: 12.h,
                    right: 12.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.black000000.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '${_currentPage + 1}/${_networkImages.length}',
                        style: TextStyles.medium(12.sp, fontColor: AppColors.whiteFFFFFF),
                      ),
                    ),
                  ),

                // Page indicators (bottom center)
                if (_isMultiImage)
                  Positioned(
                    bottom: 12.h,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _networkImages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.symmetric(horizontal: 3.w),
                          width: _currentPage == index ? 24.w : 6.w,
                          height: 6.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3.r),
                            color: _currentPage == index
                                ? AppColors.whiteFFFFFF
                                : AppColors.whiteFFFFFF.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}k';
    }
    return count.toString();
  }

  // Caption "read more" is implemented by `_ExpandableCaptionWithMentions`.
}

class _ExpandableCaptionWithMentions extends StatefulWidget {
  const _ExpandableCaptionWithMentions({required this.text, required this.mentionedUsers, required this.fontSize});

  final String text;
  final List<UserId>? mentionedUsers;
  final double fontSize;

  @override
  State<_ExpandableCaptionWithMentions> createState() => _ExpandableCaptionWithMentionsState();
}

class _ExpandableCaptionWithMentionsState extends State<_ExpandableCaptionWithMentions> {
  static const int _collapsedMaxLines = 2; // keep same default as previous UI
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure overflow only in collapsed mode; maxLines: null makes didExceedMaxLines false.
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
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    _isExpanded ? 'Read less' : 'Read more',
                    style: TextStyles.semiBold(14.sp, fontColor: AppColors.gray707070),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Full-screen overlay for pinch-to-zoom: image detaches, zooms over screen with dark barrier, animates back on release.
class _FeedImageZoomOverlay extends StatefulWidget {
  final String imageUrl;
  final Rect startRect;
  final Size screenSize;
  final ValueNotifier<double> scaleNotifier;
  final Animation<double> returnAnimation;
  final double Function() scaleAtReturnStart;
  final double minScale;
  final double maxScale;
  final VoidCallback onScaleEnd;

  const _FeedImageZoomOverlay({
    required this.imageUrl,
    required this.startRect,
    required this.screenSize,
    required this.scaleNotifier,
    required this.returnAnimation,
    required this.scaleAtReturnStart,
    required this.minScale,
    required this.maxScale,
    required this.onScaleEnd,
  });

  @override
  State<_FeedImageZoomOverlay> createState() => _FeedImageZoomOverlayState();
}

class _FeedImageZoomOverlayState extends State<_FeedImageZoomOverlay> {
  double _scaleStart = 1.0;
  Offset _offset = Offset.zero;

  Rect _centeredRect(double scale) {
    final w = widget.startRect.width * scale;
    final h = widget.startRect.height * scale;
    final c = Offset(widget.screenSize.width / 2, widget.screenSize.height / 2);
    return Rect.fromLTWH(c.dx - w / 2, c.dy - h / 2, w, h);
  }

  Rect _rectFor(double scale, Offset offset) {
    final w = widget.startRect.width * scale;
    final h = widget.startRect.height * scale;
    final c = Offset(widget.screenSize.width / 2, widget.screenSize.height / 2) + offset;
    return Rect.fromLTWH(c.dx - w / 2, c.dy - h / 2, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) {
          _scaleStart = widget.scaleNotifier.value;
        },
        onScaleUpdate: (ScaleUpdateDetails d) {
          final newScale = (_scaleStart * d.scale).clamp(widget.minScale, widget.maxScale);
          if (newScale != widget.scaleNotifier.value) {
            widget.scaleNotifier.value = newScale;
          }

          // Allow the user to drag the zoomed image around, similar to Instagram.
          // We accumulate the drag based on the focal point delta and clamp it so
          // that the image never leaves empty space on any side.
          if (newScale > 1.0) {
            final proposedOffset = _offset + d.focalPointDelta;

            final w = widget.startRect.width * newScale;
            final h = widget.startRect.height * newScale;
            final maxDx = (w - widget.screenSize.width) / 2;
            final maxDy = (h - widget.screenSize.height) / 2;

            final clampedDx = maxDx <= 0 ? 0.0 : proposedOffset.dx.clamp(-maxDx, maxDx);
            final clampedDy = maxDy <= 0 ? 0.0 : proposedOffset.dy.clamp(-maxDy, maxDy);

            setState(() {
              _offset = Offset(clampedDx, clampedDy);
            });
          } else if (_offset != Offset.zero) {
            // When the user pinches back to the original scale, gently snap the
            // image back to its centered position.
            setState(() {
              _offset = Offset.zero;
            });
          }
        },
        onScaleEnd: (_) {
          widget.onScaleEnd();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.scaleNotifier, widget.returnAnimation]),
          builder: (context, _) {
            final scale = widget.scaleNotifier.value;
            final returnT = widget.returnAnimation.value;
            final isReturning =
                widget.returnAnimation.status == AnimationStatus.forward ||
                widget.returnAnimation.status == AnimationStatus.completed;

            // Barrier: darken as zoom increases; fade out during return
            final barrierOpacity = isReturning
                ? (1.0 - returnT).clamp(0.0, 1.0)
                : (0.15 + (scale - 1.0) * 0.22).clamp(0.0, 0.55);

            Rect rect;
            if (isReturning && returnT < 1.0) {
              final startZoomRect = _centeredRect(widget.scaleAtReturnStart());
              rect = Rect.lerp(startZoomRect, widget.startRect, returnT)!;
            } else {
              // While interacting, position the image based on the current scale
              // and drag offset so that it can be panned around the screen.
              rect = _rectFor(scale, _offset);
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                // Dark barrier
                Positioned.fill(
                  child: Container(color: AppColors.black000000.withValues(alpha: barrierOpacity)),
                ),
                // Zoomed image (full screen, not clipped)
                Positioned(
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                  child: CommonNetworkImage(
                    imageUrl: widget.imageUrl,
                    width: rect.width,
                    height: rect.height,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    memCacheHeight: 800,
                    useShimmerPlaceholder: true,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PopupMenuOverlay extends StatelessWidget {
  final PostData? post;
  final Offset position;
  final Size size;
  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;
  final bool showDelete;
  final bool isSave;
  final VoidCallback onSave;
  final VoidCallback onReport;
  final VoidCallback onCopyLink;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  const PopupMenuOverlay({
    super.key,
    required this.position,
    required this.size,
    required this.scaleAnimation,
    required this.opacityAnimation,
    this.showDelete = false,
    this.isSave = false,
    required this.onSave,
    required this.onReport,
    required this.onCopyLink,
    required this.onShare,
    required this.onDelete,
    required this.onDismiss,
    this.post,
  });

  // Create staggered animations for each menu item
  List<Animation<double>> _createItemAnimations(Animation<double> parent) {
    final itemCount = showDelete ? 5 : 4;
    const staggerDelay = 0.08; // Delay between each item (8% of total duration)
    const itemDuration = 0.3; // Duration for each item animation (30% of total duration)

    return List.generate(itemCount, (index) {
      final start = index * staggerDelay;
      final end = start + itemDuration;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: parent,
          curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final menuWidth = 200.w;

    // Calculate position - center horizontally relative to the button
    final leftPosition = (position.dx + size.width / 2) - (menuWidth / 2);
    // Ensure menu doesn't go off screen
    final adjustedLeft = leftPosition.clamp(16.w, screenWidth - menuWidth - 16.w);

    // Position menu below the button with some spacing
    final topPosition = position.dy + size.height + 8.h;

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Menu
        Positioned(
          left: adjustedLeft,
          top: topPosition,
          child: AnimatedBuilder(
            animation: Listenable.merge([scaleAnimation, opacityAnimation]),
            builder: (context, child) {
              final itemAnimations = _createItemAnimations(opacityAnimation);

              return Transform.scale(
                scale: scaleAnimation.value,
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: opacityAnimation.value,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: menuWidth,
                      decoration: BoxDecoration(
                        color: AppColors.whiteFFFFFF,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black000000.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MenuItem(
                            label: isSave ? 'Unsave' : 'Save',
                            icon: isSave
                                ? Assets.icons.icSaveFill.svg(width: 20.w, height: 20.h)
                                : Assets.icons.icSave.svg(),
                            onTap: onSave,
                            animation: itemAnimations[0],
                          ),
                          _Divider(animation: itemAnimations[0]),
                          post?.userId?.id != PrefService.getString(PrefKeys.userId)
                              ? _MenuItem(
                                  label: 'Report',
                                  icon: Assets.icons.icReport.svg(width: 20.w, height: 20.h),
                                  onTap: onReport,
                                  animation: itemAnimations[1],
                                )
                              : SizedBox(),
                          post?.userId?.id != PrefService.getString(PrefKeys.userId)
                              ? _Divider(animation: itemAnimations[1])
                              : SizedBox(),
                          _MenuItem(
                            label: 'Copy link',
                            icon: Assets.icons.icCopy.svg(width: 20.w, height: 20.h),
                            onTap: onCopyLink,
                            animation: itemAnimations[2],
                          ),
                          _Divider(animation: itemAnimations[2]),
                          _MenuItem(
                            label: 'Share',
                            icon: Assets.icons.icBigShare.svg(width: 20.w, height: 20.h),
                            onTap: onShare,
                            animation: itemAnimations[3],
                          ),
                          if (showDelete) ...[
                            _Divider(animation: itemAnimations[3]),
                            _MenuItem(
                              label: 'Delete',
                              icon: Assets.icons.icDelete.svg(width: 20.w, height: 20.h),
                              onTap: onDelete,
                              isDestructive: true,
                              animation: itemAnimations[4],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final Animation<double> animation;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.animation,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 8 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: TextStyles.medium(
                          16.sp,
                          fontColor: isDestructive ? AppColors.redFF5353 : AppColors.black2F3039,
                        ),
                      ),
                      const Spacer(),
                      icon,
                    ],
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

class _Divider extends StatelessWidget {
  final Animation<double> animation;

  const _Divider({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Container(
            height: 1,
            margin: EdgeInsets.symmetric(horizontal: 8.w),
            color: AppColors.grayEDF1F4,
          ),
        );
      },
    );
  }
}
