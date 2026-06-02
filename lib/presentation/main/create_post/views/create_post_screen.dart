import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/presentation/main/create_post/controller/create_post_controller.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/insta_image_picker_helper.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/music_waves.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/poll_duration_picker.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/post_write_tab.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/video_preview_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/post/widgets/search_music_bottomsheet.dart';
import '../../myprofile/controller/my_profile_controller.dart';
import '../widgets/permission_denied_dialog.dart';

// Helper function to store music info based on URL
void _storeMusicInfoByUrl(CreatePostController controller, String audioUrl) {
  // Match URL to get track info - this is a temporary solution
  // Ideally, SearchMusicBottomSheet should pass the full MusicTrack object
  final musicTracks = [

    {
      'url':
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767591749/song-of-little-ducks-113996_piie08.mp3',
      'title': "Say You Won's Let Go",
      'artist': 'Vishal shaker',
      'albumArt': 'https://i.pravatar.cc/150?img=12',
    },
    {
      'url':
          'https://res.cloudinary.com/dzmghjqir/video/upload/v1767611027/Let_the_magic_of_the_season_cast_a_spell_reels_instagramreels_trendingreels_reelitfeelit_sa2vav.mp3',
      'title': 'Music ok please.......',
      'artist': 'rahat ji',
      'albumArt': 'https://i.pravatar.cc/150?img=13',
    },
  ];

  final track = musicTracks.firstWhere(
    (t) => t['url'] == audioUrl,
    orElse: () => {
      'title': 'Unknown Track',
      'artist': 'Unknown Artist',
      'albumArt': 'https://i.pravatar.cc/150?img=12',
    },
  );

  controller.musicTitle = track['title'];
  controller.musicArtist = track['artist'];
  controller.musicAlbumArtUrl = track['albumArt'];
}

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CreatePostController controller = Get.find<CreatePostController>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.resetZealSessionForCreatePostEntry();
      await controller.ensureCreatePostReady();
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.black, // or any color
        statusBarIconBrightness: Brightness.light, // Android
        statusBarBrightness: Brightness.dark, // iOS
      ),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) {
            controller.disposeCamera();
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: buildBottomTabs(controller),
          backgroundColor: AppColors.black000000,
          body: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  Expanded(
                    child: Obx(
                      () => ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20.r),
                          bottomRight: Radius.circular(20.r),
                        ),
                        child: _buildTabContent(context, controller),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTopBar(CreatePostController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              controller.disposeCamera();
              Get.back();
            },
            child: SizedBox(
              width: 32.w,
              height: 32.w,

              child: Icon(
                Icons.close,
                color: AppColors.whiteFFFFFF,
                size: 25.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    CreatePostController controller,
  ) {
    switch (controller.selectedTabIndex.value) {
      case 0: // Write
        return PostWriteScreen();
      case 1: // Post
        return _buildPostTab(context, controller);
      case 2: // Zeal
        return _buildZealTab(controller);
      case 3: // Poll
        return _buildPollTab(controller);
      default:
        return _buildPostTab(context, controller);
    }
  }

  Widget _buildWriteTab() {
    return Center(
      child: Text(
        'Write',
        style: TextStyles.medium(24.sp, fontColor: AppColors.whiteFFFFFF),
      ),
    );
  }

  Widget _buildPostTab(BuildContext context, CreatePostController controller) {
    return Stack(
      children: [
        // Camera preview
        Obx(() {
          if (!controller.isCameraInitialized.value ||
              controller.cameraController == null) {
            return Container(
              color: AppColors.black000000,
              child: Center(
                child: controller.isCameraInitialized.value
                    ? Text(
                        'Camera not available',
                        style: TextStyles.medium(
                          16.sp,
                          fontColor: AppColors.whiteFFFFFF,
                        ),
                      )
                    : (!controller.isCameraPermissionDialog.value)
                    ? CircularProgressIndicator(color: AppColors.whiteFFFFFF)
                    : !controller.isCameraPermissionGranted.value
                    ? PermissionDeniedDialog(deniedPermission: "Camera")
                    : CircularProgressIndicator(color: AppColors.whiteFFFFFF),
              ),
            );
          }

          // Double check that controller is initialized before using it
          final cameraController = controller.cameraController;
          if (cameraController == null ||
              !controller.isCameraInitialized.value) {
            return Container(
              color: AppColors.black000000,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.whiteFFFFFF),
              ),
            );
          }

          try {
            return SizedBox.expand(
              // Ensures it takes the full screen
              child: FittedBox(
                fit: BoxFit.cover,
                // Crops the edges to fill the screen perfectly
                child: SizedBox(
                  // Use the controller's preview size to maintain aspect ratio
                  height: cameraController.value.previewSize?.width ?? 1.0,
                  child: CameraPreview(cameraController),
                ),
              ),
            );
          } catch (e) {
            print('Error building camera preview: $e');
            return Container(
              color: AppColors.black000000,
              child: Center(
                child: Text(
                  'Camera error',
                  style: TextStyles.medium(
                    16.sp,
                    fontColor: AppColors.whiteFFFFFF,
                  ),
                ),
              ),
            );
          }
        }),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomControls(context, controller),
        ),
        Positioned(top: 30.h, left: 0, child: buildTopBar(controller)),
      ],
    );
  }

  Widget _buildZealTab(CreatePostController controller) {
    return Stack(
      children: [
        // Camera preview
        Obx(() {
          if (!controller.isCameraInitialized.value ||
              controller.cameraController == null) {
            return Container(
              color: AppColors.black000000,
              child: Center(
                child: controller.isCameraInitialized.value
                    ? Text(
                        'Camera not available',
                        style: TextStyles.medium(
                          16.sp,
                          fontColor: AppColors.whiteFFFFFF,
                        ),
                      )
                    : (!controller.isCameraPermissionDialog.value)
                    ? CircularProgressIndicator(color: AppColors.whiteFFFFFF)
                    : !controller.isCameraPermissionGranted.value
                    ? PermissionDeniedDialog(
                        deniedPermission: "Camera and Microphone",
                      )
                    : CircularProgressIndicator(color: AppColors.whiteFFFFFF),
              ),
            );
          }

          // Double check that controller is initialized before using it
          final cameraController = controller.cameraController;
          if (cameraController == null ||
              !controller.isCameraInitialized.value) {
            return Container(
              color: AppColors.black000000,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.black2F3039),
              ),
            );
          }

          try {
            return SizedBox.expand(
              // Ensures it takes the full screen
              child: FittedBox(
                fit: BoxFit.cover,
                // Crops the edges to fill the screen perfectly
                child: SizedBox(
                  // Use the controller's preview size to maintain aspect ratio
                  height: cameraController.value.previewSize?.height ?? 1.0,
                  child: CameraPreview(cameraController),
                ),
              ),
            );
          } catch (e) {
            print('Error building camera preview: $e');
            return Container(
              color: AppColors.black000000,
              child: Center(
                child: Text(
                  'Camera error',
                  style: TextStyles.medium(
                    16.sp,
                    fontColor: AppColors.whiteFFFFFF,
                  ),
                ),
              ),
            );
          }
        }),

        // Recording indicator
        Obx(() {
          if (controller.isRecording.value) {
            return Positioned(
              top: controller.confirmedMusic != null ? 90.h : 50.h,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: AppColors.redFF5353,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Gap(8.w),
                    Text(
                      controller.getRecordingDurationText(),
                      style: TextStyles.medium(
                        16.sp,
                        fontColor: AppColors.whiteFFFFFF,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }),

        // Obx(() {
        //   return controller.isMusicShowInZeal.value
        //       ? Positioned(
        //           bottom: 110.h,
        //           left: 0,
        //           right: 0,
        //           child: audioSetWidget(),
        //         )
        //       : SizedBox();
        // }),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildZealBottomControls(controller),
        ),

        GetBuilder<CreatePostController>(
          builder: (controller) {
            return Positioned(
              top: 5,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 40.h),
                child: _buildZealTopAppBar(controller),
              ),
            );
          },
        ),

        // Positioned(
        //   top: 50,
        //   left: 80,
        //   child: GetBuilder<CreatePostController>(
        //     builder: (controller) {
        //       return controller.confirmedMusic != null
        //           ? Row(
        //               mainAxisSize: MainAxisSize.min,
        //               mainAxisAlignment: MainAxisAlignment.center,
        //               children: [
        //                 Text(
        //                   controller.musicTitle ?? 'Unknown Track',
        //                   style: TextStyles.medium(14.sp, fontColor: AppColors.whiteFFFFFF),
        //                   maxLines: 1,
        //                   overflow: TextOverflow.ellipsis,
        //                 ),
        //
        //                 Gap(8.w),
        //                 // Clear music button
        //                 GestureDetector(
        //                   onTap: () {
        //                     controller.clearConfirmedMusic();
        //                     controller.isMusicShowInZeal.value = false;
        //                     controller.selectedMusic = null;
        //                     controller.update();
        //                   },
        //                   child: Icon(Icons.close, color: AppColors.whiteFFFFFF, size: 20.sp),
        //                 ),
        //               ],
        //             )
        //           : SizedBox();
        //     },
        //   ),
        // ),
      ],
    );
  }

  /// Zeal top bar: [Close] | [Expanded + Center: music chip] | [trailing slot].
  /// Equal-width left/right slots keep the middle section visually centered on screen.
  Widget _buildZealTopAppBar(CreatePostController controller) {
    final hasMusic =
        controller.confirmedMusic != null || controller.selectedMusic != null;
    final sideSlotW = 80.w;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: sideSlotW,
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                controller.disposeCamera();
                Get.back();
              },
              child: SizedBox(
                width: 32.w,
                height: 32.w,
                child: Icon(
                  Icons.close,
                  color: AppColors.whiteFFFFFF,
                  size: 25.sp,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: hasMusic
                ? Center(
                    key: const ValueKey('zeal_music_chip'),
                    child: _zealMusicCenterChip(controller: controller),
                  )
                : SizedBox(
                    key: const ValueKey('zeal_music_empty'),
                    height: 36.h,
                  ),
          ),
        ),
        SizedBox(
          width: sideSlotW,
          child: Align(
            alignment: Alignment.centerRight,
            child: Obx(() => _buildZealTopTrailing(controller, hasMusic)),
          ),
        ),
      ],
    );
  }

  /// Center music strip: icon — text (max width + ellipsis) — divider — clear.
  Widget _zealMusicCenterChip({required CreatePostController controller}) {
    final title = controller.musicTitle?.trim();
    final displayTitle = (title != null && title.isNotEmpty)
        ? title
        : 'Unknown track';

    // Row must not use min intrinsic width: icon + gaps + max(text) + divider + clear
    // can exceed the Expanded middle slot. [Expanded] lets the title shrink with ellipsis.
    return Container(
      constraints: BoxConstraints(maxWidth: 220.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20.w,
            height: 20.w,
            child: Assets.icons.icSong.svg(
              colorFilter: ColorFilter.mode(AppColors.white, BlendMode.srcIn),
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              displayTitle,
              style: TextStyles.medium(12.sp, fontColor: AppColors.whiteFFFFFF),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 6.w),
          Container(
            width: 1,
            height: 16.h,
            color: AppColors.whiteFFFFFF.withValues(alpha: 0.35),
          ),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: () async {
              await controller.clearZealMusicSelection();
            },
            child: SizedBox(
              width: 20.w,
              height: 20.w,
              child: Icon(Icons.close, color: AppColors.white, size: 18.sp),
            ),
          ),
        ],
      ),
    );
  }

  void _openZealMusicPicker(CreatePostController controller) {
    SearchMusicBottomSheet.show(
      onMusicSelect: (track) async {
        Get.back();
        final ok = await controller.applyZealMusicFromTrack(track);
        if (!ok) {
          AppFunctions().showToast(
            'Could not load music. Check your connection and try again.',
            bgColor: AppColors.red,
          );
        }
      },
    );
  }

  Future<void> _onZealNextTap(CreatePostController controller) async {
    if (controller.isRecording.value) {
      await controller.stopRecordingWithoutPreview();
    }

    if (controller.confirmedMusic != null &&
        controller.recordedVideo.value != null) {
      try {
        final videoFile = File(controller.recordedVideo.value!.path);
        if (videoFile.existsSync() &&
            controller.confirmedMusic!.downloadedURL != null) {
          final mergedVideo = await controller.mergeVideoWithTrimmedMusic(
            videoPath: videoFile.path,
            musicPath: controller.confirmedMusic!.downloadedURL!,
            startMS: controller.confirmedMusic!.audioStartMS ?? 0,
            endMS:
                controller.confirmedMusic!.endMilliSec ??
                (controller.confirmedMusic!.audioStartMS ?? 0) +
                    controller.videoDurationInMs,
            outputVideoDurationMs: controller.videoDurationInMs,
          );
          VideoPreviewBottomSheet.show(
            videoFile: mergedVideo,
            isRecordedVideo: true,
            baseAlreadyIncludesMusicMix: true,
          );
        }
      } catch (e) {
        debugPrint('Error merging video with music: $e');
        final videoFile = File(controller.recordedVideo.value!.path);
        if (videoFile.existsSync()) {
          VideoPreviewBottomSheet.show(
            videoFile: videoFile,
            isRecordedVideo: true,
          );
        }
      }
    } else if (controller.recordedVideo.value != null) {
      final videoFile = File(controller.recordedVideo.value!.path);
      if (videoFile.existsSync()) {
        VideoPreviewBottomSheet.show(
          videoFile: videoFile,
          isRecordedVideo: true,
        );
      }
    }
  }

  Widget _buildZealTopTrailing(CreatePostController controller, bool hasMusic) {
    if (controller.isMusicShowInZeal.value) {
      return SizedBox(width: 72.w, height: 32.h);
    }
    // Paused recording: Next to preview/merge (same as before; works with or without music).
    if (controller.isPaused.value) {
      return GestureDetector(
        onTap: () => _onZealNextTap(controller),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(51.r),
            color: AppColors.primaryColor,
          ),
          child: Text(
            'Next',
            style: TextStyles.medium(17.sp, fontColor: AppColors.white),
          ),
        ),
      );
    }
    // Hide music picker while recording (active); layout slot unchanged.
    if (controller.isRecording.value) {
      return SizedBox(width: 72.w, height: 32.h);
    }
    if (!hasMusic) {
      return GestureDetector(
        onTap: () => _openZealMusicPicker(controller),
        child: SizedBox(
          width: 32.w,
          height: 32.w,
          child: Center(
            child: SizedBox(
              width: 22.w,
              height: 22.w,
              child: Assets.icons.icSong.svg(
                colorFilter: ColorFilter.mode(AppColors.white, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(width: 72.w, height: 32.h);
  }

  Widget audioSetWidget() {
    return GetBuilder<CreatePostController>(
      builder: (controller) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.network(
                      'data:image/jpeg;base64,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',
                      width: 56.w,
                      height: 56.w,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 56.w,
                          height: 56.w,
                          color: AppColors.grayEDF1F4,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 56.w,
                        height: 56.w,
                        color: AppColors.grayEDF1F4,
                        child: Icon(
                          Icons.music_note,
                          color: AppColors.gray707070,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ),
                  Gap(12.w),
                  // Track info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Say You Won’s Let Go",
                          style: TextStyles.bold(
                            16.sp,
                            fontColor: AppColors.black2F3039,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Gap(4.h),
                        Text(
                          'Vishal shaker',
                          style: TextStyles.medium(
                            12.sp,
                            fontColor: AppColors.gray8C9499,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Gap(8.w),

                  InkWell(
                    onTap: controller.playPause,
                    child: Container(
                      height: 25.h,
                      width: 25.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.primaryColor,
                          ],
                        ),
                      ),
                      child: Obx(() {
                        return controller.isPlaying.value
                            ? Icon(
                                Icons.pause,
                                color: AppColors.white,
                                size: 15,
                              )
                            : Icon(
                                Icons.play_arrow,
                                color: AppColors.white,
                                size: 15,
                              );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Obx(() {
              final duration = controller.durationInMilliSec.value;

              if (duration == null ||
                  duration.isNaN ||
                  duration.isInfinite ||
                  duration <= 0) {
                return const CircularProgressIndicator();
              }

              return MusicWaveSlider(
                controller: controller,
                audioDuration: duration,
                videoDuration: 30,
              );
            }),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildPollTab(CreatePostController controller) {
    // Initialize poll options when tab is first opened
    if (controller.pollOptionControllers.isEmpty) {
      controller.initializePollOptions();
    }

    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      appBar: _buildPollHeader(controller),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          children: [
            Gap(20.h),
            // User profile section
            _buildUserProfileSection(),
            Gap(25.h),
            // Caption input
            _buildPollCaption(controller),
            Gap(10.h),
            // Poll options
            _buildPollOptions(controller),
            Gap(5.h),
            // Poll duration
            _buildPollDuration(controller),
            Gap(20.h),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildPollHeader(CreatePostController controller) {
    return AppBar(
      backgroundColor: AppColors.whiteFFFFFF,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: EdgeInsets.only(left: 16.w),
        child: IconButton(
          icon: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
          padding: EdgeInsets.zero,
          splashColor: AppColors.transparentColor,
          highlightColor: AppColors.transparentColor,
          constraints: const BoxConstraints(),
          onPressed: () {
            controller.disposeCamera();
            Get.back();
          },
        ),
      ),
      leadingWidth: 40.w,
      titleSpacing: 0,
      centerTitle: true,
      title: Text(
        'Start Poll',
        style: TextStyles.bold(18.sp, fontColor: AppColors.black2F3039),
      ),
      actions: [
        GetBuilder<CreatePostController>(
          builder: (ctrl) {
            final canPost =
                ctrl.pollCaptionController.text.isNotEmpty &&
                ctrl.pollOptionControllers.any((c) => c.text.trim().isNotEmpty);
            final isLoading = ctrl.isLoadingPoll.value;
            final enabled = canPost && !isLoading;

            return Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: InkWell(
                splashColor: AppColors.transparentColor,
                highlightColor: AppColors.transparentColor,
                onTap: enabled ? () => ctrl.submitPoll() : null,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: enabled
                        ? AppColors.primaryColor
                        : AppColors.primaryColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(51.r),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.whiteFFFFFF,
                          ),
                        )
                      : Text(
                          'Post',
                          style: TextStyles.medium(
                            16.sp,
                            fontColor: AppColors.whiteFFFFFF,
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1.h),
        child: Container(height: 1, color: AppColors.grayEAEAEA),
      ),
    );
  }

  Widget _buildUserProfileSection() {
    final profileImageUrl =
        Get.find<MyProfileController>().profile.value?.profileImage ??
        PrefService.getString(PrefKeys.userProfile);
    final username =
        Get.find<MyProfileController>().profile.value?.username ??
        PrefService.getString(PrefKeys.userName);
    bool isVerifiedBeach =
        Get.find<MyProfileController>().profile.value?.isVerifiedBadge ??
        PrefService.getBool(PrefKeys.isVerifiedBeach);
    final displayName = username.isNotEmpty ? '@$username' : 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Gap(20),
            CommonProfileImage(
              imageUrl: profileImageUrl,
              width: 60.w,
              height: 60.w,
              memCacheWidth: 120,
              memCacheHeight: null,
            ),
            Gap(8.h),
            Row(
              children: [
                Text(
                  displayName,
                  style: TextStyles.regular(
                    16.sp,
                    fontColor: AppColors.black2F3039,
                  ),
                ),
                Gap(5.h),
                if (isVerifiedBeach == true) ...[
                  Assets.icons.icVerifyBadgeSmallSize.svg(
                    width: 16.w,
                    height: 16.h,
                  ),
                ],
              ],
            ),
            Gap(20),
          ],
        ),
      ],
    );
  }

  Widget _buildPollCaption(CreatePostController controller) {
    return TextField(
      controller: controller.pollCaptionController,
      onChanged: (_) => controller.update(),
      maxLines: null,
      style: TextStyles.medium(18.sp, fontColor: AppColors.black2F3039),
      decoration: InputDecoration(
        hintText: "Add a caption...",
        hintStyle: TextStyles.medium(18.sp, fontColor: AppColors.greyC4CACE),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPollOptions(CreatePostController controller) {
    return Obx(() {
      return Column(
        children: List.generate(controller.pollOptionControllers.length, (
          index,
        ) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildPollOptionItem(controller, index),
          );
        }),
      );
    });
  }

  Widget _buildPollOptionItem(CreatePostController controller, int index) {
    final optionController = controller.pollOptionControllers[index];
    final isLast = index == controller.pollOptionControllers.length - 1;
    final canRemove = controller.pollOptionControllers.length > 2;

    return Row(
      children: [
        Expanded(
          child:
              // Container(
              //
              //   padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6),
              //   decoration: BoxDecoration(
              //     color: AppColors.whiteFFFFFF,
              //     borderRadius: BorderRadius.circular(12.r),
              //     border: Border.all(color: AppColors.gray8C9499.withValues(alpha: 0.4), width: 1),
              //   ),
              //   child: TextField(
              //     controller: optionController,
              //     onChanged: (_) => controller.update(),
              //     style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
              //     decoration: InputDecoration(
              //       hintText: 'Option ${index + 1}',
              //       hintStyle: TextStyles.medium(16.sp, fontColor: AppColors.greyC4CACE),
              //       border: InputBorder.none,
              //       contentPadding: EdgeInsets.zero,
              //     ),
              //   ),
              // ),
              CommonTextField(
                hintText: 'Option ${index + 1}',
                labelText: 'Option ${index + 1}',
                controller: optionController,
                textFieldPadding: EdgeInsets.symmetric(vertical: 2),
                onChanged: (_) => controller.update(),
              ),
        ),
        Gap(8.w),
        // Remove button (X) or Add button (+)
        GestureDetector(
          onTap: () {
            if (isLast) {
              controller.addPollOption();
            } else if (canRemove) {
              controller.removePollOption(index);
            }
          },
          child: Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: isLast
                  ? AppColors.transparentColor
                  : AppColors.black2F3039,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLast ? Icons.add : Icons.close,
              size: isLast ? 30.sp : 20.sp,
              color: isLast ? AppColors.primaryColor : AppColors.whiteFFFFFF,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPollDuration(CreatePostController controller) {
    return GestureDetector(
      onTap: () => _showPollDurationPicker(controller),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.grayEDF1F4,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Text(
              'Poll Duration',
              style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
            ),
            const Spacer(),
            Obx(() {
              return Text(
                controller.getPollDurationText(),
                style: TextStyles.medium(
                  16.sp,
                  fontColor: AppColors.gray8C9499,
                ),
              );
            }),
            Gap(8.w),
            Icon(
              Icons.keyboard_arrow_down,
              size: 28.sp,
              color: AppColors.black2F3039,
            ),
          ],
        ),
      ),
    );
  }

  void _showPollDurationPicker(CreatePostController controller) {
    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PollDurationPicker(
        controller: controller,
        initialDays: controller.pollDurationDays.value,
        initialHours: controller.pollDurationHours.value,
        initialMinutes: controller.pollDurationMinutes.value,
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    CreatePostController controller,
  ) {
    return Container(
      padding: EdgeInsets.only(bottom: 40.h),
      margin: EdgeInsets.symmetric(horizontal: 30.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            // onTap: () {
            //   GalleryBottomSheet.show();
            //   controller.loadAlbums();
            //   controller.loadAssets();
            // },
            onTap: () async {
              final allowed = await controller.refreshGalleryPermissionState();
              if (!context.mounted) return;
              if (allowed) {
                InstaImagePickerHelper.openPicker(context);
              } else {
                Get.dialog(
                  PermissionDeniedDialog(
                    deniedPermission: "Files and media",
                    onBackPressed: () {
                      Get.back();
                    },
                  ),
                  barrierDismissible: false,
                );
              }
            },
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: AppColors.whiteFFFFFF.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(
                Icons.image,
                color: AppColors.whiteFFFFFF,
                size: 24.sp,
              ),
            ) /*Obx(() {
              // Show last captured image if available, otherwise show icon
              if (controller.capturedImages.isNotEmpty) {
                final lastImage = controller.capturedImages.last;
                return Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6.r)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: Image.file(
                      File(lastImage.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.whiteFFFFFF.withValues(alpha: 0.2),
                          child: Icon(Icons.image, color: AppColors.whiteFFFFFF, size: 24.sp),
                        );
                      },
                    ),
                  ),
                );
              }
              return Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.whiteFFFFFF.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(Icons.image, color: AppColors.whiteFFFFFF, size: 24.sp),
              );
            }),*/,
          ),
          GestureDetector(
            onTap: () => controller.takePicture(),
            child: Container(
              width: 65.w,
              height: 65.w,
              decoration: BoxDecoration(
                color: AppColors.transparentColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Assets.icons.icCameraClick.svg(),
            ),
          ),

          GestureDetector(
            onTap: () => controller.switchCamera(),
            child: Assets.icons.icCameraFlip.svg(),
          ),
        ],
      ),
    );
  }

  Widget _buildZealBottomControls(CreatePostController controller) {
    return Container(
      padding: EdgeInsets.only(bottom: 40.h),
      margin: EdgeInsets.symmetric(horizontal: 30.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Obx(() {
            if (controller.isRecording.value) {
              return SizedBox(width: 40.w, height: 40.w);
            }
            return GestureDetector(
              onTap: () async {
                // If there's a recorded video, show preview. Otherwise, open gallery
                if (controller.recordedVideo.value != null) {
                  final videoFile = File(controller.recordedVideo.value!.path);
                  if (videoFile.existsSync()) {
                    VideoPreviewBottomSheet.show(
                      videoFile: videoFile,
                      isRecordedVideo: true,
                    );
                  }
                } else {
                  final ctx = Get.context;
                  if (ctx == null) return;
                  final allowed = await controller.refreshGalleryPermissionState();
                  if (!ctx.mounted) return;
                  if (allowed) {
                    InstaImagePickerHelper.openZealVideoPicker(ctx);
                  } else {
                    if (Get.isDialogOpen ?? false) {
                      Get.back();
                    }
                    Get.dialog(
                      PermissionDeniedDialog(
                        deniedPermission: "Files and media",
                        onBackPressed: () {
                          Get.back();
                        },
                      ),
                      barrierDismissible: false,
                    );
                  }
                }
              },
              child: Obx(() {
                // Show last recorded video if available, otherwise show icon
                if (controller.recordedVideo.value != null) {
                  final video = controller.recordedVideo.value!;
                  return Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: AppColors.whiteFFFFFF.withValues(alpha: 0.2),
                            child: Icon(
                              Icons.videocam,
                              color: AppColors.whiteFFFFFF,
                              size: 24.sp,
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Icon(
                              Icons.play_circle_filled,
                              color: AppColors.whiteFFFFFF,
                              size: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: AppColors.whiteFFFFFF.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(
                    Icons.videocam,
                    color: AppColors.whiteFFFFFF,
                    size: 24.sp,
                  ),
                );
              }),
            );
          }),
          Obx(() {
            final isRecording = controller.isRecording.value;
            final isPaused = controller.isPaused.value;
            return GestureDetector(
              onTap: () {
                if (isRecording) {
                  // If recording, toggle pause/resume
                  if (isPaused) {
                    controller.resumeRecording();
                  } else {
                    controller.pauseRecording();
                  }
                } else {
                  // If not recording, start recording
                  controller.startRecording();
                }
              },
              onLongPress: () {
                // Long press to stop recording
                if (isRecording) {
                  controller.stopRecording();
                }
              },

              child: isRecording == false
                  ? Container(
                      width: 65.w,
                      height: 65.w,
                      decoration: BoxDecoration(
                        color: AppColors.transparentColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Assets.icons.icCameraClick.svg(),
                    )
                  : Obx(() {
                      // Calculate progress: elapsed time / 30 seconds
                      final progress =
                          (controller.recordingDuration.value.inMilliseconds /
                                  controller.videoDurationInMs)
                              .clamp(0.0, 1.0);
                      final isPaused = controller.isPaused.value;
                      return Stack(
                        alignment: AlignmentGeometry.center,
                        children: [
                          Container(
                            width: 65.w,
                            height: 65.w,
                            decoration: BoxDecoration(
                              color: AppColors.transparentColor,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Assets.icons.icCameraClick.svg(),
                          ),
                          SizedBox(
                            width: 63.w,
                            height: 63.w,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3.6,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      );
                    }),
            );
          }),
          Obx(() {
            final isRecording = controller.isRecording.value;
            if (isRecording) {
              return SizedBox(
                width: 40.w,
                height: 40.w,
              );
            }
            return GestureDetector(
              onTap: () => controller.switchCamera(),
              child: Assets.icons.icCameraFlip.svg(),
            );
          }),
        ],
      ),
    );
  }

  Widget buildBottomTabs(CreatePostController controller) {
    final List<String> modes = ['WRITE', 'POST', 'ZEAL', 'POLL'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: EdgeInsets.symmetric(vertical: 15.h),
          alignment: Alignment.center,
          width: Get.width * 0.7,
          height: 44.h,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(500.r),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(modes.length, (index) {
              return Obx(() {
                return GestureDetector(
                  onTap: () => controller.changeTab(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        modes[index],
                        style: TextStyles.medium(
                          12.sp,
                          fontColor: AppColors.whiteFFFFFF,
                        ),
                      ),
                      if (controller.selectedTabIndex.value == index) ...[
                        Container(
                          width: 4.w,
                          height: 4.w,
                          decoration: BoxDecoration(
                            color: AppColors.whiteFFFFFF,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              });
            }),
          ),
        ),
      ],
    );
  }
}
