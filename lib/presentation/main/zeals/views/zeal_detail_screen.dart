import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import 'package:omeeba_new/core/services/zeal_video_cache_service.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/core/widgets/delete_confirmation_dialog.dart';
import 'package:omeeba_new/presentation/main/zeals/views/zeals_view.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/helper/like_helper.dart';
import '../../../../core/utils/app_constant.dart';
import '../../../../core/widgets/liked_by_bottom_sheet.dart';
import '../../home/widgets/share_bottom_sheet.dart';
import '../../report/controller/report_controller.dart';
import '../../report/view/report_bottom_sheet.dart';
import '../../settings/controller/settings_controller.dart';
import '../controller/zeals_controller.dart';
import '../widget/comments_bottom_sheet.dart';
import '../widget/zeals_shimmer.dart';
import '../widget/zeal_unfollow_sheet.dart';

/// Full-screen zeal (video) detail. Plays video like [ZealsView] _ReelItem.
class ZealDetailScreen extends StatefulWidget {
  final VoidCallback? onDelete;
  final bool? savePage;
  final int? indexOnSave;

  const ZealDetailScreen({super.key, this.onDelete, this.savePage, this.indexOnSave});

  @override
  State<ZealDetailScreen> createState() => _ZealDetailScreenState();
}

class _ZealDetailScreenState extends State<ZealDetailScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasStartedPlaying = false;
  bool _isLiked = false;
  bool _isSave = false;
  final GlobalKey _moreOptionsKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;
  late Animation<double> _likeOpacityAnimation;
  bool _showHeroAnimation = false;
  bool _resumeOnAppResume = false;
  late AnimationController _menuAnimationController;
  late Animation<double> _menuScaleAnimation;
  late Animation<double> _menuOpacityAnimation;

  PostData? _postData;
  bool _isLoadingPost = false;
  String? _pendingCommentId;

  PostData? get _post => _postData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final args = Get.arguments;
    if (args is PostData) {
      // Full PostData passed directly (e.g. from feed, profile, explore).
      _postData = args;
      _isLiked = _postData?.isLiked ?? false;
      _isSave = _postData?.isSaved ?? false;
      // Defer video init to next frame so previous route can dispose and free memory before allocating decoder (reduces OOM).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _videoController == null && !_hasError) _initializeVideo();
      });
    } else if (args is Map) {
      // Only contentId provided (e.g. from notification). Fetch full data from API.
      final contentId = args['contentId']?.toString() ?? '';
      _pendingCommentId = args['commentId']?.toString();
      if (contentId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchPostData(contentId);
        });
      } else {
        _hasError = true;
        _errorMessage = 'Invalid content';
      }
    }
    // like animation controller
    _likeAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _likeScaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _likeOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );
    // Menu animation controller
    _menuAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _menuScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _menuAnimationController, curve: Curves.easeOutCubic));
    _menuOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _menuAnimationController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Remove overlay first so it doesn't reference disposed controllers
    _overlayEntry?.remove();
    _overlayEntry = null;
    // Pause then dispose video to release ExoPlayer/MediaCodec buffers and avoid OOM
    _videoController?.pause();
    _videoController?.removeListener(_videoErrorListener);
    _videoController?.dispose();
    _videoController = null;
    _likeAnimationController.dispose();
    _menuAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Remember whether this instance was actively playing before app lost focus.
        _resumeOnAppResume = _videoController!.value.isPlaying;
        _videoController!.pause();
        break;
      case AppLifecycleState.resumed:
        // Resume only if it was playing before backgrounding; honor manual pause.
        if (_resumeOnAppResume && _hasStartedPlaying && !_hasError) {
          _videoController!.play();
        }
        _resumeOnAppResume = false;
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _videoErrorListener() {
    if (mounted && _videoController != null && _videoController!.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Video playback error';
      });
    }
  }

  Future<void> _initializeVideo() async {
    final post = _post;
    final url = post?.mediaUrl ?? '';
    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No video URL';
        });
      }
      return;
    }
    try {
      final cache = Get.find<ZealVideoCacheService>();
      final cachedPath = await cache.getCachedPath(url);
      if (!mounted) return;
      final VideoPlayerController controller;
      if (cachedPath != null && cachedPath.isNotEmpty && File(cachedPath).existsSync()) {
        controller = VideoPlayerController.file(File(cachedPath));
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        // Do not preload same URL here — we're already playing it; preload would add memory/network pressure and can contribute to OOM.
      }
      if (!mounted) {
        controller.dispose();
        return;
      }
      _videoController = controller;
      controller.addListener(_videoErrorListener);

      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Video loading timeout'),
      );
      if (!mounted || _videoController != controller) return;
      controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {
          _hasError = false;
          _hasStartedPlaying = true;
        });
      }
    } on TimeoutException {
      _videoController?.removeListener(_videoErrorListener);
      _videoController?.dispose();
      _videoController = null;
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Video loading timeout. Please check your connection.';
        });
      }
    } catch (e) {
      _videoController?.removeListener(_videoErrorListener);
      _videoController?.dispose();
      _videoController = null;
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  void _retryVideo() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
    _videoController?.pause();
    _videoController?.removeListener(_videoErrorListener);
    _videoController?.dispose();
    _videoController = null;
    _initializeVideo();
  }

  /// Called when only a contentId was passed as arguments.
  /// Fetches the full Zeal [PostData] from the API then starts video playback.
  Future<void> _fetchPostData(String contentId) async {
    if (!mounted) return;
    setState(() => _isLoadingPost = true);

    final repo = Get.isRegistered<NotificationRepository>()
        ? Get.find<NotificationRepository>()
        : Get.put(NotificationRepository());

    await repo.fetchContentByTypeAndId(
      contentId: contentId,
      apiContentType: 'Zeal Post',
      onSuccess: (data) {
        if (!mounted) return;
        setState(() {
          _postData = data;
          _isLiked = data.isLiked ?? false;
          _isSave = data.isSaved ?? false;
          _isLoadingPost = false;
        });
        _initializeVideo();

        final commentId = _pendingCommentId;
        if (commentId != null && commentId.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            CommentsBottomSheet.show(
              postId: data.id ?? contentId,
              commentsCount: data.commentCount ?? 0,
              contentType: 'Zeal Post',
              highlightCommentId: commentId,
              onCommentAdded: (newCount) {
                data.commentCount = newCount;
              },
            );
          });
        }
      },
      onError: (AppException e) {
        if (!mounted) return;
        setState(() {
          _isLoadingPost = false;
          _hasError = true;
          _errorMessage = e.message;
        });
      },
    );
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _resumeOnAppResume = false;
      } else {
        _videoController!.play();
        _resumeOnAppResume = true;
      }
    });
  }

  /// Pushing a route (e.g. profile) does not dispose this screen, so pause playback
  /// until the user returns; resume only if video was playing before navigation.
  Future<void> _navigateToUserProfile(String userId) async {
    if (userId.isEmpty) return;
    final controller = _videoController;
    final wasPlaying =
        controller != null && controller.value.isInitialized && controller.value.isPlaying;
    if (wasPlaying) {
      controller.pause();
      _resumeOnAppResume = false;
    }
    await Get.toNamed(AppRoutes.otherUserProfile, arguments: userId);
    if (!mounted) return;
    if (wasPlaying &&
        _videoController != null &&
        _videoController!.value.isInitialized &&
        !_hasError) {
      await _videoController!.play();
      if (mounted) setState(() {});
    }
  }

  void _onDoubleTap() {
    // animation
    setState(() {
      _showHeroAnimation = true;
    });

    _likeAnimationController.forward().then((_) {
      if (mounted) {
        setState(() {
          _showHeroAnimation = false;
        });
        _likeAnimationController.reset();
      }
    });

    // like only if not already liked
    if (!_isLiked) {
      setState(() {
        _isLiked = true;
        _post!.likeCount = (_post!.likeCount ?? 0) + 1;
      });

      LikeHelper.toggleLike(
        contentId: _post!.id ?? '',
        contentType: _post!.contentType ?? 'Post',
        isLiked: _post!.isLiked ?? false,
        likeCount: _post!.likeCount ?? 0,
        onLocalUpdate: (liked, count) {
          //  widget.post.isLiked = liked;
          //widget.post.likeCount = count;
        },
      );
    }
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        // unlike
        _isLiked = false;
        _post!.likeCount = ((_post!.likeCount ?? 1) - 1).clamp(0, 999999999);
      } else {
        // like
        _isLiked = true;
        _post!.likeCount = (_post!.likeCount ?? 0) + 1;
      }
    });

    void _likeSheet(){
      LikedByBottomSheet.show(
        context: context,
        contentId: _post!.id ?? '',
        contentType: _post!.contentType ?? 'Zeal Post',
      );
    }

    LikeHelper.toggleLike(
      contentId: _post!.id ?? '',
      contentType: _post!.contentType ?? 'Post',
      isLiked: _post!.isLiked ?? false,
      likeCount: _post!.likeCount ?? 0,
      onLocalUpdate: (liked, count) {
        //   widget.post.isLiked = liked;
        //   widget.post.likeCount = count;
      },
    );
  }

  void _showMenu() {
    if (_overlayEntry != null) return;

    final RenderBox? renderBox = _moreOptionsKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final post = _post;
    final isCurrentUserPost = post?.userId?.id == PrefService.getString(PrefKeys.userId);
    _overlayEntry = OverlayEntry(
      builder: (context) => PopupReelMenuOverlay(
        position: position,
        size: size,
        scaleAnimation: _menuScaleAnimation,
        opacityAnimation: _menuOpacityAnimation,
        showDelete: isCurrentUserPost,
        onReport: () {
          _closeMenu();
          Get.find<ReportController>().reset();
          Get.find<ReportController>().getReportsCategories(context);
          ReportBottomSheet.show(postId: post!.id ?? '', postType: post.contentType ?? 'Zeal Post');
        },
        onDelete: () {
          _closeMenu();
          _performZealDelete();
        },
        isSave: _isSave,
        onSave: widget.savePage == true
            ? () {
                _closeMenu();
                //              Get.find<ZealsController>().saveUnSavePost(context, post ?? PostData());
                Get.find<SettingsController>().unsaveAndRemoveFromList(
                  context,
                  "Zeal Post",
                  post!.id ?? "",
                  Get.find<SettingsController>().savedZeals,
                  widget.indexOnSave ?? 0,
                );
                Get.back();
              }
            : () {
                _closeMenu();
                Get.find<ZealsController>().saveUnSavePost(context, post ?? PostData());

                if (_isSave == true) {
                  post?.isSaved = false;
                  setState(() {
                    _isSave = false;
                  });
                } else {
                  post?.isSaved = true;
                  setState(() {
                    _isSave = true;
                  });
                }
              },
        onDismiss: _closeMenu,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _menuAnimationController.forward();
  }

  void _closeMenu() {
    _menuAnimationController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  Widget _buildFollowButton(PostData post) {
    final userId = post.userId?.id;
    final currentUserId = PrefService.getString(PrefKeys.userId);
    if (userId == null || userId.isEmpty || userId == currentUserId) {
      return const SizedBox.shrink();
    }
    final following = post.isFollowing == true;
    final zealController = Get.find<ZealsController>();
    return TextButton(
      onPressed: () {
        if (following) {
          ZealUnfollowSheet.show(
            controller: zealController,
            userId: userId,
            onSuccess: () => setState(() {
              _postData = _postData?.copyWith(isFollowing: false);
            }),
          );
        } else {
          zealController.followUser(
            userId,
            onSuccess: () => setState(() {
              _postData = _postData?.copyWith(isFollowing: true);
            }),
            onError: (msg) => AppFunctions().showToast(msg, bgColor: AppColors.red),
          );
        }
      },
      // style: TextButton.styleFrom(
      //   minimumSize: Size(0, 28.h),
      //   padding: EdgeInsets.symmetric(horizontal: 12.w),
      //   backgroundColor: following ? AppColors.grayEDF1F4 : AppColors.primaryColor,
      //   foregroundColor: following ? AppColors.black2F3039 : AppColors.whiteFFFFFF,
      //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
      // ),
      child: Text(
        following ? 'Following' : 'Follow',
        style: TextStyles.medium(12.sp, fontColor: AppColors.whiteFFFFFF),
      ),
    );
  }

  Future<void> _performZealDelete() async {
    final post = _post;
    if (post == null) return;
    final confirmed = await showDeleteConfirmationDialog(context);
    if (!confirmed) return;
    final contentId = post.id;
    if (contentId == null || contentId.isEmpty) {
      AppFunctions().showToast('Invalid post', bgColor: AppColors.red);
      return;
    }
    final repo = Get.isRegistered<NotificationRepository>()
        ? Get.find<NotificationRepository>()
        : Get.put(NotificationRepository());
    repo.deleteContentByTypeAndId(
      contentId: contentId,
      contentType: post.contentType ?? 'Zeal Post',
      onSuccess: (response) {
        AppFunctions().showToast(response.message ?? "Zeal deleted successfully", bgColor: AppColors.green);
        widget.onDelete?.call();
        Get.back(result: contentId);
      },
      onError: (AppException e) {
        AppFunctions().showToast(e.message, bgColor: AppColors.red);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;

    // Show shimmer while fetching post data from API (contentId-only navigation path).
    if (_isLoadingPost) {
      return Scaffold(
        backgroundColor: AppColors.black000000,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ZealsShimmer(),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Assets.icons.icArrowBack.image(height: 24.h, width: 24.w, color: AppColors.whiteFFFFFF),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (post == null) {
      return Scaffold(
        backgroundColor: AppColors.black000000,
        appBar: AppBar(
          backgroundColor: AppColors.black000000,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Get.back(),
            icon: Assets.icons.icArrowBack.image(height: 24.h, width: 24.w, color: AppColors.whiteFFFFFF),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
          ),
        ),
        body: const Center(
          child: Text('Zeal not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    if (_videoController == null && !_hasError) {
      return Scaffold(
        backgroundColor: AppColors.black000000,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ZealsShimmer(),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Assets.icons.icArrowBack.image(height: 24.h, width: 24.w, color: AppColors.whiteFFFFFF),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: AppColors.black000000,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppColors.whiteFFFFFF, size: 48.sp),
                    SizedBox(height: 16.h),
                    Text(
                      _errorMessage ?? 'Failed to load video',
                      style: TextStyles.regular(14.sp, fontColor: AppColors.whiteFFFFFF),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h),
                    ElevatedButton(
                      onPressed: _retryVideo,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
                      child: Text('Retry', style: TextStyles.medium(14.sp, fontColor: AppColors.whiteFFFFFF)),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Assets.icons.icArrowBack.image(height: 24.h, width: 24.w, color: AppColors.whiteFFFFFF),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final controller = _videoController!;
    if (!controller.value.isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.black000000,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ZealsShimmer(),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Assets.icons.icArrowBack.image(height: 24.h, width: 24.w, color: AppColors.whiteFFFFFF),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final videoAspectRatio = controller.value.aspectRatio;
    final isVideoVertical = videoAspectRatio < 1.0;

    return Scaffold(
      backgroundColor: AppColors.black000000,
      body: GestureDetector(
        onDoubleTap: () => _onDoubleTap(),
        onTap: _togglePlayPause,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.black000000),
            Center(
              child: isVideoVertical
                  ? FittedBox(
                      fit: BoxFit.fitHeight,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            if (_showHeroAnimation)
              Center(
                child: AnimatedBuilder(
                  animation: _likeAnimationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _likeOpacityAnimation.value,
                      child: Hero(
                        tag: 'like_hero_${_post!.id}',
                        flightShuttleBuilder:
                            (
                              BuildContext flightContext,
                              Animation<double> animation,
                              HeroFlightDirection flightDirection,
                              BuildContext fromHeroContext,
                              BuildContext toHeroContext,
                            ) {
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, child) {
                                  // Scale from large (80) to small (28.sp) as it moves
                                  final scale = 1.0 - (animation.value * 0.65); // Scale from 1.0 to 0.35
                                  final size = 80.0 * (1 - animation.value) + 28.sp * animation.value;
                                  return Transform.scale(
                                    scale: scale,
                                    child: Assets.icons.icLike.svg(height: size, width: size),
                                  );
                                },
                              );
                            },
                        child: Transform.scale(
                          scale: _likeScaleAnimation.value,
                          child: Assets.icons.icLike.svg(height: 80, width: 80),
                        ),
                      ),
                    );
                  },
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Assets.icons.icArrowBack.image(height: 24.h, width: 24.w, color: AppColors.whiteFFFFFF),
                  padding: EdgeInsets.zero,
                  highlightColor: AppColors.transparentColor,
                  constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
                ),
              ),
            ),
            Positioned(
              right: 12.w,
              bottom: 10.h,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Like button
                  ActionButton(
                    heroTag: 'like_hero_${_post?.id}',
                    icon: _isLiked ? Assets.icons.icLike : Assets.icons.icLikeBorder,
                    iconColor: _isLiked ? null : AppColors.white,
                    count: _post?.likeCount ?? 0,
                    onTap: _toggleLike,
                    onCountTap: _likeSheet,
                    formatCount: formatCount,
                  ),

                  SizedBox(height: 20.h),
                  _ActionButton(
                    icon: Assets.icons.icComment,
                    iconColor: AppColors.whiteFFFFFF,
                    count: post.commentCount ?? 0,
                    formatCount: formatCount,
                    onTap: () => CommentsBottomSheet.show(
                      contentType: 'Zeal Post',
                      postId: post.id ?? '',
                      commentsCount: post.commentCount ?? 0,
                      onCommentAdded: (newCount) {
                        post.commentCount = newCount;
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(height: 20.h),
                  _ActionButton(
                    icon: Assets.icons.icShare,
                    iconColor: AppColors.whiteFFFFFF,
                    count: post.shareCount ?? 0,
                    formatCount: formatCount,
                    onTap: () {
                      ShareBottomSheet.show(
                        postId: post.id,
                        postType: post.contentType,
                        shareUrl: post.shareableLink,
                        onShared: (count) {
                          post.shareCount = count;
                          setState(() {});
                        },
                      );
                    },
                  ),
                  Gap(10.h),
                  IconButton(
                    key: _moreOptionsKey,
                    onPressed: _showMenu,
                    icon: Icon(Icons.more_horiz, color: AppColors.white),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12.w,
              bottom: 20.h,
              right: 80.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      final userId = post.userId?.id;
                      if (userId != null && userId.isNotEmpty) {
                        _navigateToUserProfile(userId);
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 35.w,
                          height: 35.w,
                          decoration: const BoxDecoration(shape: BoxShape.circle),
                          child: CommonProfileImage(
                            imageUrl: post.userId?.profileImage?.toString(),
                            width: 35.w,
                            height: 35.w,
                          ),
                        ),
                        //       CommonProfileImage(imageUrl: post.userId?.profileImage?.toString(), width: 35.w, height: 35.w),
                        Gap(12.w),
                        Flexible(
                          child: Text(
                            post.userId?.name ?? 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF),
                          ),
                        ),
                        Gap(5.w),
                        if (post.userId?.isVerifiedBadge == true) ...[
                          Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                          Gap(5.w),
                        ],
                        if (post.isFollowing != null) ...[
                          Gap(6.w),
                          Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                          ),

                          _buildFollowButton(post),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (post.caption?.isNotEmpty ?? false)
                    _ExpandableCaption(
                      text: post.caption ?? "",
                      mentionedUsers: post.mentionedUsers,
                      fontSize: 14.sp,
                      onOpenUserProfile: _navigateToUserProfile,
                    ),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
            if (controller.value.isInitialized && !controller.value.isPlaying && !_hasError && _hasStartedPlaying)
              Center(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: Icon(Icons.play_arrow, color: AppColors.whiteFFFFFF, size: 40.sp),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds zeal caption with @mentions highlighted and tappable.

  void _likeSheet() {
    LikedByBottomSheet.show(
      context: context,
      contentId: _post!.id ?? '',
      contentType: _post!.contentType ?? 'Zeal Post',
    );
  }
}

class _ExpandableCaption extends StatefulWidget {
  final String text;
  final List<UserId>? mentionedUsers;
  final double fontSize;
  final Future<void> Function(String userId)? onOpenUserProfile;

  const _ExpandableCaption({
    required this.text,
    this.mentionedUsers,
    required this.fontSize,
    this.onOpenUserProfile,
  });

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    final baseStyle = TextStyles.regular(widget.fontSize, fontColor: AppColors.white);
    final mentionStyle = TextStyles.regular(widget.fontSize, fontColor: AppColors.primaryColor);
    final list = widget.mentionedUsers ?? [];
    final List<InlineSpan> spans = [];
    final mentionRegex = RegExp(r'@(\w+)');
    int lastIndex = 0;

    for (final match in mentionRegex.allMatches(widget.text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: widget.text.substring(lastIndex, match.start), style: baseStyle));
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
              ..onTap = () {
                final id = matchedUser!.id;
                if (id != null && id.isNotEmpty) {
                  final open = widget.onOpenUserProfile;
                  if (open != null) {
                    open(id);
                  } else {
                    Get.toNamed(AppRoutes.otherUserProfile, arguments: id);
                  }
                }
              },
          ),
        );
      } else {
        spans.add(TextSpan(text: match.group(0), style: baseStyle));
      }
      lastIndex = match.end;
    }
    if (lastIndex < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(lastIndex), style: baseStyle));
    }

    final fullSpan = TextSpan(children: spans, style: baseStyle);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(text: fullSpan, textDirection: TextDirection.ltr, maxLines: 8);
        tp.layout(maxWidth: constraints.maxWidth);
        final isOverflown = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isExpanded)
              RichText(text: fullSpan, maxLines: 4, overflow: TextOverflow.ellipsis)
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 200.h),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: RichText(text: fullSpan),
                ),
              ),
            if (isOverflown)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    _isExpanded ? "Read Less" : "Read More",
                    style: TextStyles.bold(widget.fontSize, fontColor: AppColors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final SvgGenImage icon;
  final Color? iconColor;
  final int count;
  final VoidCallback onTap;
  final String Function(int) formatCount;

  const _ActionButton({
    required this.icon,
    this.iconColor,
    required this.count,
    required this.onTap,
    required this.formatCount,
  });

  @override
  Widget build(BuildContext context) {
    return PressScaleButton(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 45.sp,
            height: 28.sp,
            child: iconColor == null
                ? icon.svg(height: 28.sp, width: 28.sp)
                : icon.svg(
                    height: 28.sp,
                    width: 28.sp,
                    colorFilter: ColorFilter.mode(iconColor ?? AppColors.white, BlendMode.srcIn),
                  ),
          ),
          SizedBox(height: 4.h),
          Text(formatCount(count), style: TextStyles.regular(12.sp, fontColor: AppColors.whiteFFFFFF)),
        ],
      ),
    );
  }
}
