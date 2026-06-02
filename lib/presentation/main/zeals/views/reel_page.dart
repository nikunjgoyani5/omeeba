import 'dart:async';
import 'package:omeeba_new/presentation/main/dashboard/controller/dashboard_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/controller/reel_page_controller.dart';

import 'package:omeeba_new/presentation/main/zeals/controller/reels_screen_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/models/post_model.dart';
import 'package:omeeba_new/presentation/main/zeals/views/widgets/double_tap_detector.dart';
import 'package:omeeba_new/presentation/main/zeals/views/widgets/reel_animation_like.dart';
import 'package:omeeba_new/presentation/main/zeals/views/zeals_view.dart';
import 'package:readmore/readmore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/utils/exports.dart';
import '../../../../core/widgets/common_post_detail_widget.dart';
import '../../../../core/widgets/common_profile_image.dart';

// ---------------------------------------------------------------
// REEL PAGE
// ---------------------------------------------------------------
class ReelPage extends StatefulWidget {
  final Post reelData;
  final int reelIndex;
  final bool autoPlay;

  final GlobalKey likeKey;
  final ReelsScreenController reelsScreenController;
  final Function(Post reel) onUpdateReelData;

  const ReelPage({
    super.key,
    required this.reelData,
    required this.reelIndex,
    this.autoPlay = false,

    required this.likeKey,
    required this.reelsScreenController,
    required this.onUpdateReelData,
  });

