import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/presentation/main/dashboard/controller/dashboard_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/models/post_model.dart';
import 'package:video_player/video_player.dart';

class ReelsScreenController extends GetxController {
  static const String tag = "REEL";
  PageController pageController = PageController();

  RxInt currentIndex = 0.obs;

  final RxBool isRefreshing = false.obs;

  // Video controllers map - stores controllers by index
  final Map<int, VideoPlayerController> _videoControllers = {};

  // Track which videos are initialized
  final Set<int> _initializedIndices = {};

  // Track which batch has been loaded
  int _lastLoadedIndex = -1;

  // Guard against concurrent initialization
  bool _isInitializing = false;
  Completer<void>? _initializationCompleter;

  // Preload configuration
  static const int _initialBatchSize = 10;
  static const int _nextBatchSize = 10;
  static const int _preloadThreshold = 7; // Load next batch when reaching this index

  // RxList<Post> reels = [
  //   Post(video: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4'),
  //   Post(
  //     video:
  //     'https://res.cloudinary.com/dzmghjqir/video/upload/v1767173608/20.11.2025_18.08.08_REC_niusuv.mp4',
  //   ),
  //   Post(
  //     video:
  //     'https://res.cloudinary.com/dzmghjqir/video/upload/v1767250915/Let_the_magic_of_the_season_cast_a_spell_reels_instagramreels_trendingreels_reelitfeelit_qcsudd.mp4',
  //   ),
  //   Post(
  //     video:
  //     'https://res.cloudinary.com/dzmghjqir/video/upload/v1767173603/20.11.2025_18.07.24_REC_bs32hy.mp4',
  //   ),
  //   Post(video: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  //   Post(video: 'https://res.cloudinary.com/dzmghjqir/video/upload/v1767172721/demo_video_ujlebb.mp4'),
  //
  //
  //   Post(video: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4'),
  //   Post(video: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4'),
  //   Post(
  //     video:
  //     'https://res.cloudinary.com/dzmghjqir/video/upload/v1767173603/20.11.2025_18.07.24_REC_bs32hy.mp4',
  //   ),
  //   Post(video: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  //   Post(video: 'https://res.cloudinary.com/dzmghjqir/video/upload/v1767172721/demo_video_ujlebb.mp4'),
  //
  //   Post(video: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  //   Post(video: 'https://res.cloudinary.com/dzmghjqir/video/upload/v1767172721/demo_video_ujlebb.mp4'),
  //
  //   Post(video: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4'),
  // ].obs;

