import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/helper/like_helper.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/delete_confirmation_dialog.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/core/widgets/liked_by_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/report/view/report_bottom_sheet.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/models/post_list_response_model.dart';
import '../../../../core/services/network_quality_service.dart';
import '../../../../core/services/zeal_video_cache_service.dart';
import '../../../../core/utils/app_constant.dart';
import '../../dashboard/controller/dashboard_controller.dart';
import '../../home/widgets/share_bottom_sheet.dart';
import '../../report/controller/report_controller.dart';
import '../controller/zeals_controller.dart';
import '../widget/comments_bottom_sheet.dart';
import '../widget/zeals_shimmer.dart';
import '../widget/zeal_unfollow_sheet.dart';

class ZealsView extends StatefulWidget {
  const ZealsView({super.key});

  @override
  State<ZealsView> createState() => _ZealsViewState();
}

class _ZealsViewState extends State<ZealsView> with WidgetsBindingObserver {
  late PageController _pageController;
  final ZealsController _controller = Get.find<ZealsController>();

  //   final ZealsController _controller = Get.put(ZealsController());
  final DashboardController _dashboardController = Get.find<DashboardController>();
  final Map<int, VideoPlayerController?> _videoControllers = {};
  static const int _zealsTabIndex = 3; // ZealsView is at index 3 in IndexedStack
  bool _wasOnZealsTab = false;
  bool _initialPreloadDone = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasDisconnected = false;
  bool _isAppInForeground = true;
  bool _shouldResumeCurrentVideoOnForeground = false;
  Timer? _connectivityDebounce;
  static const _connectivityDebounceDuration = Duration(milliseconds: 1500);
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  Future<void> _onRefresh() => _controller.refreshZealsAsync(clearReelsFirst: false);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);

    // Check initial tab index - if not on Zeals tab, ensure videos are paused
    _wasOnZealsTab = _dashboardController.currentIndex.value == _zealsTabIndex;
    if (!_wasOnZealsTab) {
      // Not on Zeals tab initially, pause all videos
      Future.microtask(() => _pauseAllVideos());
    }

    // Listen to tab changes and pause/resume videos accordingly
    ever(_dashboardController.currentIndex, (index) {
      if (index != _zealsTabIndex) {
        _wasOnZealsTab = false;
        _pauseAllVideos();
      } else if (!_wasOnZealsTab) {
        _wasOnZealsTab = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncPageControllerToCurrentIndex();
          _resumeCurrentVideo();
        });
      }
    });

    // After feed fetch (e.g. shimmer → list), PageView can reattach at page 0 while currentIndex
    // still holds the old index — nothing looks "current" until the user scrolls. Resync when loading ends.
    ever(_controller.isLoading, (bool loading) {
      if (loading) return;
      if (_dashboardController.currentIndex.value != _zealsTabIndex) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncPageControllerToCurrentIndex();
        _resumeCurrentVideo();
      });
    });

    // Listen to global pause request (when navigating to other screens)
    ever(_controller.pauseVideosTrigger, (_) {
      if (_dashboardController.currentIndex.value == _zealsTabIndex) {
        _pauseAllVideos();
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final hasConnection =
          results.isNotEmpty &&
          results.any(
            (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.mobile || r == ConnectivityResult.ethernet,
          );
      if (hasConnection && _wasDisconnected) {
        _wasDisconnected = false;
        _connectivityDebounce?.cancel();
        _connectivityDebounce = Timer(_connectivityDebounceDuration, () {
          if (!mounted) return;
          if (!_isAppInForeground) return;
          if (_dashboardController.currentIndex.value != _zealsTabIndex) return;
          if (_controller.isLoading.value) return;
          _refreshKey.currentState?.show();
        });
      } else if (!hasConnection) {
        _wasDisconnected = true;
        _connectivityDebounce?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _connectivityDebounce?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _controller.disposeAllVideos();
    _pauseAllVideos();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isAppInForeground = false;
      final currentIndex = _controller.currentIndex.value;
      final currentController = _videoControllers[currentIndex];
      _shouldResumeCurrentVideoOnForeground =
          currentController != null &&
          currentController.value.isInitialized &&
          currentController.value.isPlaying;
      _pauseAllVideos();
    } else if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      if (_dashboardController.currentIndex.value == _zealsTabIndex &&
          _shouldResumeCurrentVideoOnForeground) {
        _resumeCurrentVideo();
      }
      _shouldResumeCurrentVideoOnForeground = false;
    }
  }

  void _pauseAllVideos() {
    for (var controller in _videoControllers.values) {
      if (controller != null && controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  /// Keeps [PageController] aligned with [ZealsController.currentIndex] after IndexedStack / rebuilds.
  void _syncPageControllerToCurrentIndex() {
    final reels = _controller.reelsData.value?.posts ?? [];
    if (reels.isEmpty) return;
    if (!_pageController.hasClients) return;
    final target = _controller.currentIndex.value.clamp(0, reels.length - 1);
    final current = _pageController.page?.round() ?? 0;
    if (current != target) {
      _pageController.jumpToPage(target);
    }
  }

  void _resumeCurrentVideo() {
    final currentIndex = _controller.currentIndex.value;
    final controller = _videoControllers[currentIndex];
    if (controller != null &&
        controller.value.isInitialized &&
        !controller.value.isPlaying &&
        _dashboardController.currentIndex.value == _zealsTabIndex) {
      // Small delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted &&
            _dashboardController.currentIndex.value == _zealsTabIndex &&
            controller.value.isInitialized &&
            !controller.value.isPlaying) {
          controller.play();
        }
      });
    }
  }

  void _registerVideoController(int index, VideoPlayerController? controller) {
    if (controller == null) {
      _videoControllers.remove(index);
    } else {
      _videoControllers[index] = controller;
      _pruneDistantControllers(index);
    }
  }

  void _pruneDistantControllers(int currentIdx) {
    final toRemove = <int>[];
    for (final entry in _videoControllers.entries) {
      if ((entry.key - currentIdx).abs() > 1) {
        toRemove.add(entry.key);
      }
    }
    for (final i in toRemove) {
      _videoControllers.remove(i);
    }
  }

  Future<void> _performZealDeleteAndRemove(BuildContext context, PostData post) async {
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
        _controller.removeReelById(contentId);
      },
      onError: (AppException e) {
        AppFunctions().showToast(e.message, bgColor: AppColors.red);
      },
    );
  }

  void _preloadNextVideos(int currentIndex) {
    try {
      final cache = Get.find<ZealVideoCacheService>();
      final network = Get.find<NetworkQualityService>();
      final reels = _controller.reelsData.value?.posts ?? [];
      final count = network.preloadCount;
      if (count >= 1 && currentIndex + 1 < reels.length) {
        final url = network.getPreferredMediaUrl(reels[currentIndex + 1]);
        cache.preloadVideo(url);
      }
      if (count >= 2 && currentIndex + 2 < reels.length) {
        final url = network.getPreferredMediaUrl(reels[currentIndex + 2]);
        cache.preloadVideo(url);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black000000,
      extendBodyBehindAppBar: true,
      body: Obx(() {
        final reels = _controller.reelsData.value?.posts ?? [];
        if (reels.isEmpty && _controller.isLoading.value) {
          return RefreshIndicator(
            key: _refreshKey,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false, // ✅ fill full screen
                  child: const ZealsShimmer(),
                ),
              ],
            ),
          );
        }

        if (reels.isEmpty) {
          return RefreshIndicator(
            key: _refreshKey,
            onRefresh: _onRefresh,
            color: AppColors.primaryColor,
            child: SingleChildScrollView(
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                child: const Center(
                  child: Text('No zeals available', style: TextStyle(color: AppColors.whiteFFFFFF)),
                ),
              ),
            ),
          );
        }

        if (!_initialPreloadDone && reels.isNotEmpty) {
          _initialPreloadDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final net = Get.find<NetworkQualityService>();
            final firstUrl = reels.first.mediaUrl;
            net.updateQuality(speedTestUrl: firstUrl);
            _preloadNextVideos(_controller.currentIndex.value);
          });
        }

        return RefreshIndicator(
          key: _refreshKey,
          onRefresh: _onRefresh,
          color: AppColors.primaryColor,
          child: SizedBox.expand(
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: reels.length,
              onPageChanged: (index) {
                _controller.onPageChanged(index);
                _pruneDistantControllers(index);
                _preloadNextVideos(index);
                if (index >= reels.length - 2) {
                  _controller.loadMore();
                }
              },
              itemBuilder: (context, index) {
                return Obx(() {
                  final currentIdx = _controller.currentIndex.value;
                  final isWithinRange = (index - currentIdx).abs() <= 1;
                  final post = reels[index];
                  final isCurrentUserReel = post.userId?.id == PrefService.getString(PrefKeys.userId);
                  return _ReelItem(
                    key: ValueKey('reel_${post.id ?? index}'),
                    post: post,
                    index: index,
                    isCurrentPage: index == currentIdx,
                    isWithinRange: isWithinRange,
                    onControllerCreated: (controller) => _registerVideoController(index, controller),
                    onReport: () async {
                      Get.find<ReportController>().reset();
                      Get.find<ReportController>().getReportsCategories(context);
                      final success = await ReportBottomSheet.show(
                        postId: post.id ?? '',
                        postType: post.contentType ?? 'Post',
                      );
                      if (success == true) _controller.removeReelById(post.id ?? '');
                    },
                    showDelete: isCurrentUserReel,
                    onDelete: isCurrentUserReel ? () => _performZealDeleteAndRemove(context, post) : null,
                    isSave: post.isSaved ?? false,
                    onSave: () {
                      _controller.saveUnSavePost(context, post);
                      _controller.reelsData.refresh();
                    },
                  );
                });
              },
            ),
          ),
        );
      }),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final PostData post;
  final int index;
  final bool isCurrentPage;
  final bool isWithinRange;
  final Function(VideoPlayerController?)? onControllerCreated;
  final void Function() onReport;
  final bool showDelete;
  final VoidCallback? onDelete;
  final bool isSave;
  final VoidCallback onSave;

  const _ReelItem({
    super.key,
    required this.post,
    required this.index,
    this.isCurrentPage = false,
    this.isWithinRange = true,
    this.onControllerCreated,
    required this.onReport,
    this.showDelete = false,
    this.onDelete,
    this.isSave = false,
    required this.onSave,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  bool _hasStartedPlaying = false;
  bool _isLiked = false;
  bool _isVisible = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _disposedToSaveMemory = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;
  late Animation<double> _likeOpacityAnimation;
  final ValueNotifier<bool> _showHeartNotifier = ValueNotifier<bool>(false);
  final GlobalKey _moreOptionsKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late AnimationController _menuAnimationController;
  late Animation<double> _menuScaleAnimation;
  late Animation<double> _menuOpacityAnimation;

  /// Keep only current ±1 pages alive to avoid OOM when scrolling many videos.
  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked ?? false;
    _isVisible = widget.isCurrentPage;
    if (widget.isWithinRange) {
      _initializeVideo();
    } else {
      _disposedToSaveMemory = true;
    }

    // Like animation (same as CommonPostDetailWidget: quick pop-in, slight bounce, fade out)
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
  void didUpdateWidget(_ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWithinRange != oldWidget.isWithinRange) {
      if (widget.isWithinRange) {
        _disposedToSaveMemory = false;
        _initializeVideo();
      } else {
        _disposeVideoToSaveMemory();
      }
    }
    if (widget.isCurrentPage != oldWidget.isCurrentPage) {
      if (widget.isCurrentPage) {
        _isVisible = true;
        _playVideo();
      } else {
        _isVisible = false;
        _pauseVideo();
      }
    }
  }

  @override
  void deactivate() {
    // Pause video when widget is deactivated (e.g., when navigating away)
    _pauseVideo();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (widget.isCurrentPage && _videoController != null && _videoController!.value.isInitialized) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && widget.isCurrentPage && _videoController != null && !_videoController!.value.isPlaying) {
          _playVideo();
        }
      });
    }
  }

  void _disposeVideoToSaveMemory() {
    if (_videoController == null) return;
    _videoController!.removeListener(_videoErrorListener);
    widget.onControllerCreated?.call(null);
    _videoController!.dispose();
    _videoController = null;
    _disposedToSaveMemory = true;
    _hasError = false;
    _errorMessage = null;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _closeMenu();
    if (_videoController != null) {
      _videoController!.removeListener(_videoErrorListener);
      widget.onControllerCreated?.call(null);
      _videoController!.dispose();
      _videoController = null;
    }
    _showHeartNotifier.dispose();
    _likeAnimationController.dispose();
    _menuAnimationController.dispose();
    super.dispose();
  }

  void _showMenu() {
    if (_overlayEntry != null) return;

    final RenderBox? renderBox = _moreOptionsKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => PopupReelMenuOverlay(
        position: position,
        size: size,
        scaleAnimation: _menuScaleAnimation,
        opacityAnimation: _menuOpacityAnimation,
        showDelete: widget.showDelete,
        onReport: () {
          _closeMenu();
          widget.onReport();
        },
        onDelete: () {
          _closeMenu();
          widget.onDelete?.call();
        },
        onDismiss: _closeMenu,
        isSave: widget.isSave,
        onSave: () {
          _closeMenu();
          widget.onSave.call();
        },
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

  void _onDoubleTap(TapDownDetails details) {
    // Instant UI update: like state and count (no wait for API)
    if (!_isLiked) {
      setState(() {
        _isLiked = true;
        widget.post.likeCount = (widget.post.likeCount ?? 0) + 1;
      });
      LikeHelper.toggleLike(
        contentId: widget.post.id ?? '',
        contentType: widget.post.contentType ?? 'Post',
        isLiked: widget.post.isLiked ?? false,
        likeCount: widget.post.likeCount ?? 0,
        onLocalUpdate: (liked, count) {},
      );
    }

    // Show heart animation (ValueNotifier avoids rebuilding entire reel)
    _showHeartNotifier.value = true;
    _likeAnimationController.forward().then((_) {
      if (mounted) {
        _showHeartNotifier.value = false;
        _likeAnimationController.reset();
      }
    });
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        // unlike
        _isLiked = false;
        widget.post.likeCount = ((widget.post.likeCount ?? 1) - 1).clamp(0, 999999999);
      } else {
        // like
        _isLiked = true;
        widget.post.likeCount = (widget.post.likeCount ?? 0) + 1;
      }
    });

    LikeHelper.toggleLike(
      contentId: widget.post.id ?? '',
      contentType: widget.post.contentType ?? 'Post',
      isLiked: widget.post.isLiked ?? false,
      likeCount: widget.post.likeCount ?? 0,
      onLocalUpdate: (liked, count) {
        //   widget.post.isLiked = liked;
        //   widget.post.likeCount = count;
      },
    );
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  void _pauseVideo() {
    if (_videoController == null) return;
    if (_videoController!.value.isInitialized && _videoController!.value.isPlaying) {
      _videoController!.pause();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _initializeVideo() {
    if (_videoController != null) return;
    final network = Get.find<NetworkQualityService>();
    final url = network.getPreferredMediaUrl(widget.post) ?? widget.post.mediaUrl ?? '';
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
      cache
          .getCachedPath(url)
          .then((cachedPath) {
            if (!mounted || _videoController != null) return;
            final VideoPlayerController controller;
            if (cachedPath != null && cachedPath.isNotEmpty && File(cachedPath).existsSync()) {
              controller = VideoPlayerController.file(File(cachedPath));
            } else {
              controller = VideoPlayerController.networkUrl(Uri.parse(url));
              cache.preloadVideo(url);
            }
            _videoController = controller;
            widget.onControllerCreated?.call(controller);

            final initializeFuture = controller.initialize().timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('Video loading timeout after 15 seconds');
              },
            );

            initializeFuture
                .then((_) {
                  if (mounted && _videoController == controller) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted && _videoController == controller && controller.value.isInitialized) {
                        final dashboardController = Get.find<DashboardController>();
                        final isOnZealsTab = dashboardController.currentIndex.value == 3;

                        setState(() {
                          _hasError = false;
                          controller.setLooping(true);
                          if (_isVisible && isOnZealsTab) {
                            try {
                              controller.play();
                              _hasStartedPlaying = true;
                            } catch (e) {
                              setState(() {
                                _hasError = true;
                                _errorMessage = 'Failed to play video: $e';
                              });
                            }
                          }
                        });
                      }
                    });
                  }
                })
                .catchError((error) {
                  if (mounted && _videoController == controller) {
                    setState(() {
                      _hasError = true;
                      if (error is TimeoutException) {
                        _errorMessage = 'Video loading timeout. Please check your connection.';
                      } else if (error.toString().contains('MediaCodec') || error.toString().contains('Decoder')) {
                        _errorMessage = 'Video codec error. This video may not be supported on your device.';
                      } else {
                        _errorMessage = 'Failed to load video: ${error.toString()}';
                      }
                    });
                  }
                });

            controller.addListener(_videoErrorListener);
          })
          .catchError((e) {
            if (mounted && _videoController == null) {
              _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
              widget.onControllerCreated?.call(_videoController);
              _attachControllerInitAndListen(_videoController!);
            }
          });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error initializing video: $e';
        });
      }
    }
  }

  void _attachControllerInitAndListen(VideoPlayerController controller) {
    final initializeFuture = controller.initialize().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException('Video loading timeout after 15 seconds');
      },
    );

    initializeFuture
        .then((_) {
          if (mounted && _videoController == controller) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _videoController == controller && controller.value.isInitialized) {
                final dashboardController = Get.find<DashboardController>();
                final isOnZealsTab = dashboardController.currentIndex.value == 3;

                setState(() {
                  _hasError = false;
                  controller.setLooping(true);
                  if (_isVisible && isOnZealsTab) {
                    try {
                      controller.play();
                      _hasStartedPlaying = true;
                    } catch (e) {
                      setState(() {
                        _hasError = true;
                        _errorMessage = 'Failed to play video: $e';
                      });
                    }
                  }
                });
              }
            });
          }
        })
        .catchError((error) {
          if (mounted && _videoController == controller) {
            setState(() {
              _hasError = true;
              if (error is TimeoutException) {
                _errorMessage = 'Video loading timeout. Please check your connection.';
              } else if (error.toString().contains('MediaCodec') || error.toString().contains('Decoder')) {
                _errorMessage = 'Video codec error. This video may not be supported on your device.';
              } else {
                _errorMessage = 'Failed to load video: ${error.toString()}';
              }
            });
          }
        });

    controller.addListener(_videoErrorListener);
  }

  void _playVideo() {
    if (_videoController == null) return;
    final dashboardController = Get.find<DashboardController>();
    final isOnZealsTab = dashboardController.currentIndex.value == 3;

    if (_videoController!.value.isInitialized && !_videoController!.value.isPlaying && _isVisible && isOnZealsTab) {
      try {
        _videoController!.play();
        if (mounted) {
          setState(() {
            _hasStartedPlaying = true;
            _hasError = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Failed to play video: $e';
          });
        }
      }
    }
  }

  void _videoErrorListener() {
    if (_videoController == null) return;
    if (_videoController!.value.hasError && mounted) {
      final errorDesc = _videoController!.value.errorDescription ?? '';
      setState(() {
        _hasError = true;
        if (errorDesc.contains('MediaCodec') || errorDesc.contains('Decoder') || errorDesc.contains('codec')) {
          _errorMessage = 'Video codec error. This video format may not be supported on your device.';
        } else {
          _errorMessage = errorDesc.isNotEmpty ? errorDesc : 'Video playback error';
        }
      });
    }
  }

  void _retryVideo() {
    if (mounted) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
      if (_videoController != null) {
        _videoController!.removeListener(_videoErrorListener);
        widget.onControllerCreated?.call(null);
        _videoController!.dispose();
        _videoController = null;
      }
      _initializeVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_disposedToSaveMemory || _videoController == null) {
      return const ZealsShimmer();
    }

    if (!_videoController!.value.isInitialized) {
      return const ZealsShimmer();
    }

    if (_hasError || _videoController!.value.hasError) {
      return Container(
        color: AppColors.black000000,
        child: Center(
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _retryVideo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.whiteFFFFFF,
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      ),
                      child: Text('Retry', style: TextStyles.medium(14.sp, fontColor: AppColors.whiteFFFFFF)),
                    ),
                    SizedBox(width: 12.w),
                    OutlinedButton(
                      onPressed: () {
                        // Skip to next video - handled by PageView
                        // This will be handled by swiping or the parent can implement skip logic
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.whiteFFFFFF),
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      ),
                      child: Text('Skip', style: TextStyles.medium(14.sp, fontColor: AppColors.whiteFFFFFF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _videoController!;
    final videoAspectRatio = controller.value.aspectRatio;
    final isVideoVertical = videoAspectRatio < 1.0;

    return GestureDetector(
      onDoubleTapDown: _onDoubleTap,
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

          // Gradient overlay at bottom
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

          // Heart animation overlay: quick pop-in, slight bounce, fade out (same as CommonPostDetailWidget)
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

          // Right side action buttons
          Positioned(
            right: 12.w,
            bottom: 10.h,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Like button
                ActionButton(
                  heroTag: 'like_hero_${widget.post.id}',
                  icon: _isLiked ? Assets.icons.icLike : Assets.icons.icLikeBorder,
                  iconColor: _isLiked ? null : AppColors.white,
                  count: widget.post.likeCount ?? 0,
                  onTap: _toggleLike,
                  onCountTap: () {
                    LikedByBottomSheet.show(
                      context: context,
                      contentId: widget.post.id ?? '',
                      contentType: widget.post.contentType ?? 'Zeal Post',
                    );
                  },
                  formatCount: formatCount,
                ),
                SizedBox(height: 20.h),

                // Comment button
                ActionButton(
                  icon: Assets.icons.icComment,
                  iconColor: AppColors.whiteFFFFFF,
                  count: widget.post.commentCount ?? 0,
                  onTap: () {
                    CommentsBottomSheet.show(
                      contentType: 'Zeal Post',
                      postId: widget.post.id ?? "",
                      commentsCount: widget.post.commentCount ?? 0,
                      onCommentAdded: (newCount) {
                        widget.post.commentCount = newCount;
                        setState(() {});
                      },
                    );
                  },
                  formatCount: formatCount,
                ),
                SizedBox(height: 20.h),

                // Share button
                ActionButton(
                  icon: Assets.icons.icShare,
                  iconColor: AppColors.whiteFFFFFF,
                  count: widget.post.shareCount ?? 0,
                  onTap: () {
                    ShareBottomSheet.show(
                      postId: widget.post.id,
                      postType: widget.post.contentType,
                      shareUrl: widget.post.shareableLink,
                      onShared: (count) {
                        widget.post.shareCount = count;
                        setState(() {});
                      },
                    );
                  },
                  formatCount: formatCount,
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

          // Bottom user info and caption
          Positioned(
            left: 12.w,
            bottom: 20.h,
            right: 80.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Username — tap profile image or name to open user profile
                GestureDetector(
                  onTap: () {
                    final userId = widget.post.userId?.id;
                    if (userId != null && userId.isNotEmpty) {
                      Get.toNamed(AppRoutes.otherUserProfile, arguments: userId);
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 35.w,
                        height: 35.w,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: CommonProfileImage(
                          imageUrl: widget.post.userId?.profileImage?.toString(),
                          width: 35.w,
                          height: 35.w,
                        ),
                      ),
                      Gap(12.w),
                      Flexible(
                        child: Text(
                          widget.post.userId?.name ?? "User Name",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF),
                        ),
                      ),
                      Gap(5.w),
                      if (widget.post.userId?.isVerifiedBadge == true) ...[
                        Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                        Gap(5.w),
                      ],
                      if (widget.post.isFollowing != null) ...[
                        Container(
                          height: 6,
                          width: 6,
                          decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                        ),
                        _ZealFollowButton(post: widget.post),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 8.h),

                // Caption with @mentions highlighted and tappable
                if (widget.post.caption?.isNotEmpty ?? false)
                  _ExpandableCaption(
                    text: widget.post.caption ?? "",
                    mentionedUsers: widget.post.mentionedUsers,
                    fontSize: 14.sp,
                  ),
                SizedBox(height: 8.h),
              ],
            ),
          ),

          if (controller.value.isInitialized &&
              !controller.value.isPlaying &&
              !_hasError &&
              _isVisible &&
              _hasStartedPlaying)
            Center(
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(color: AppColors.black000000.withValues(alpha: 0.5), shape: BoxShape.circle),
                child: Icon(Icons.play_arrow, color: AppColors.whiteFFFFFF, size: 40.sp),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandableCaption extends StatefulWidget {
  final String text;
  final List<UserId>? mentionedUsers;
  final double fontSize;

  const _ExpandableCaption({required this.text, this.mentionedUsers, required this.fontSize});

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
              ..onTap = () => Get.toNamed(AppRoutes.otherUserProfile, arguments: matchedUser!.id),
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

/// Follow/Following button for zeal reel. Shown only when [post.isFollowing] is not null.
class _ZealFollowButton extends StatelessWidget {
  const _ZealFollowButton({required this.post});

  final PostData post;

  @override
  Widget build(BuildContext context) {
    final userId = post.userId?.id;
    final currentUserId = PrefService.getString(PrefKeys.userId);
    if (userId == null || userId.isEmpty || userId == currentUserId) {
      return const SizedBox.shrink();
    }
    final following = post.isFollowing == true;
    final controller = Get.find<ZealsController>();
    return TextButton(
      onPressed: () {
        if (following) {
          ZealUnfollowSheet.show(controller: controller, userId: userId);
        } else {
          controller.followUser(userId, onError: (msg) => AppFunctions().showToast(msg, bgColor: AppColors.red));
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
        style: TextStyles.semiBold(12.sp, fontColor: following ? AppColors.whiteFFFFFF : AppColors.whiteFFFFFF),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final SvgGenImage icon;
  final Color? iconColor;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onCountTap;
  final String Function(int) formatCount;
  final String? heroTag;

  const ActionButton({
    super.key,
    this.heroTag,
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.onTap,
    this.onCountTap,
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
            width: 28.sp,
            height: 28.sp,
            child: heroTag != null
                ? Hero(
                    tag: heroTag!,
                    child: iconColor == null
                        ? icon.svg(height: 28.sp, width: 28.sp)
                        : icon.svg(
                            height: 28.sp,
                            width: 28.sp,
                            colorFilter: ColorFilter.mode(iconColor ?? AppColors.white, BlendMode.srcIn),
                          ),
                  )
                : (iconColor == null
                      ? icon.svg(height: 28.sp, width: 28.sp)
                      : icon.svg(
                          height: 28.sp,
                          width: 28.sp,
                          colorFilter: ColorFilter.mode(iconColor ?? AppColors.white, BlendMode.srcIn),
                        )),
          ),
          SizedBox(height: 4.h),
          PressScaleButton(
            onTap: onCountTap ?? onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(formatCount(count), style: TextStyles.regular(12.sp, fontColor: AppColors.whiteFFFFFF)),
            ),
          ),
        ],
      ),
    );
  }
}

// Reel Model
class ReelModel {
  final String id;
  final String videoUrl;
  final String username;
  final String? userProfileImage;
  final String caption;
  final String musicName;
  final bool isVerified;
  int likesCount;
  int commentsCount;
  int sharesCount;
  bool isLiked;
  bool isSaved;

  ReelModel({
    required this.id,
    required this.videoUrl,
    required this.username,
    this.userProfileImage,
    required this.caption,
    required this.musicName,
    this.isVerified = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.isSaved = false,
  });
}

class PopupReelMenuOverlay extends StatelessWidget {
  final Offset position;
  final Size size;
  final bool isSave;
  final VoidCallback onSave;
  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;
  final bool showDelete;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  const PopupReelMenuOverlay({
    super.key,
    required this.position,
    required this.size,
    required this.scaleAnimation,
    required this.opacityAnimation,
    this.showDelete = false,
    required this.onReport,
    required this.onDelete,
    required this.onDismiss,
    this.isSave = false,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final menuWidth = 200.w;
    final menuHeight = 120.h; // Approximate height of menu with 2 items

    // Calculate position - shift left from center and position lower
    final leftPosition = (position.dx + size.width / 2) - (menuWidth / 2) - 110.w;
    // Ensure menu doesn't go off screen
    final adjustedLeft = leftPosition.clamp(16.w, screenWidth - menuWidth - 16.w);

    // Calculate if menu should appear above or below the button
    final spaceBelow = screenHeight - (position.dy + size.height);
    final spaceAbove = position.dy - safeAreaTop;
    final showAbove = spaceBelow < menuHeight + 32.h && spaceAbove > spaceBelow;

    // Position menu with proper spacing - add more spacing to make it lower
    final topPosition = showAbove
        ? position.dy -
              menuHeight +
              50
                  .h // Above the button
        : position.dy + size.height + 20.h; // Below the button with more spacing (20.h instead of 8.h)

    // Ensure menu doesn't go above safe area
    final adjustedTop = topPosition.clamp(safeAreaTop + 8.h, screenHeight - safeAreaBottom - menuHeight - 8.h);

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
          top: adjustedTop,
          child: AnimatedBuilder(
            animation: Listenable.merge([scaleAnimation, opacityAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: scaleAnimation.value,
                alignment: showAbove ? Alignment.bottomCenter : Alignment.topCenter,
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
                          ),
                          if (!showDelete)
                            _MenuItem(
                              label: 'Report',
                              icon: Assets.icons.icReport.svg(width: 20.w, height: 20.h),
                              onTap: onReport,
                              isDestructive: false,
                            ),
                          if (showDelete)
                            _MenuItem(
                              label: 'Delete',
                              icon: Assets.icons.icDelete.svg(width: 20.w, height: 20.h),
                              onTap: onDelete,
                              isDestructive: true,
                            ),
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

  const _MenuItem({required this.label, required this.icon, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return Material(
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
                style: TextStyles.medium(16.sp, fontColor: isDestructive ? AppColors.redFF5353 : AppColors.black2F3039),
              ),
              const Spacer(),
              icon,
            ],
          ),
        ),
      ),
    );
  }
}