  @override
  State<ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isDisposed = false;
  bool isPlaying = true;
  late ReelController reelController;
  Rx<TapDownDetails?> details = Rx(null);
  final bool _showHeroAnimation = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;
  late Animation<double> _likeOpacityAnimation;
  GlobalKey moreOptionsKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late AnimationController _menuAnimationController;
  late Animation<double> _menuScaleAnimation;
  late Animation<double> _menuOpacityAnimation;
  bool _isMuted = false;
  bool _wasVisible = false;
  int? _lastCurrentIndex;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Listen to currentIndex changes to reset video when this reel becomes active
    ever(widget.reelsScreenController.currentIndex, (int currentIndex) {
      if (!_isDisposed && _controller != null && _controller!.value.isInitialized) {
        // Check if we're on the Zeals tab
        final dashboardController = Get.find<DashboardController>();
        final isOnZealsTab = dashboardController.currentIndex.value == 3; // Zeals tab index

        // If this reel just became the current page AND we're on Zeals tab, reset video to start
        if (currentIndex == widget.reelIndex && _lastCurrentIndex != widget.reelIndex && isOnZealsTab) {
          _controller!.seekTo(Duration.zero);
          if (!_controller!.value.isPlaying) {
            _controller!.play();
            isPlaying = true;
          }
          setState(() {});
        } else if (currentIndex != widget.reelIndex && _controller!.value.isPlaying) {
          // Pause if not the current page
          _controller!.pause();
          isPlaying = false;
          setState(() {});
        } else if (!isOnZealsTab && _controller!.value.isPlaying) {
          // Pause if not on Zeals tab
          _controller!.pause();
          isPlaying = false;
          setState(() {});
        }
      }
      _lastCurrentIndex = currentIndex;
    });
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
    // ✅ Setup Reel Controller
    if (Get.isRegistered<ReelController>(tag: '${widget.reelData.id}')) {
      reelController = Get.find<ReelController>(tag: '${widget.reelData.id}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // reelController.notifyCommentSheet(widget.postByIdData);
      });
    } else {
      reelController = Get.put(
        ReelController(widget.reelData.obs, widget.onUpdateReelData),
        tag: '${widget.reelData.id}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // reelController.notifyCommentSheet(widget.postByIdData);
      });
    }

    // Try to get pre-initialized controller first
    _tryInitializeVideo();
  }

  /// Try to initialize video - checks for pre-initialized controller first
  Future<void> _tryInitializeVideo() async {
    // Check if controller is already initialized in ReelsScreenController
    final preInitializedController = widget.reelsScreenController.getVideoController(widget.reelIndex);

    if (preInitializedController != null && preInitializedController.value.isInitialized) {
      // Use pre-initialized controller immediately
      await _usePreInitializedController(preInitializedController);
      return;
    }

    // If not pre-initialized, wait a bit and check again (in case it's still initializing)
    if (widget.reelIndex < widget.reelsScreenController.reels.length) {
      // Wait for pre-initialization (max 2 seconds)
      int attempts = 0;
      while (attempts < 20 && !_isDisposed) {
        await Future.delayed(const Duration(milliseconds: 100));
        final controller = widget.reelsScreenController.getVideoController(widget.reelIndex);
        if (controller != null && controller.value.isInitialized) {
          await _usePreInitializedController(controller);
          return;
        }
        attempts++;
      }
    }

    // Fallback: initialize on demand if not pre-initialized
    await _initializeAndPlayVideo();
  }

  /// Use a pre-initialized controller
  Future<void> _usePreInitializedController(VideoPlayerController preInitializedController) async {
    if (_isDisposed) return;

    _controller = preInitializedController;
    _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    _initialized = true;

    // Check if we're on the Zeals tab before playing
    final dashboardController = Get.find<DashboardController>();
    final isOnZealsTab = dashboardController.currentIndex.value == 3; // Zeals tab index

    // Reset to start if this is the current page AND we're on Zeals tab
    if (widget.reelsScreenController.currentIndex.value == widget.reelIndex && isOnZealsTab) {
      _controller!.seekTo(Duration.zero);
      if (!_controller!.value.isPlaying) {
        _controller!.play();
        isPlaying = true;
      }
    } else {
      // Not on Zeals tab or not current page - ensure paused
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        isPlaying = false;
      }
    }

    setState(() {});
  }

  void _closeMenu() {
    _menuAnimationController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  void showPopMenu() {
    if (_overlayEntry != null) return;

    final RenderBox? renderBox = moreOptionsKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => PopupMenuOverlay(
        post: null,
        position: position,
        size: size,
        scaleAnimation: _menuScaleAnimation,
        opacityAnimation: _menuOpacityAnimation,
        onReport: () {
          _closeMenu();
          // Handle report action
        },
        onDelete: () {
          _closeMenu();
          // Handle delete action
        },
        onDismiss: _closeMenu,
        onSave: () {},
        onCopyLink: () {},
        onShare: () {},
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _menuAnimationController.forward();
  }

  Future<void> _initializeAndPlayVideo({int retryCount = 0}) async {
    if (_isDisposed) return;

    // Try to get pre-initialized controller from ReelsScreenController
    final preInitializedController = widget.reelsScreenController.getVideoController(widget.reelIndex);

    if (preInitializedController != null && preInitializedController.value.isInitialized) {
      // Use pre-initialized controller
      _controller = preInitializedController;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      _initialized = true;

      // Reset to start if this is the current page
      if (widget.reelsScreenController.currentIndex.value == widget.reelIndex) {
        _controller!.seekTo(Duration.zero);
        if (!_controller!.value.isPlaying) {
          _controller!.play();
          isPlaying = true;
        }
      }

      setState(() {});
      return;
    }

    // If no pre-initialized controller, initialize on demand (fallback)
    try {
      final url = Uri.parse(widget.reelData.video ?? '');
      _controller = VideoPlayerController.networkUrl(url);

      await _controller!.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Video loading timeout after 15 seconds');
        },
      );

      if (_isDisposed) return;
      _controller!.setLooping(true);
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);

      // Check if we're on the Zeals tab before playing
      final dashboardController = Get.find<DashboardController>();
      final isOnZealsTab = dashboardController.currentIndex.value == 3; // Zeals tab index

      // Reset to start when initialized if this is the current page AND we're on Zeals tab
      if (widget.reelsScreenController.currentIndex.value == widget.reelIndex && isOnZealsTab) {
        _controller!.seekTo(Duration.zero);
        // Don't auto-play here - let visibility detector handle it
      } else {
        // Ensure paused if not on Zeals tab or not current page
        _controller!.pause();
      }
      _initialized = true;

      setState(() {});
    } catch (e) {
      debugPrint('Video init error: $e');

      // 🔁 Retry on MediaCodec/ExoPlayer errors (max 3 retries with exponential backoff)
      if (retryCount < 3 && !_isDisposed) {
        final isCodecError =
            e.toString().contains('MediaCodec') ||
            e.toString().contains('ExoPlaybackException') ||
            e.toString().contains('VideoError');

        if (isCodecError || retryCount < 2) {
          await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
          _initializeAndPlayVideo(retryCount: retryCount + 1);
        }
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Only dispose if we created the controller ourselves (not pre-initialized)
    // Pre-initialized controllers are managed by ReelsScreenController
    final preInitializedController = widget.reelsScreenController.getVideoController(widget.reelIndex);
    if (_controller != null && _controller != preInitializedController) {
      _controller?.dispose();
    }
    _controller = null;

    _closeMenu();

    _likeAnimationController.dispose();
    _menuAnimationController.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!_initialized || _controller == null || !_controller!.value.isInitialized) {
      // If not initialized yet, try to get pre-initialized controller
      if (!_initialized) {
        final preController = widget.reelsScreenController.getVideoController(widget.reelIndex);
        if (preController != null && preController.value.isInitialized) {
          _usePreInitializedController(preController);
        }
      }
      return;
    }

    // Check if we're on the Zeals tab
    final dashboardController = Get.find<DashboardController>();
    final isOnZealsTab = dashboardController.currentIndex.value == 3; // Zeals tab index

    final isVisible = (info.visibleFraction * 100) > 90;
    final isCurrentPage = widget.reelsScreenController.currentIndex.value == widget.reelIndex;

    // Only play if: visible AND on Zeals tab AND is current page AND no errors
    if (isVisible && isOnZealsTab && isCurrentPage && !_controller!.value.hasError) {
      // Use microtask to ensure state is stable
      Future.microtask(() {
        // Double-check conditions after microtask
        final dashboardController = Get.find<DashboardController>();
        final isOnZealsTab = dashboardController.currentIndex.value == 3;
        final isCurrentPage = widget.reelsScreenController.currentIndex.value == widget.reelIndex;

        if (!_isDisposed &&
            _controller != null &&
            _controller!.value.isInitialized &&
            !_controller!.value.hasError &&
            isOnZealsTab &&
            isCurrentPage) {
          try {
            // Reset to start if this reel is the current active page
            _controller!.seekTo(Duration.zero);
            if (!_controller!.value.isPlaying) {
              _controller!.play();
              isPlaying = true;
            }
            _wasVisible = true;
            setState(() {});
          } catch (e) {
            debugPrint('❌ Error playing video in visibility handler: $e');
          }
        }
      });
    } else {
      // Pause if not visible OR not on Zeals tab OR not current page
      if (_controller!.value.isPlaying) {
        try {
          _controller!.pause();
          isPlaying = false;
          _wasVisible = false;
          setState(() {});
        } catch (e) {
          debugPrint('❌ Error pausing video in visibility handler: $e');
        }
      }
    }
  }

  void onPlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      isPlaying = false;
    } else {
      _controller!.play();
      isPlaying = true;
    }
    setState(() {});
  }

  void _toggleVolume() {
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DoubleTapDetector(
      onDoubleTap: (value) {
        if (details.value != null) return;
        details.value = value;
        // print('dshgj');
        //
        // setState(() {
        //   _showHeroAnimation = true;
        // });
        //
        // // Always show animation on double tap
        // _likeAnimationController.forward().then((_) {
        //   if (mounted) {
        //     setState(() {
        //       _showHeroAnimation = false;
        //     });
        //     _likeAnimationController.reset();
        //   }
        // });
        //

        if (!(reelController.reelData.value.isLiked ?? false)) {
          setState(() {
            reelController.reelData.value.isLiked = true;
            reelController.reelData.value.likes = (reelController.reelData.value.likes ?? 0) + 1;
          });
        }
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          /// 🎬 Directly play video (no thumbnail, no loader)
          if (_controller != null) buildContent(),

          /// 🕹 Tap Overlay (pause/play)
          // InkWell(onTap: onPlayPause, child: const BlackGradientShadow()),
          InkWell(onTap: onPlayPause, child: const SizedBox()),

          /// 📊 Linear Progress Indicator at Top (Instagram-style)
          if (_controller != null && _controller!.value.isInitialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller!,
                builder: (context, value, _) {
                  final duration = value.duration.inMilliseconds;
                  final position = value.position.inMilliseconds;
                  final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

                  return LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.white.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                    minHeight: 2,
                  );
                },
              ),
            ),

          /// 🔊 Volume Toggle Button (Top Right)
          Positioned(
            top: 40.h,
            right: 16.w,
            child: GestureDetector(
              onTap: _toggleVolume,
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(shape: BoxShape.circle),
                child: _isMuted
                    ? Assets.icons.icMusicOff.svg(colorFilter: ColorFilter.mode(AppColors.white, BlendMode.srcIn))
                    : Assets.icons.icMusicOn.svg(colorFilter: ColorFilter.mode(AppColors.white, BlendMode.srcIn)),
                // Icon(
                //   _isMuted ? Icons.volume_off : Icons.volume_up,
                //   color: AppColors.whiteFFFFFF,
                //   size: 24.sp,
                // ),
              ),
            ),
          ),

          /// ▶ Play/Pause Icon overlay
          if (_controller != null)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isPlaying ? 0.0 : 1.0,

              child: Align(
                alignment: Alignment.center,
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(color: AppColors.black000000.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: AppColors.whiteFFFFFF, size: 40.sp),
                ),
              ),
            ),

          /// ℹ️ Reel Info Section
          ReelInfoSection(
            controller: reelController,
            likeKey: widget.likeKey,
            videoPlayerPlusController: _controller,
            onTapMenu: showPopMenu,
            menuOptionKey: moreOptionsKey,
          ),

          /// 💖 Like Animation 💖
          Obx(() {
            if (details.value == null) return const SizedBox();
            return ReelAnimationLike(
              likeKey: widget.likeKey,
              position: details.value!.globalPosition,
              size: const Size(50, 50),
              leftRightPosition: 8,
              onLikeCall: () {
                if (reelController.reelData.value.isLiked == true) return;
                // reelController.onLikeTap();
              },
              onCompleteAnimation: () => details.value = null,
            );
          }),
          // if (_showHeroAnimation)
          //   Center(
          //     child: AnimatedBuilder(
          //       animation: _likeAnimationController,
          //       builder: (context, child) {
          //         return Opacity(
          //           opacity: _likeOpacityAnimation.value,
          //           child: Hero(
          //             tag: 'like_hero_${reelController.reelData.value.id ?? 'oo'}',
          //             flightShuttleBuilder:
          //                 (
          //                   BuildContext flightContext,
          //                   Animation<double> animation,
          //                   HeroFlightDirection flightDirection,
          //                   BuildContext fromHeroContext,
          //                   BuildContext toHeroContext,
          //                 ) {
          //                   return AnimatedBuilder(
          //                     animation: animation,
          //                     builder: (context, child) {
          //                       // Scale from large (80) to small (28.sp) as it moves
          //                       final scale = 1.0 - (animation.value * 0.65); // Scale from 1.0 to 0.35
          //                       final size = 80.0 * (1 - animation.value) + 28.sp * animation.value;
          //                       return Transform.scale(
          //                         scale: scale,
          //                         child: Assets.icons.icLike.svg(height: size, width: size),
          //                       );
          //                     },
          //                   );
          //                 },
          //             child: Transform.scale(
          //               scale: _likeScaleAnimation.value,
          //               child: Assets.icons.icLike.svg(height: 80, width: 80),
          //             ),
          //           ),
          //         );
          //       },
          //     ),
          //   ),
        ],
      ),
    );
  }

  Widget buildContent() {
    Size size = _controller!.value.size;
    return VisibilityDetector(
      key: Key('reel_${widget.reelData.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: InkWell(
        onTap: onPlayPause,
        child: ClipRRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: (size.width < size.height) ? BoxFit.cover : BoxFit.fitWidth,
              child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(_controller!)),
            ),
          ),
        ),
      ),
    );
  }
}