  RxList<Post> reels = [
    Post(
      video:
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334664/2026_%E0%AA%A8%E0%AA%BE_%E0%AA%AA%E0%AA%B9%E0%AB%87%E0%AA%B2%E0%AA%BE_%E0%AA%A6%E0%AA%BF%E0%AA%B5%E0%AA%B8%E0%AB%87_%E0%AA%B8%E0%AB%81%E0%AA%B0%E0%AA%A4_%E0%AA%A8%E0%AB%80_%E0%AA%B9%E0%AA%B5%E0%AA%BE_%E0%AA%96%E0%AA%B0%E0%AA%BE%E0%AA%AC_.._surat_suratcity_surti_ptfpq6.mp4',
    ),
    Post(
      video:
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334664/Sound_on_for_those_ear_flaps_varunaditya_varunadityaphotography_reel_reels_nature_cute_hghu3m.mp4',
    ),
    Post(
      video:
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767250915/Let_the_magic_of_the_season_cast_a_spell_reels_instagramreels_trendingreels_reelitfeelit_qcsudd.mp4',
    ),
    Post(video: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),

    Post(video: 'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334665/get_gqlody.mp4'),
    Post(
      video:
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334666/Pull_the_mountain_%EF%B8%8F_%EF%B8%8F....._fyp_explore_influencer_mountain_travel_instadaily_instagram_v_trllar.mp4',
    ),
    Post(
      video:
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334665/AQMswOH-Khiti_yFCLXnQrMvfiJ8JXq4q2FFM0vzIgEgCgfooPgvrItgapTevdBi2BcUnMw0NELXvKyntMD4NwbS3kaykZrN_yzmoga.mp4',
    ),

    Post(
      video:
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334666/Spain_is_burning._Relentless_wildfires_under_heatwaves_above_40_C._Thousands_of_hectares_of_for_zea10f.mp4',
    ),
    Post(
      video:
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334667/In_first_frame-_White-bellied_minivet_2nd-_Baya_weaver_3rd-_Asian_paradise_flycatcher_reels_re_1_actdcc.mp4',
    ),
    Post(video: 'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334667/6646588-hd_1080_1920_30fps_mi2rp5.mp4'),

    Post(
      video:
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334667/Where_life_tastes_better_than_anything_Experience_hot_and_cold_good_and_bad_victory_and_loss_dfcxfp.mp4',
    ),
    Post(video: 'https://res.cloudinary.com/dzmghjqir/video/upload/v1767334678/7279832-uhd_2160_3840_24fps_nivv3x.mp4'),


  ].obs;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: currentIndex.value);
  }


  /// Initialize first batch of videos (10 videos)
  Future<void> initFirstPlayers() async {
    if (reels.isEmpty) return;
    
    // If already initializing, wait for it to complete
    if (_isInitializing) {
      if (_initializationCompleter != null) {
        return _initializationCompleter!.future;
      }
    }
    
    // Check if already initialized
    if (_initializedIndices.isNotEmpty && _initializedIndices.contains(0)) {
      debugPrint('✅ Videos already initialized, skipping');
      return;
    }
    
    _isInitializing = true;
    _initializationCompleter = Completer<void>();
    
    try {
      final endIndex = _initialBatchSize < reels.length ? _initialBatchSize : reels.length;
      await _initializeVideosBatch(0, endIndex);
      _initializationCompleter?.complete();
    } catch (e) {
      _initializationCompleter?.completeError(e);
      rethrow;
    } finally {
      _isInitializing = false;
      _initializationCompleter = null;
    }
  }

  /// Initialize a batch of videos
  Future<void> _initializeVideosBatch(int startIndex, int endIndex) async {
    if (startIndex >= reels.length) return;

    final actualEndIndex = endIndex < reels.length ? endIndex : reels.length;

    // Initialize all videos in the batch concurrently
    final futures = <Future<void>>[];

    for (int i = startIndex; i < actualEndIndex; i++) {
      if (!_initializedIndices.contains(i) && reels[i].video != null && reels[i].video!.isNotEmpty) {
        futures.add(_initializeVideoController(i));
      }
    }

    // Wait for all videos in the batch to initialize
    await Future.wait(futures);
    _lastLoadedIndex = actualEndIndex - 1;

    debugPrint('✅ Initialized videos from index $startIndex to ${actualEndIndex - 1}');
  }

  /// Initialize a single video controller
  Future<void> _initializeVideoController(int index, {int retryCount = 0}) async {
    if (_initializedIndices.contains(index)) return;
    if (index >= reels.length) return;

    final reel = reels[index];
    if (reel.video == null || reel.video!.isEmpty) return;

    try {
      final url = Uri.parse(reel.video!);
      final controller = VideoPlayerController.networkUrl(url);

      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Video loading timeout after 15 seconds');
        },
      );

      controller.setLooping(true);
      controller.setVolume(1.0);

      // Pause initially - will be played when it becomes the current page
      controller.pause();

      _videoControllers[index] = controller;
      _initializedIndices.add(index);

      debugPrint('✅ Video controller initialized for index $index');
    } catch (e) {
      debugPrint('❌ Error initializing video at index $index: $e');
      
      // Retry on MediaCodec/ExoPlayer errors (max 2 retries with delay)
      if (retryCount < 2 && 
          (e.toString().contains('MediaCodec') || 
           e.toString().contains('ExoPlaybackException') ||
           e.toString().contains('VideoError'))) {
        debugPrint('🔄 Retrying video initialization for index $index (attempt ${retryCount + 1})');
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        return _initializeVideoController(index, retryCount: retryCount + 1);
      }
      
      // Don't add to initialized indices if it failed after retries
    }
  }

  /// Get video controller for a specific index
  VideoPlayerController? getVideoController(int index) {
    return _videoControllers[index];
  }

  /// Check if video is initialized
  bool isVideoInitialized(int index) {
    return _initializedIndices.contains(index);
  }

  /// Handle page change
  Future<void> onPageChanged(int index) async {
    currentIndex.value = index;

    // Preload next batch when reaching threshold
    if (index >= _preloadThreshold && _lastLoadedIndex < index + 3) {
      final nextBatchStart = _lastLoadedIndex + 1;
      final nextBatchEnd = nextBatchStart + _nextBatchSize;

      if (nextBatchStart < reels.length) {
        // Load next batch in background
        _initializeVideosBatch(nextBatchStart, nextBatchEnd);
      }
    }

    // Play current video and pause others
    _playCurrentVideo(index);
  }

  /// Play current video and pause others
  void _playCurrentVideo(int currentIndex) {
    // Check if we're on the Zeals tab before playing
    final dashboardController = Get.find<DashboardController>();
    final isOnZealsTab = dashboardController.currentIndex.value == 3; // Zeals tab index
    
    if (!isOnZealsTab) {
      // Not on Zeals tab, pause all videos
      pauseAllVideos();
      return;
    }
    
    // Use a small delay to ensure state is stable
    Future.microtask(() {
      // Double-check tab state after microtask
      final dashboardController = Get.find<DashboardController>();
      final isOnZealsTab = dashboardController.currentIndex.value == 3;
      
      if (!isOnZealsTab) {
        pauseAllVideos();
        return;
      }
      
      for (var entry in _videoControllers.entries) {
        final controller = entry.value;
        if (controller.value.isInitialized && !controller.value.hasError) {
          if (entry.key == currentIndex) {
            // Play current video only if on Zeals tab
            if (!controller.value.isPlaying && isOnZealsTab) {
              try {
                controller.seekTo(Duration.zero);
                controller.play();
              } catch (e) {
                debugPrint('❌ Error playing video at index $currentIndex: $e');
              }
            }
          } else {
            // Pause other videos
            if (controller.value.isPlaying) {
              try {
                controller.pause();
              } catch (e) {
                debugPrint('❌ Error pausing video at index ${entry.key}: $e');
              }
            }
          }
        }
      }
    });
  }

  /// Pause all videos
  void pauseAllVideos() {
    for (var controller in _videoControllers.values) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  /// Resume current video
  void resumeCurrentVideo() {
    // Check if we're on the Zeals tab before resuming
    final dashboardController = Get.find<DashboardController>();
    final isOnZealsTab = dashboardController.currentIndex.value == 3; // Zeals tab index
    
    if (!isOnZealsTab) return;
    
    // Use a small delay to ensure state is stable
    Future.microtask(() {
      // Double-check tab state after microtask
      final dashboardController = Get.find<DashboardController>();
      final isOnZealsTab = dashboardController.currentIndex.value == 3;
      
      if (!isOnZealsTab) return;
      
      final index = currentIndex.value;
      final controller = _videoControllers[index];
      if (controller != null && 
          controller.value.isInitialized && 
          !controller.value.hasError &&
          !controller.value.isPlaying) {
        try {
          controller.play();
        } catch (e) {
          debugPrint('❌ Error resuming video at index $index: $e');
        }
      }
    });
  }

  bool isCurrentPageVisible = true;

  /// Handle refresh logic
  Future<void> handleRefresh(Future<void> Function()? onRefresh) async {
    if (isRefreshing.value) return;
    isRefreshing.value = true;

    await Future.delayed(const Duration(milliseconds: 100));
    await onRefresh?.call();
    await Future.delayed(const Duration(milliseconds: 200));

    if (reels.isNotEmpty) {
      currentIndex.value = 0;
      pageController.jumpToPage(0);
    }

    isRefreshing.value = false;
    update();
  }

  @override
  void onClose() {
    // Dispose all video controllers
    pauseAllVideos();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _initializedIndices.clear();

    pageController.dispose();
    super.onClose();
  }

  // void onReportTap() {
  //   Get.bottomSheet(
  //     ReportSheet(reportType: ReportType.post, id: reels[currentIndex.value].id?.toInt()),
  //     isScrollControlled: true,
  //   );
  // }
  //
  // void onUpdateComment(Comment comment, bool isReplyComment) {
  //   final post = reels.firstWhereOrNull((e) => e.id == comment.postId);
  //   if (post == null) {
  //     return Loggers.error('Post not found');
  //   }
  //   final controllerTag = post.id.toString();
  //   if (Get.isRegistered<ReelController>(tag: controllerTag)) {
  //     Get.find<ReelController>(tag: controllerTag).reelData.update((val) => val?.updateCommentCount(1));
  //   }
  // }
  //
  // void openPostOptionsSheet() {
  //   const tag = ProfileScreenController.tag;
  //
  //   final controller = Get.isRegistered<ProfileScreenController>(tag: tag)
  //       ? Get.find<ProfileScreenController>(tag: tag)
  //       : Get.put(ProfileScreenController(SessionManager.instance.getUser().obs, (user) {}), tag: tag);
  //
  //   Get.bottomSheet(
  //     PostOptionsSheet(
  //       controller: controller,
  //       onChanged: (type) {
  //         if (type == PublishType.goLive) {
  //           Future.delayed(const Duration(seconds: 1), () {
  //             final controller = Get.find<DashboardScreenController>();
  //             controller.onChanged(2);
  //           });
  //         }
  //       },
  //     ),
  //     isScrollControlled: true,
  //   );
  // }

  onUpdateReelData(Post reel) {
    final index = reels.indexWhere((element) => element.id == reel.id);
    if (index != -1) {
      reels[index] = reel;
      update();
    }
  }
}