class ReelInfoSection extends StatelessWidget {
  final ReelController controller;
  final GlobalKey likeKey;
  final VideoPlayerController? videoPlayerPlusController;
  final VoidCallback onTapMenu;
  final GlobalKey menuOptionKey;

  const ReelInfoSection({
    super.key,
    required this.controller,
    required this.likeKey,
    required this.videoPlayerPlusController,
    required this.onTapMenu,
    required this.menuOptionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ReelInfoRow(likeKey: likeKey, onTapMenu: onTapMenu, menuOptionKey: menuOptionKey, controller: controller),
        // ReelSeekBar(videoController: videoPlayerPlusController, controller: controller),
      ],
    );
  }
}

class ReelInfoRow extends StatefulWidget {
  final ReelController controller;
  final GlobalKey likeKey;
  final VoidCallback onTapMenu;
  final GlobalKey menuOptionKey;

  const ReelInfoRow({
    super.key,
    required this.controller,
    required this.likeKey,
    required this.onTapMenu,
    required this.menuOptionKey,
  });

  @override
  State<ReelInfoRow> createState() => _ReelInfoRowState();
}

class _ReelInfoRowState extends State<ReelInfoRow> {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 16.w, bottom: 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Username
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Navigate to profile
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 35.w,
                            height: 35.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // border: Border.all(color: AppColors.whiteFFFFFF, width: 2),
                            ),
                            child: CommonProfileImage(width: 35.w, height: 35.w),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Assets.icons.icVerifyProfile.svg(height: 12, width: 12),
                          ),
                        ],
                      ),
                    ),
                    Gap(12.w),
                    Text('Proya Apte', style: TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF)),
                    Gap(6.w),
                    Container(
                      height: 6,
                      width: 6,
                      decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                    ),
                    Gap(6.w),
                    Text("Follow", style: TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF)),
                  ],
                ),
                SizedBox(height: 8.h),

                ReadMoreText(
                  'Flutter is Google’s mobile UI open source framework to build high-quality native (super fast) interfaces for iOS and Android apps with the unified codebase.',
                  trimMode: TrimMode.Line,
                  trimLines: 2,
                  trimCollapsedText: 'More',
                  trimExpandedText: 'Less',
                  style: TextStyles.regular(14.sp, fontColor: AppColors.white),
                  moreStyle: TextStyles.regular(
                    14.sp,
                    fontColor: AppColors.white,
                    textDecoration: TextDecoration.underline,
                    decorationsColor: AppColors.white,
                  ),
                  lessStyle: TextStyles.regular(
                    14.sp,
                    fontColor: AppColors.white,
                    textDecoration: TextDecoration.underline,
                    decorationsColor: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        // SideBarList(controller: controller, likeKey: likeKey),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Like button
            ActionButton(
              key: widget.likeKey,
              heroTag: 'like_hero_${widget.controller.reelData.value.id ?? ''}',
              icon: widget.controller.reelData.value.isLiked ?? false ? Assets.icons.icLike : Assets.icons.icLikeBorder,
              iconColor: widget.controller.reelData.value.isLiked ?? false ? null : AppColors.white,
              count: int.parse(widget.controller.reelData.value.likes?.toString() ?? '0'),
              onTap: () {
                widget.controller.reelData.value.isLiked = !(widget.controller.reelData.value.isLiked ?? false);
                if (widget.controller.reelData.value.isLiked == true) {
                  widget.controller.reelData.value.likes = (widget.controller.reelData.value.likes ?? 0) + 1;
                } else {
                  widget.controller.reelData.value.likes = (widget.controller.reelData.value.likes ?? 0) - 1;
                }
                widget.controller.update();
                setState(() {});
              },
              formatCount: (val) {
                return widget.controller.reelData.value.likes?.toString() ?? '0';
              },
            ),
            SizedBox(height: 20.h),

            // Comment button
            ActionButton(
              icon: Assets.icons.icComment,
              iconColor: AppColors.whiteFFFFFF,
              count: int.parse(widget.controller.reelData.value.comments?.toString() ?? '0'),
              onTap: () {
                // CommentsBottomSheet.show(reelId: '', commentsCount: 5);
              },
              formatCount: (val) {
                return widget.controller.reelData.value.comments?.toString() ?? '0';
              },
            ),
            SizedBox(height: 20.h),

            // Share button
            ActionButton(
              icon: Assets.icons.icShare,
              iconColor: AppColors.whiteFFFFFF,
              count: int.parse(widget.controller.reelData.value.shares?.toString() ?? '0'),
              onTap: () async {
                try {
                  // Create share text with video URL and caption
                  final shareText = widget.controller.reelData.value.description?.isNotEmpty ?? false
                      ? '${widget.controller.reelData.value.description}\n\n${widget.controller.reelData.value.video}'
                      : widget.controller.reelData.value.video;

                  // Share the video URL
                  await Share.share(
                    shareText ?? "",
                    subject: 'Check out this reel by ${widget.controller.reelData.value.userId}',
                  );
                } catch (e) {
                  debugPrint('❌ Error sharing reel: $e');
                }
              },
              formatCount: (val) {
                return widget.controller.reelData.value.shares?.toString() ?? '0';
              },
            ),
            Gap(10.h),
            IconButton(
              key: widget.menuOptionKey,
              onPressed: widget.onTapMenu,
              icon: Icon(Icons.more_horiz, color: AppColors.white),
            ),
          ],
        ),
      ],
    );
  }
}
