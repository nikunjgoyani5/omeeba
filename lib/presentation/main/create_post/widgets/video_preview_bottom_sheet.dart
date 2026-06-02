import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:omeeba_new/core/utils/audio_file_helper.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/presentation/main/create_post/controller/create_post_controller.dart';
import 'package:omeeba_new/presentation/main/post/views/post_data_screen.dart';
import 'package:omeeba_new/presentation/main/post/views/selected_music_sheet_controller.dart';
import 'package:omeeba_new/presentation/main/post/views/wave_slider.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/download_processing_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/post/widgets/search_music_bottomsheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_native_video_trimmer/flutter_native_video_trimmer.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:omeeba_new/presentation/main/create_post/widgets/native_trim_timeline.dart';

class VideoPreviewBottomSheet extends StatefulWidget {
  final File? videoFile;
  final AssetEntity? videoAsset;
  final bool
  isRecordedVideo; // Whether this is a recorded video (can be discarded)

  /// True when [videoFile] already has library audio baked in (e.g. Zeal "Next" merge).
  /// Prevents treating that file as mic-only (Original off would mute music too).
  final bool baseAlreadyIncludesMusicMix;

  const VideoPreviewBottomSheet({
    super.key,
    this.videoFile,
    this.videoAsset,
    this.isRecordedVideo = false,
    this.baseAlreadyIncludesMusicMix = false,
  });

  static void show({
    File? videoFile,
    AssetEntity? videoAsset,
    bool isRecordedVideo = false,
    bool baseAlreadyIncludesMusicMix = false,
  }) {
    Get.bottomSheet(
      VideoPreviewBottomSheet(
        videoFile: videoFile,
        videoAsset: videoAsset,
        isRecordedVideo: isRecordedVideo,
        baseAlreadyIncludesMusicMix: baseAlreadyIncludesMusicMix,
      ),
      isScrollControlled: true,
      backgroundColor: AppColors.transparentColor,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  State<VideoPreviewBottomSheet> createState() =>
      _VideoPreviewBottomSheetState();
}

class _VideoPreviewBottomSheetState extends State<VideoPreviewBottomSheet>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  int _videoControllerGeneration = 0;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isMuted = false; // true = original sound off
  bool _isDownloading = false;
  bool isTrimMode = false;
  String? _previewMusicKey;
  File? _baseVideoFile;
  AssetEntity? _currentVideoAsset;
  late final String filepath;
  bool _wasPlayingBeforePause = false;
  String? _inflightPreviewKey;

  /// Raw Zeal recording on disk (for remerge when [baseAlreadyIncludesMusicMix] display file is pre-merged).
  File? _rawZealRecordingForMerge;

  /// FFmpeg output: single stream (reliable audio). [isOriginalSoundOn] is baked in at merge time.
  bool _previewUsesMergedVideo = false;
  File? _mergedPreviewFile;
  bool _isPreparingPreview = false;
  double _previewPrepareProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _baseVideoFile = widget.videoFile;
    _currentVideoAsset = widget.videoAsset;
    final ctrl = Get.find<CreatePostController>();
    _isMuted = !ctrl.isOriginalSoundOn;
    if (widget.isRecordedVideo) {
      final rv = ctrl.recordedVideo.value;
      if (rv != null) {
        final f = File(rv.path);
        if (f.existsSync()) _rawZealRecordingForMerge = f;
      }
    }

    _loadBaseAndInit();
  }

  Future<void> _loadBaseAndInit() async {
    if (_baseVideoFile == null && _currentVideoAsset != null) {
      final file = await _currentVideoAsset!.file;
      if (file != null) _baseVideoFile = file;
    }
    if (_baseVideoFile != null) {
      await _initializeVideo();
      filepath = await generateThumbnail() ?? '';
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'No video provided';
      });
    }
  }

  void _deleteMergedPreviewFile() {
    final f = _mergedPreviewFile;
    if (f != null) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    _mergedPreviewFile = null;
  }

  /// Prefer the raw Zeal capture for FFmpeg when the displayed file is already merged once.
  File? _mergeInputVideoFile() {
    final r = _rawZealRecordingForMerge;
    if (r != null && r.existsSync()) return r;
    final b = _baseVideoFile;
    if (b != null && b.existsSync()) return b;
    return null;
  }

  Future<void> _initializeVideo({File? playbackOverride}) async {
    try {
      final previousController = _videoController;
      if (mounted) {
        setState(() {
          _videoController = null;
          _isInitialized = false;
          _isPlaying = false;
        });
      } else {
        _videoController = null;
        _isInitialized = false;
        _isPlaying = false;
      }
      previousController?.removeListener(_videoListener);
      await previousController?.dispose();

      File? fileToPlay;
      if (playbackOverride != null && playbackOverride.existsSync()) {
        fileToPlay = playbackOverride;
      } else if (_previewUsesMergedVideo &&
          _mergedPreviewFile != null &&
          _mergedPreviewFile!.existsSync()) {
        fileToPlay = _mergedPreviewFile;
      } else {
        fileToPlay = _baseVideoFile;
        if (fileToPlay == null && _currentVideoAsset != null) {
          fileToPlay = await _currentVideoAsset!.file;
        }
      }
      if (fileToPlay == null || !fileToPlay.existsSync()) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No video to play';
        });
        return;
      }

      final generation = ++_videoControllerGeneration;
      final nextController = VideoPlayerController.file(
        fileToPlay,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await nextController.initialize();
      if (!mounted || generation != _videoControllerGeneration) {
        await nextController.dispose();
        return;
      }
      _videoController = nextController;

      final vd = nextController.value.duration.inMilliseconds;
      if (vd > 0) {
        Get.find<CreatePostController>().videoDurationInMs = vd;
      }

      setState(() {
        _isInitialized = true;
        _isPlaying = false;
      });
      nextController.setLooping(true);
      _applyPreviewVolume();
      nextController.addListener(_videoListener);
      nextController.play();
      setState(() {
        _isPlaying = true;
      });
      _syncPreviewMusicIfNeeded(Get.find<CreatePostController>());
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  /// Merged preview: one stream — volume is master. Re-merge when [Original] toggles (see key).
  void _applyPreviewVolume() {
    if (_videoController == null) return;
    final ctrl = Get.find<CreatePostController>();
    if (_previewUsesMergedVideo) {
      _videoController!.setVolume(1.0);
      return;
    }
    _videoController!.setVolume(ctrl.isOriginalSoundOn ? 1.0 : 0.0);
  }

  void _videoListener() {
    if (_videoController == null || !mounted) return;
    late final bool isPlaying;
    try {
      isPlaying = _videoController!.value.isPlaying;
    } catch (_) {
      // Controller may be in the middle of a platform swap/dispose.
      return;
    }
    if (_isPlaying != isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }
  }

  void _syncPreviewMusicIfNeeded(CreatePostController controller) {
    final music = controller.confirmedMusic;
    if (music == null ||
        music.downloadedURL == null ||
        music.downloadedURL!.isEmpty) {
      _previewMusicKey = null;
      if (_previewUsesMergedVideo) {
        _previewUsesMergedVideo = false;
        _deleteMergedPreviewFile();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _initializeVideo();
        });
      }
      _applyPreviewVolume();
      return;
    }

    _applyPreviewVolume();

    final key =
        '${music.musicId ?? ''}-${music.audioStartMS}-${music.endMilliSec}-${controller.isOriginalSoundOn}';
    if (_previewMusicKey == key) return;
    if (_inflightPreviewKey == key) return;
    _inflightPreviewKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await _runMergedMusicPreview(controller, music, key);
      } finally {
        if (_inflightPreviewKey == key) {
          _inflightPreviewKey = null;
        }
      }
    });
  }

  bool _confirmedMusicMatchesKey(
    SelectedMusic music,
    String key,
    CreatePostController ctrl,
  ) {
    final k =
        '${music.musicId ?? ''}-${music.audioStartMS}-${music.endMilliSec}-${ctrl.isOriginalSoundOn}';
    return k == key;
  }

  Future<void> _runMergedMusicPreview(
    CreatePostController ctrl,
    SelectedMusic music,
    String key,
  ) async {
    final cur = ctrl.confirmedMusic;
    if (cur == null || !_confirmedMusicMatchesKey(cur, key, ctrl)) {
      return;
    }

    // Zeal "Next" already merged music into [videoFile] — don't mute as "mic only" or re-merge yet.
    if (widget.baseAlreadyIncludesMusicMix &&
        _mergedPreviewFile == null &&
        !_previewUsesMergedVideo &&
        _confirmedMusicMatchesKey(cur, key, ctrl)) {
      if (mounted) {
        setState(() {
          _previewUsesMergedVideo = true;
          _previewMusicKey = key;
        });
      }
      _applyPreviewVolume();
      return;
    }

    if (_previewUsesMergedVideo) {
      _previewUsesMergedVideo = false;
      final hadTempMergedPreview = _mergedPreviewFile != null;
      _deleteMergedPreviewFile();
      if (widget.baseAlreadyIncludesMusicMix &&
          !hadTempMergedPreview &&
          _rawZealRecordingForMerge != null &&
          _rawZealRecordingForMerge!.existsSync()) {
        await _initializeVideo(playbackOverride: _rawZealRecordingForMerge);
      } else {
        await _initializeVideo();
      }
      if (!mounted) return;
    }

    setState(() {
      _isPreparingPreview = true;
      _previewPrepareProgress = 0;
    });
    try {
      final still = Get.find<CreatePostController>().confirmedMusic;
      if (still == null || !_confirmedMusicMatchesKey(still, key, ctrl)) {
        return;
      }
      await _fallbackMergedPreviewPlayback(still, key);
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingPreview = false;
          _previewPrepareProgress = 0;
        });
      }
    }
  }

  Future<void> _fallbackMergedPreviewPlayback(
    SelectedMusic music,
    String key,
  ) async {
    final ctrl = Get.find<CreatePostController>();
    final confirmed = ctrl.confirmedMusic;
    if (confirmed == null || !_confirmedMusicMatchesKey(confirmed, key, ctrl)) {
      return;
    }
    final File? base = (widget.baseAlreadyIncludesMusicMix &&
            _rawZealRecordingForMerge != null &&
            _rawZealRecordingForMerge!.existsSync())
        ? _rawZealRecordingForMerge
        : _baseVideoFile;
    if (base == null || !base.existsSync()) return;

    final resolvedMusic = await AudioFileHelper.ensureLocalAudioFile(
      confirmed.downloadedURL!,
    );
    if (resolvedMusic == null) {
      if (mounted) {
        AppFunctions().showToast(
          'Could not load music for preview',
          bgColor: AppColors.red,
        );
      }
      return;
    }

    final durationMs = _mergeInputDurationMs(ctrl);
    final SelectedMusic? savedMusic = ctrl.confirmedMusic;
    final bool swapPath =
        resolvedMusic.path != (savedMusic?.downloadedURL ?? '');
    if (swapPath && savedMusic != null) {
      ctrl.confirmedMusic = SelectedMusic(
        savedMusic.audioStartMS,
        resolvedMusic.path,
        savedMusic.endMilliSec,
        musicId: savedMusic.musicId,
      );
    }

    try {
      final merged = await ctrl.buildConfirmedVideo(
        baseVideo: base,
        durationMs: durationMs,
        assignConfirmedVideoFile: false,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _previewPrepareProgress = p.clamp(0, 100));
        },
      );
      if (!mounted || merged == null || !merged.existsSync()) return;
      final still = ctrl.confirmedMusic;
      if (still == null || !_confirmedMusicMatchesKey(still, key, ctrl)) {
        return;
      }

      _deleteMergedPreviewFile();
      _mergedPreviewFile = merged;
      _previewUsesMergedVideo = true;
      _previewMusicKey = key;

      await _initializeVideo();
      if (!mounted) return;
      setState(() {
        _isPlaying = _videoController?.value.isPlaying ?? false;
      });
    } catch (e, st) {
      debugPrint('FFmpeg preview merge failed: $e\n$st');
      if (mounted) {
        AppFunctions().showToast(
          'Could not build preview with music',
          bgColor: AppColors.red,
        );
      }
    } finally {
      if (swapPath && savedMusic != null) {
        ctrl.confirmedMusic = savedMusic;
      }
    }
  }

  int _mergeInputDurationMs(CreatePostController ctrl) {
    if (!_previewUsesMergedVideo) {
      final v = _videoController?.value.duration.inMilliseconds ?? 0;
      if (v > 0) return v;
    }
    final d = ctrl.videoDurationInMs;
    if (d > 0) return d;
    final m = ctrl.confirmedMusic;
    if (m != null &&
        m.audioStartMS != null &&
        m.endMilliSec != null &&
        m.endMilliSec! > m.audioStartMS!) {
      final seg = m.endMilliSec! - m.audioStartMS!;
      if (seg > 0) return seg;
    }
    final v2 = _videoController?.value.duration.inMilliseconds ?? 0;
    return v2 > 0 ? v2 : CreatePostController.kZealDefaultMaxRecordingMs;
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isInitialized) return;

    if (_isPlaying) {
      _videoController!.pause();
      _pausePreviewAudio();
    } else {
      _videoController!.play();
      _resumePreviewAudio();
    }
  }

  void _pauseAllPlayback() {
    // Pause video + stop any preview music before opening another sheet
    _videoController?.pause();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
    _stopPreviewAudio();
  }

  /// User leaves preview without posting: drop clip + library music so Zeal state matches a fresh take.
  Future<void> _onPreviewBack() async {
    _pauseAllPlayback();
    final c = Get.find<CreatePostController>();
    c.discardRecordedVideo();
    c.setOriginalSoundOn(true);
    try {
      await c.clearZealMusicSelection();
    } catch (e, st) {
      debugPrint('Zeal preview back reset: $e\n$st');
    }
    Get.back();
  }

  Future<void> _applyTrimResult(TrimResult result) async {
    _previewMusicKey = null;
    _previewUsesMergedVideo = false;
    _deleteMergedPreviewFile();
    _baseVideoFile = result.file;
    _currentVideoAsset = null;
    final controller = Get.find<CreatePostController>();
    final music = controller.confirmedMusic;
    if (music != null && music.downloadedURL != null) {
      final startMs = music.audioStartMS ?? 0;
      final endMs = startMs + result.durationMs;
      controller.selectedMusic = SelectedMusic(
        startMs,
        music.downloadedURL,
        endMs,
        musicId: music.musicId,
      );
      controller.confirmedMusic = SelectedMusic(
        startMs,
        music.downloadedURL,
        endMs,
        musicId: music.musicId,
      );
      controller.update();
    }
    await _initializeVideo();
  }

  void _pausePreviewAudio() {}

  void _resumePreviewAudio() {}

  void _stopPreviewAudio() {}

  /// Updates [isOriginalSoundOn] (baked into FFmpeg preview). [GetBuilder] rebuild remerges.
  void _toggleSound() {
    if (_videoController == null) return;
    final ctrl = Get.find<CreatePostController>();
    final next = !ctrl.isOriginalSoundOn;
    ctrl.setOriginalSoundOn(next);
    setState(() {
      _isMuted = !next;
    });
    _previewMusicKey = null;
    _applyPreviewVolume();
  }

  Future<void> _onRemoveSelectedMusic() async {
    _pauseAllPlayback();
    final c = Get.find<CreatePostController>();
    try {
      await c.clearZealMusicSelection();
    } catch (e, st) {
      debugPrint('Remove music: $e\n$st');
    }
    if (!mounted) return;
    final wasMerged = _previewUsesMergedVideo;
    setState(() {
      _previewMusicKey = null;
      _inflightPreviewKey = null;
      _isMuted = !c.isOriginalSoundOn;
      _previewUsesMergedVideo = false;
    });
    _deleteMergedPreviewFile();
    if (wasMerged) {
      await _initializeVideo();
    } else {
      _applyPreviewVolume();
    }
    if (_videoController != null &&
        _isInitialized &&
        _videoController!.value.isInitialized) {
      _videoController!.play();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    }
  }

  Future<String?> generateThumbnail() async {
    try {
      File? source = _baseVideoFile;
      if (source == null && _currentVideoAsset != null) {
        source = await _currentVideoAsset!.file;
      }

      if (source == null) return null;

      // final thumb = await VideoThumbnail.thumbnailFile(
      //   video: source.path,
      //   thumbnailPath: (await getTemporaryDirectory()).path,
      //   imageFormat: ImageFormat.JPEG,
      //   maxHeight: 400,
      //   // quality vs size
      //   quality: 75,
      // );

      // return thumb; // <-- local file path
      return "";
    } catch (e) {
      debugPrint('Thumbnail error: $e');
      return null;
    }
  }

  Future<void> _downloadVideo() async {
    if (_isDownloading) return;

    final progress = ValueNotifier<double>(0);
    var isSheetShown = false;

    try {
      setState(() {
        _isDownloading = true;
      });
      final thumbnail = await generateThumbnail() ?? '';
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.transparentColor,
          isDismissible: false,
          enableDrag: false,
          builder: (context) => DownloadProcessingBottomSheet(
            progress: progress,
            thumbnail: thumbnail,
          ),
        );
        isSheetShown = true;
      }

      final controller = Get.find<CreatePostController>();
      final mergeIn = _mergeInputVideoFile();
      if (mergeIn == null) {
        throw Exception('No video file available');
      }

      final durationMs =
          _videoController?.value.duration.inMilliseconds ??
          controller.videoDurationInMs;
      final outputFile = await controller.buildConfirmedVideo(
        baseVideo: mergeIn,
        durationMs: durationMs,
        onProgress: (value) => progress.value = value,
      );

      if (outputFile == null) {
        throw Exception('Failed to prepare video');
      }

      // Request permission
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        throw Exception('Storage permission denied');
      }

      // Save video to gallery
      await PhotoManager.editor.saveVideo(
        outputFile,
        title: 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      if (mounted) {
        progress.value = 100;
        await Future.delayed(const Duration(milliseconds: 200));
        AppFunctions().showToast(
          'Video saved to gallery',
          bgColor: AppColors.green,
        );
      }
    } catch (e) {
      debugPrint('Error downloading video: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Failed to save video: ${e.toString()}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } finally {
      if (isSheetShown && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      progress.dispose();
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoControllerGeneration++;
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _deleteMergedPreviewFile();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _wasPlayingBeforePause = _isPlaying;
      _videoController?.pause();
      _pausePreviewAudio();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        _videoController?.play();
        _resumePreviewAudio();
      }
      _wasPlayingBeforePause = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CreatePostController>(
      builder: (controller) {
        _syncPreviewMusicIfNeeded(controller);
        _isMuted = !controller.isOriginalSoundOn;
        return Container(
              height: Get.height * 0.9,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: AppColors.whiteFFFFFF,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
              ),
              child: Column(
                children: [
              Container(
                margin: EdgeInsets.only(top: 12.h),
                height: 5.w,
                width: 55.w,
                decoration: BoxDecoration(
                  color: AppColors.grayEDF1F4,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              Gap(16.h),
              Row(
                children: [
                  Gap(7),
                  InkWell(
                    onTap: () => _onPreviewBack(),
                    child: Assets.icons.icArrowBack.image(scale: 3.5),
                  ),
                  Spacer(),
                  // Discard button (only for recorded videos)
                  if (widget.isRecordedVideo)
                    GestureDetector(
                      onTap: () {
                        _showDiscardDialog();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.orangeDA7000,
                          borderRadius: BorderRadius.circular(51.r),
                        ),
                        child: Text(
                          'Discard',
                          style: TextStyles.medium(
                            16.sp,
                            fontColor: AppColors.whiteFFFFFF,
                          ),
                        ),
                      ),
                    ),
                  Gap(15.w),
                  Material(
                    color: AppColors.transparentColor,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      splashColor: AppColors.primaryColor.withValues(alpha: 0.14),
                      highlightColor: AppColors.primaryColor.withValues(
                        alpha: 0.08,
                      ),
                      onTap: () async {
                        _pauseAllPlayback();

                        final mergeIn = _mergeInputVideoFile();
                        if (mergeIn == null) {
                          AppFunctions().showToast(
                            'No video to upload',
                            bgColor: AppColors.red,
                          );
                          return;
                        }

                        final ctrl = Get.find<CreatePostController>();
                        final progress = ValueNotifier<double>(0);
                        if (mounted) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: AppColors.transparentColor,
                            isDismissible: false,
                            enableDrag: false,
                            builder: (_) => DownloadProcessingBottomSheet(
                              progress: progress,
                              title: 'Processing...',
                              subtitle:
                                  'Stay on this screen to finish\n processing',
                              thumbnail: filepath,
                            ),
                          );
                        }

                        final videoToUpload = await ctrl.buildConfirmedVideo(
                          baseVideo: mergeIn,
                          durationMs:
                              _videoController
                                  ?.value
                                  .duration
                                  .inMilliseconds ??
                              ctrl.videoDurationInMs,
                          onProgress: (v) => progress.value = v,
                        );

                        if (mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        progress.dispose();

                        if (videoToUpload == null) {
                          AppFunctions().showToast(
                            'Failed to prepare video',
                            bgColor: AppColors.red,
                          );
                          return;
                        }

                        final thumbnail = await generateThumbnail() ?? '';

                        if (!mounted) return;
                        Get.to(
                          () => PostDataScreen(
                            type: 'Zeal',
                            videoThumbnail: thumbnail,
                            videoFilePath: videoToUpload.path,
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12.h,
                          horizontal: 14.w,
                        ),
                        child: Text(
                          'Next',
                          style: TextStyles.medium(
                            16.sp,
                            fontColor: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Gap(20.h),
              if (controller.confirmedMusic != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_note_rounded,
                        size: 18.sp,
                        color: AppColors.primaryColor,
                      ),
                      Gap(6.w),
                      Expanded(
                        child: Text(
                          _zealPreviewMusicLabel(controller),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.medium(
                            14.sp,
                            fontColor: AppColors.black2F3039,
                          ),
                        ),
                      ),
                      Material(
                        color: AppColors.transparentColor,
                        child: InkWell(
                          onTap: () => _onRemoveSelectedMusic(),
                          borderRadius: BorderRadius.circular(20.r),
                          child: Padding(
                            padding: EdgeInsets.all(4.w),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20.sp,
                              color: AppColors.gray8C9499,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Expanded(child: _buildVideoPreview()),
              Expanded(
                child: SizedBox(
                  height: Get.height * 0.5,
                  width: double.infinity,
                  child: _buildVideoPreview(),
                ),
              ),

              Gap(27.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    icon: _isMuted
                        ? Assets.icons.icVolumeOff.svg(height: 20, width: 20)
                        : Assets.icons.icVolumeOn.svg(height: 20, width: 20),
                    label: 'Original',
                    onTap: _toggleSound,
                  ),
                  // Gap(10.w),
                  // _buildActionButton(
                  //   icon: Assets.icons.icCc.svg(height: 20, width: 20),
                  //   label: 'CC',
                  //   onTap: () {
                  //     // TODO: Toggle closed captions
                  //   },
                  // ),
                  Gap(10.w),
                  _buildActionButton(
                    icon: Assets.icons.icSong.svg(height: 20, width: 20),
                    label: 'Music',
                    onTap: () {
                      if (!_isInitialized ||
                          _videoController == null ||
                          !_videoController!.value.isInitialized) {
                        AppFunctions().showToast(
                          'Wait for the video to finish loading',
                          bgColor: AppColors.orangeDA7000,
                        );
                        return;
                      }
                      final videoDurationMs =
                          _videoController!.value.duration.inMilliseconds;
                      if (videoDurationMs <= 0) {
                        AppFunctions().showToast(
                          'Could not read video duration',
                          bgColor: AppColors.red,
                        );
                        return;
                      }
                      final controller = Get.find<CreatePostController>();
                      controller.videoDurationInMs = videoDurationMs;

                      // Stop/pause any current playback while searching music
                      _pauseAllPlayback();

                      SearchMusicBottomSheet.show(
                        onMusicSelect: (track) {
                          // Stop preview audio before opening music selection bottom sheet
                          _stopPreviewAudio();
                          Get.back();

                          VideoMusicSelectionBottomSheet.show(
                            videoFile: _baseVideoFile,
                            videoAsset: _currentVideoAsset,
                            audioUrl: track.audioUrl,
                            musicId: track.id,
                            musicTitle: track.title,
                            musicArtist: track.artist,
                            albumArtUrl: track.albumArtUrl,
                            isRecordedVideo: widget.isRecordedVideo,
                            videoDurationInMs: videoDurationMs,
                            onMusicApplied: () {
                              if (!mounted) return;
                              final createCtrl =
                                  Get.find<CreatePostController>();
                              createCtrl.setOriginalSoundOn(false);
                              setState(() {
                                _isMuted = true;
                                _previewMusicKey = null;
                                _inflightPreviewKey = null;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                _syncPreviewMusicIfNeeded(
                                  Get.find<CreatePostController>(),
                                );
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                  Gap(10.w),

                  _buildActionButton(
                    icon: Assets.icons.icCutVideo.svg(height: 20, width: 20),
                    label: 'Trim',
                    onTap: () async {
                      // Pause video + stop any music before opening trim
                      _pauseAllPlayback();
                      //     _videoController?.setVolume(0);
                      final result = await VideoTrimSelectionBottomSheet.show(
                        videoFile: _baseVideoFile,
                        videoAsset: _currentVideoAsset,
                        isRecordedVideo: widget.isRecordedVideo,
                      );
                      if (result != null && mounted) {
                        await _applyTrimResult(result);
                      }
                    },
                  ),
                  Gap(10.w),
                  _buildActionButton(
                    icon: Assets.icons.icDownload.svg(height: 20, width: 20),
                    label: 'Download',
                    onTap: _downloadVideo,
                  ),
                ],
              ),
              Gap(35.h),
                ],
              ),
            );
      },
    );
  }

  String _zealPreviewMusicLabel(CreatePostController c) {
    final t = c.musicTitle?.trim();
    if (t != null && t.isNotEmpty) return t;
    final a = c.musicArtist?.trim();
    if (a != null && a.isNotEmpty) return a;
    return 'Selected music';
  }

  void _showDiscardDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.whiteFFFFFF,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Discard Video?',
          style: TextStyles.bold(18.sp, fontColor: AppColors.black2F3039),
        ),
        content: Text(
          'Are you sure you want to discard this video? This action cannot be undone.',
          style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyles.medium(16.sp, fontColor: AppColors.gray8C9499),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // Close dialog
              _pauseAllPlayback();
              final controller = Get.find<CreatePostController>();
              controller.discardRecordedVideo();
              controller.setOriginalSoundOn(true);
              await controller.clearZealMusicSelection();
              Get.back(); // Close bottom sheet
            },
            child: Text(
              'Discard',
              style: TextStyles.medium(16.sp, fontColor: AppColors.redFF5353),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: AppColors.gray8C9499),
            Gap(16.h),
            Text(
              _errorMessage ?? 'Failed to load video',
              style: TextStyles.medium(16.sp, fontColor: AppColors.gray8C9499),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _videoController == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.orangeDA7000),
      );
    }

    final controller = _videoController!;
    if (!controller.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.orangeDA7000),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r), // 👈 rounded video box
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 🎥 Video
          FittedBox(
            fit: BoxFit.cover, // 👈 no stretch, crop allowed
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),

          // ▶️ Play / Pause overlay
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              color: Colors.transparent,
              alignment: Alignment.center,
              child: _isPlaying
                  ? const SizedBox.shrink()
                  : Container(
                      width: 68.w,
                      height: 68.w,
                      decoration: BoxDecoration(
                        color: AppColors.black000000.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.white,
                        size: 50.sp,
                      ),
                    ),
            ),
          ),
          if (_isPreparingPreview)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.orangeDA7000),
                  Gap(12.h),
                  Text(
                    'Preparing preview…',
                    style: TextStyles.medium(
                      14.sp,
                      fontColor: AppColors.whiteFFFFFF,
                    ),
                  ),
                  if (_previewPrepareProgress > 0)
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Text(
                        '${_previewPrepareProgress.round()}%',
                        style: TextStyles.regular(
                          12.sp,
                          fontColor: AppColors.whiteFFFFFF,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            alignment: Alignment.center,
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: AppColors.grayEDF1F4,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Wrap(children: [icon]),
          ),
          Gap(4.h),
          Text(
            label,
            style: TextStyles.regular(12.sp, fontColor: AppColors.black2F3039),
          ),
        ],
      ),
    );
  }
}

class TrimResult {
  final File file;
  final int durationMs;

  const TrimResult({required this.file, required this.durationMs});
}

class VideoTrimSelectionBottomSheet extends StatefulWidget {
  final File? videoFile;
  final AssetEntity? videoAsset;
  final bool isRecordedVideo;

  const VideoTrimSelectionBottomSheet({
    super.key,
    this.videoFile,
    this.videoAsset,
    this.isRecordedVideo = false,
  });

  static Future<TrimResult?> show({
    File? videoFile,
    AssetEntity? videoAsset,
    bool isRecordedVideo = false,
  }) {
    return Get.bottomSheet<TrimResult>(
      VideoTrimSelectionBottomSheet(
        videoFile: videoFile,
        videoAsset: videoAsset,
        isRecordedVideo: isRecordedVideo,
      ),
      isScrollControlled: true,
      backgroundColor: AppColors.transparentColor,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  State<VideoTrimSelectionBottomSheet> createState() =>
      _VideoTrimSelectionBottomSheetState();
}

class _VideoTrimSelectionBottomSheetState
    extends State<VideoTrimSelectionBottomSheet> {
  /// Minimum selected segment (native trim + timeline both enforce when possible).
  static const int _kMinTrimDurationMs = 5000;
  static const int _kTimelineThumbCount = 12;

  final VideoTrimmer _nativeTrimmer = VideoTrimmer();
  VideoPlayerController? _videoController;
  List<Uint8List?> _timelineThumbnails = [];

  late final PlayerController _trimMusicController;
  StreamSubscription? _trimMusicCompletionSub;
  Timer? _trimMusicStopTimer;
  SelectedMusic? _confirmedMusic;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  double _startValue = 0.0;
  double _endValue = 0.0;
  int _videoDurationMs = 0;
  File? _sourceTrimFile;
  /// Separate copy for `video_thumbnail` so the file is not read while `VideoPlayer` has it open (fixes blank thumbs on Android/iOS).
  File? _videoThumbSourceFile;

  bool get _trimMeetsMinimumLength {
    if (_videoDurationMs < _kMinTrimDurationMs) return false;
    return (_endValue - _startValue) >= _kMinTrimDurationMs;
  }

  void _onVideoPlayerTick() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized || !c.value.isPlaying) return;
    final pos = c.value.position.inMilliseconds;
    if (pos >= _endValue.toInt()) {
      c.pause();
      c.seekTo(Duration(milliseconds: _startValue.toInt()));
      _stopTrimMusic();
    }
  }

  void _onTrimRangeChanged(({double start, double end}) v) {
    setState(() {
      _startValue = v.start;
      _endValue = v.end;
    });
    final vc = _videoController;
    if (vc == null) return;
    vc.pause();
    vc.seekTo(Duration(milliseconds: v.start.toInt()));
  }

  void _onPlayheadSeek(double ms) {
    final vc = _videoController;
    if (vc == null || !vc.value.isInitialized) return;
    final total = _videoDurationMs.toDouble();
    if (total <= 0) return;
    final clamped = ms.clamp(0.0, total);
    vc.seekTo(Duration(milliseconds: clamped.toInt()));
  }

  Future<Uint8List?> _extractOneTimelineThumbnail(String videoPath, int timeMs) async {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: timeMs,
        quality: 85,
        maxWidth: 240,
        maxHeight: 240,
      );
      if (data != null && data.isNotEmpty) return data;
    } catch (e) {
      debugPrint('trim thumbnailData t=$timeMs: $e');
    }
    try {
      final tmp = await getTemporaryDirectory();
      final outPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tmp.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: timeMs,
        quality: 85,
        maxWidth: 240,
        maxHeight: 240,
      );
      if (outPath == null) return null;
      final f = File(outPath);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      try {
        await f.delete();
      } catch (_) {}
      return bytes.isEmpty ? null : bytes;
    } catch (e) {
      debugPrint('trim thumbnailFile t=$timeMs: $e');
    }
    return null;
  }

  Future<void> _loadTimelineThumbnails() async {
    final thumbFile = _videoThumbSourceFile ?? _sourceTrimFile;
    final d = _videoDurationMs;
    if (thumbFile == null || d <= 0) return;

    final path = thumbFile.path;
    final lastMs = math.max(0, d - 1);
    final results = <Uint8List?>[];

    try {
      for (var i = 0; i < _kTimelineThumbCount; i++) {
        final t = _kTimelineThumbCount <= 1
            ? 0
            : ((d * i) / (_kTimelineThumbCount - 1)).floor().clamp(0, lastMs);
        results.add(await _extractOneTimelineThumbnail(path, t));
      }
      if (mounted) {
        setState(() => _timelineThumbnails = results);
      }
    } catch (e, st) {
      debugPrint('_loadTimelineThumbnails: $e\n$st');
      if (mounted) {
        setState(
          () => _timelineThumbnails =
              List<Uint8List?>.filled(_kTimelineThumbCount, null),
        );
      }
    } finally {
      try {
        if (_videoThumbSourceFile != null &&
            _videoThumbSourceFile!.existsSync()) {
          await _videoThumbSourceFile!.delete();
        }
      } catch (_) {}
      _videoThumbSourceFile = null;
    }
  }

  void _onDoneTrimTapped() {
    if (_isSaving || _isLoading) return;
    if (_videoDurationMs < _kMinTrimDurationMs) {
      Fluttertoast.showToast(
        msg: 'Video must be at least 5 seconds long.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    if ((_endValue - _startValue) < _kMinTrimDurationMs) {
      Fluttertoast.showToast(
        msg: 'Select at least 5 seconds of video.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    _saveTrimmedVideo();
  }

  @override
  void initState() {
    super.initState();
    _stopAllMusic();
    _trimMusicController = PlayerController();
    _confirmedMusic = Get.find<CreatePostController>().confirmedMusic;
    _loadVideo();
  }

  void _stopAllMusic() {
    // Stop music from VideoMusicSelectionBottomSheet if it exists
    try {
      if (Get.isRegistered<SelectedMusicSheetController>()) {
        final musicController = Get.find<SelectedMusicSheetController>();
        musicController.onPause();
      }
    } catch (e) {
      debugPrint('Music controller not found: $e');
    }
  }

  Future<void> _loadVideo() async {
    try {
      File? sourceFile = widget.videoFile;
      if (sourceFile == null && widget.videoAsset != null) {
        final file = await widget.videoAsset!.file;
        if (file == null) {
          throw Exception('Failed to load video file');
        }
        sourceFile = file;
      }
      if (sourceFile == null) {
        throw Exception('No video provided');
      }

      final ext = sourceFile.path.contains('.')
          ? sourceFile.path.split('.').last
          : 'mp4';
      final dir = await getTemporaryDirectory();
      final tempPath =
          '${dir.path}/trim_source_${DateTime.now().millisecondsSinceEpoch}.$ext';
      _sourceTrimFile = await sourceFile.copy(tempPath);

      final thumbPath =
          '${dir.path}/trim_thumbs_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _sourceTrimFile!.copy(thumbPath);
      _videoThumbSourceFile = File(thumbPath);

      _videoController?.removeListener(_onVideoPlayerTick);
      await _videoController?.dispose();
      _videoController = VideoPlayerController.file(_sourceTrimFile!);
      await _videoController!.initialize();
      _videoController!.addListener(_onVideoPlayerTick);

      final duration =
          _videoController!.value.duration.inMilliseconds;
      _videoDurationMs = duration;
      _startValue = 0.0;
      _endValue = duration.toDouble();

      // If music is already added, preview trim with that music (mute original video audio)
      await _setupTrimMusicIfNeeded();
      await _loadTimelineThumbnails();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveTrimmedVideo() async {
    if (_isSaving || _isLoading || _sourceTrimFile == null) return;
    if (_videoDurationMs < _kMinTrimDurationMs ||
        (_endValue - _startValue) < _kMinTrimDurationMs) {
      return;
    }
    final vThumbnail = await generateThumbnail() ?? '';
    final progress = ValueNotifier<double>(0);
    var isSheetShown = false;

    setState(() {
      _isSaving = true;
    });

    // Show progress loader
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.transparentColor,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => DownloadProcessingBottomSheet(
          progress: progress,
          title: 'Trimming video...',
          subtitle: 'Stay on this screen to finish trimming',
          thumbnail: vThumbnail,
        ),
      );
      isSheetShown = true;
    }

    try {
      progress.value = 10;
      await Future.delayed(const Duration(milliseconds: 100));

      await _nativeTrimmer.loadVideo(_sourceTrimFile!.path);
      final trimmedPath = await _nativeTrimmer.trimVideo(
        startTimeMs: _startValue.toInt(),
        endTimeMs: _endValue.toInt(),
      );

      progress.value = 90;
      await Future.delayed(const Duration(milliseconds: 100));

      if (trimmedPath == null) {
        if (mounted) {
          if (isSheetShown && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          setState(() {
            _isSaving = false;
          });
          Fluttertoast.showToast(
            msg: 'Could not trim video.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
        progress.dispose();
        return;
      }

      final docs = await getApplicationDocumentsDirectory();
      final outDir = Directory(p.join(docs.path, 'Trimmer'));
      await outDir.create(recursive: true);
      final base = p.basenameWithoutExtension(_sourceTrimFile!.path);
      final ext = p.extension(_sourceTrimFile!.path);
      final outPath = p.join(
        outDir.path,
        '${base}_trimmed_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(trimmedPath).copy(outPath);
      await _nativeTrimmer.clearCache();

      progress.value = 100;
      await Future.delayed(const Duration(milliseconds: 200));

      final trimmedFile = File(outPath);
      final durationMs = (_endValue - _startValue).toInt();

      if (mounted) {
        if (isSheetShown && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        Get.back(
          result: TrimResult(file: trimmedFile, durationMs: durationMs),
        );
      }
      progress.dispose();
    } catch (e) {
      if (mounted) {
        if (isSheetShown && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
      progress.dispose();
    }
  }

  Future<void> _toggleTrimPlayback() async {
    final c = _videoController;
    if (c == null || !c.value.isInitialized || _videoDurationMs <= 0) return;

    if (c.value.isPlaying) {
      await c.pause();
      _stopTrimMusic();
    } else {
      var pos = c.value.position.inMilliseconds;
      if (pos < _startValue.toInt() || pos >= _endValue.toInt()) {
        await c.seekTo(Duration(milliseconds: _startValue.toInt()));
      }
      await c.play();
      await _syncTrimMusicWithVideo();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setupTrimMusicIfNeeded() async {
    final music = _confirmedMusic;
    if (music == null || (music.downloadedURL ?? '').isEmpty) return;

    // Mute original video sound in trim preview
    try {
      await _videoController?.setVolume(0.0);
    } catch (_) {}

    try {
      final local = await AudioFileHelper.ensureLocalAudioFile(
        music.downloadedURL!,
      );
      if (local == null) {
        debugPrint('Trim music: could not resolve local audio');
        return;
      }
      await _trimMusicController.preparePlayer(
        path: local.path,
        shouldExtractWaveform: false,
      );
      _trimMusicController.setFinishMode(finishMode: FinishMode.pause);

      _trimMusicCompletionSub?.cancel();
      _trimMusicCompletionSub = _trimMusicController.onCompletion.listen((
        _,
      ) async {
        await _syncTrimMusicWithVideo();
      });
    } catch (e) {
      debugPrint('Trim music prepare error: $e');
    }
  }

  int _currentTrimDurationMs() {
    final d = (_endValue - _startValue).toInt();
    return d <= 0 ? 0 : d;
  }

  int _audioStartForCurrentTrimMs() {
    final base = _confirmedMusic?.audioStartMS ?? 0;
    return base + _startValue.toInt();
  }

  void _stopTrimMusic() {
    _trimMusicStopTimer?.cancel();
    _trimMusicController.pausePlayer();
  }

  Future<String?> generateThumbnail() async {
    try {
      File? source = _sourceTrimFile;
      if (source == null) return null;

      // final thumb = await VideoThumbnail.thumbnailFile(
      //   video: source.path,
      //   thumbnailPath: (await getTemporaryDirectory()).path,
      //   imageFormat: ImageFormat.JPEG,
      //   maxHeight: 400,
      //   // quality vs size
      //   quality: 75,
      // );

      // return thumb; // <-- local file path
      return "";
    } catch (e) {
      debugPrint('Thumbnail error: $e');
      return null;
    }
  }

  Future<void> _syncTrimMusicWithVideo() async {
    final music = _confirmedMusic;
    final video = _videoController;
    if (music == null || (music.downloadedURL ?? '').isEmpty || video == null) {
      return;
    }

    final isPlaying = video.value.isPlaying;
    if (!isPlaying) {
      _stopTrimMusic();
      return;
    }

    final trimDurationMs = _currentTrimDurationMs();
    if (trimDurationMs <= 0) {
      _stopTrimMusic();
      return;
    }

    // When trimming from startValue..endValue, music should start from (musicStart + startValue)
    final startMs = _audioStartForCurrentTrimMs();
    final trackEnd = music.endMilliSec;
    final availableMs = trackEnd != null && trackEnd > startMs
        ? (trackEnd - startMs)
        : trimDurationMs;
    final playMs = trimDurationMs < availableMs ? trimDurationMs : availableMs;
    if (playMs <= 0) {
      _stopTrimMusic();
      return;
    }
    try {
      await _trimMusicController.seekTo(startMs);
      await _trimMusicController.startPlayer();
      _trimMusicStopTimer?.cancel();
      _trimMusicStopTimer = Timer(Duration(milliseconds: playMs), () {
        _stopTrimMusic();
      });
    } catch (e) {
      debugPrint('Trim music sync error: $e');
    }
  }

  @override
  void dispose() {
    _trimMusicStopTimer?.cancel();
    _trimMusicCompletionSub?.cancel();
    _trimMusicController.release();
    _trimMusicController.dispose();
    _videoController?.removeListener(_onVideoPlayerTick);
    _videoController?.dispose();
    try {
      if (_videoThumbSourceFile != null && _videoThumbSourceFile!.existsSync()) {
        _videoThumbSourceFile!.deleteSync();
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * 0.9,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.h),
            height: 5.w,
            width: 55.w,
            decoration: BoxDecoration(
              color: AppColors.grayEDF1F4,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          Gap(16.h),
          Row(
            children: [
              Gap(7.w),
              GestureDetector(
                onTap: () => Get.back(),
                child: Assets.icons.icArrowBack.image(scale: 3.5),
              ),
              Spacer(),
              if (widget.isRecordedVideo)
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orangeDA7000,
                      borderRadius: BorderRadius.circular(51.r),
                    ),
                    child: Text(
                      'Discard',
                      style: TextStyles.medium(
                        16.sp,
                        fontColor: AppColors.whiteFFFFFF,
                      ),
                    ),
                  ),
                ),
              Gap(15.w),
              GestureDetector(
                onTap: _isSaving ? null : _onDoneTrimTapped,
                child: Text(
                  'Done',
                  style: TextStyles.medium(
                    16.sp,
                    fontColor: (!_isLoading && _trimMeetsMinimumLength)
                        ? AppColors.primaryColor
                        : AppColors.gray8C9499,
                  ),
                ),
              ),
            ],
          ),
          Gap(20.h),
          Expanded(
            child: _isLoading
                ? const _VideoPreparingPlaceholder()
                : _errorMessage != null
                ? Center(
                    child: Text(
                      _errorMessage!,
                      style: TextStyles.medium(
                        14.sp,
                        fontColor: AppColors.gray8C9499,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20.r),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio ==
                                    0
                                ? 16 / 9
                                : _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleTrimPlayback,
                          child: Container(
                            color: Colors.transparent,
                            alignment: Alignment.center,
                            child: ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: _videoController!,
                              builder: (context, value, _) {
                                return value.isPlaying
                                    ? const SizedBox.shrink()
                                    : Container(
                                        width: 68.w,
                                        height: 68.w,
                                        decoration: BoxDecoration(
                                          color: AppColors.black000000
                                              .withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: AppColors.white,
                                          size: 50.sp,
                                        ),
                                      );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Gap(16.h),
          if (!_isLoading &&
              _errorMessage == null &&
              _videoDurationMs > 0 &&
              _videoController != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _videoController!,
                builder: (context, value, _) {
                  return NativeTrimTimeline(
                    thumbnails: _timelineThumbnails,
                    totalDurationMs: _videoDurationMs,
                    startMs: _startValue,
                    endMs: _endValue,
                    minTrimMs: _videoDurationMs < _kMinTrimDurationMs
                        ? _videoDurationMs.toDouble()
                        : _kMinTrimDurationMs.toDouble(),
                    playheadMs: value.position.inMilliseconds.toDouble(),
                    onTrimChanged: _onTrimRangeChanged,
                    onPlayheadSeek: _onPlayheadSeek,
                  );
                },
              ),
            ),
          if (!_isLoading &&
              _errorMessage == null &&
              _videoDurationMs >= _kMinTrimDurationMs)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                'Minimum trim length: 5 seconds',
                style: TextStyles.medium(
                  12.sp,
                  fontColor: AppColors.gray8C9499,
                ),
              ),
            )
          else if (!_isLoading &&
              _errorMessage == null &&
              _videoDurationMs > 0 &&
              _videoDurationMs < _kMinTrimDurationMs)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                'This video is shorter than 5 seconds.',
                style: TextStyles.medium(
                  12.sp,
                  fontColor: AppColors.gray8C9499,
                ),
              ),
            ),
          Gap(20.h),
        ],
      ),
    );
  }
}

/// Loading state while the trim sheet copies the file, initializes playback, and builds thumbnails.
class _VideoPreparingPlaceholder extends StatefulWidget {
  const _VideoPreparingPlaceholder();

  @override
  State<_VideoPreparingPlaceholder> createState() =>
      _VideoPreparingPlaceholderState();
}

class _VideoPreparingPlaceholderState extends State<_VideoPreparingPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _fade = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulse.value,
                  child: Opacity(
                    opacity: _fade.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.all(28.w),
                decoration: BoxDecoration(
                  color: AppColors.orangeF8F1EB,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  size: 44.sp,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            Gap(28.h),
            SizedBox(
              width: 40.w,
              height: 40.w,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primaryColor,
              ),
            ),
            Gap(20.h),
            Text(
              'Preparing your video',
              textAlign: TextAlign.center,
              style: TextStyles.semiBold(
                17.sp,
                fontColor: AppColors.black141414,
              ),
            ),
            Gap(8.h),
            Text(
              'Hang tight — loading preview and timeline',
              textAlign: TextAlign.center,
              style: TextStyles.medium(
                13.sp,
                fontColor: AppColors.gray8C9499,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoMusicSelectionBottomSheet extends StatefulWidget {
  final File? videoFile;
  final AssetEntity? videoAsset;
  final String audioUrl;

  /// Track id from `zeals/music` (POST `/zeals` `musicId`).
  final String musicId;
  final String musicTitle;
  final String musicArtist;
  final String albumArtUrl;
  final bool isRecordedVideo;
  final int videoDurationInMs;
  final VoidCallback? onMusicApplied;

  const VideoMusicSelectionBottomSheet({
    super.key,
    required this.audioUrl,
    required this.musicId,
    required this.videoDurationInMs,
    required this.musicTitle,
    required this.musicArtist,
    this.albumArtUrl = '',
    this.videoFile,
    this.videoAsset,
    this.isRecordedVideo = false,
    this.onMusicApplied,
  });

  static void show({
    required String audioUrl,
    required String musicId,
    required int videoDurationInMs,
    required String musicTitle,
    required String musicArtist,
    String albumArtUrl = '',
    File? videoFile,
    AssetEntity? videoAsset,
    bool isRecordedVideo = false,
    VoidCallback? onMusicApplied,
  }) {
    Get.bottomSheet(
      VideoMusicSelectionBottomSheet(
        audioUrl: audioUrl,
        musicId: musicId,
        videoDurationInMs: videoDurationInMs,
        musicTitle: musicTitle,
        musicArtist: musicArtist,
        albumArtUrl: albumArtUrl,
        videoFile: videoFile,
        videoAsset: videoAsset,
        isRecordedVideo: isRecordedVideo,
        onMusicApplied: onMusicApplied,
      ),
      isScrollControlled: true,
      backgroundColor: AppColors.transparentColor,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  State<VideoMusicSelectionBottomSheet> createState() =>
      _VideoMusicSelectionBottomSheetState();
}

class _VideoMusicSelectionBottomSheetState
    extends State<VideoMusicSelectionBottomSheet>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;
  SelectedMusicSheetController? _musicController;
  late int _effectiveVideoDurationInMs;
  bool _wasPlayingBeforePause = false;
  bool _audioLoading = true;
  String? _audioError;
  String? _localAudioPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effectiveVideoDurationInMs = widget.videoDurationInMs;
    // Video duration must be known before building the waveform; otherwise segment length
    // sticks to a stale estimate (e.g. 30s default) and never matches the real clip.
    Future(() async {
      await _initializeVideo();
      if (!mounted) return;
      await _prepareAudioAndMusicController();
    });
  }

  Future<void> _prepareAudioAndMusicController() async {
    setState(() {
      _audioLoading = true;
      _audioError = null;
    });
    final file = await AudioFileHelper.ensureLocalAudioFile(widget.audioUrl);
    if (!mounted) return;
    if (file == null) {
      setState(() {
        _audioLoading = false;
        _audioError =
            'Could not load music. Check your connection and try again.';
      });
      return;
    }
    _localAudioPath = file.path;
    final videoMsForWaves = _effectiveVideoDurationInMs > 0
        ? _effectiveVideoDurationInMs
        : widget.videoDurationInMs;
    _musicController = SelectedMusicSheetController(
      videoMsForWaves,
      SelectedMusic(0, file.path, videoMsForWaves, musicId: widget.musicId),
    );
    await _musicController!.initPlayer();
    await _ensureWaveSliderReady();
    if (_videoController != null && _videoController!.value.isInitialized) {
      final d = _videoController!.value.duration.inMilliseconds;
      if (d > 0 && d != _effectiveVideoDurationInMs) {
        _effectiveVideoDurationInMs = d;
        Get.find<CreatePostController>().videoDurationInMs = d;
        _musicController?.updateVideoDuration(d);
      }
    }
    if (!mounted) return;
    setState(() {
      _audioLoading = false;
    });
  }

  Future<void> _retryAudioLoad() async {
    _musicController?.onClose();
    _musicController = null;
    _localAudioPath = null;
    await _prepareAudioAndMusicController();
  }

  Future<void> _ensureWaveSliderReady() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final mc = _musicController;
    if (mc == null) return;
    final duration = mc.durationInMilliSec.value;
    if (duration == null ||
        duration.isNaN ||
        duration.isInfinite ||
        duration <= 0 ||
        mc.waves.isEmpty) {
      _seedFallbackWaves(_effectiveVideoDurationInMs, mc);
      return;
    }
  }

  void _seedFallbackWaves(
    int targetDurationMs,
    SelectedMusicSheetController mc,
  ) {
    mc.waves.clear();
    mc.durationInMilliSec.value = targetDurationMs;
    mc.oneBarValue = (mc.barInBoxCount / (targetDurationMs / 1000));
    final totalBars = (mc.oneBarValue * (targetDurationMs / 1000)).floor();
    final n = totalBars < 1 ? 1 : totalBars;
    for (var i = 0; i < n; i++) {
      mc.waves.add(i.toDouble());
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.videoFile != null) {
        _videoController = VideoPlayerController.file(
          widget.videoFile!,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        _videoController?.setVolume(0.0);
      } else if (widget.videoAsset != null) {
        final file = await widget.videoAsset!.file;
        if (file != null) {
          _videoController = VideoPlayerController.file(
            file,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          _videoController?.setVolume(0.0);
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = 'Failed to load video file';
          });
          return;
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'No video provided';
        });
        return;
      }

      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = false;
        });
        final actualDurationMs =
            _videoController!.value.duration.inMilliseconds;
        if (actualDurationMs > 0 &&
            actualDurationMs != _effectiveVideoDurationInMs) {
          _effectiveVideoDurationInMs = actualDurationMs;
          Get.find<CreatePostController>().videoDurationInMs = actualDurationMs;
          _musicController?.updateVideoDuration(actualDurationMs);
          setState(() {});
        }
        _videoController!.setLooping(true);
        _videoController!.addListener(_videoListener);
        _videoController!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  void _videoListener() {
    if (_videoController != null && mounted) {
      final isPlaying = _videoController!.value.isPlaying;
      if (_isPlaying != isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isInitialized) return;

    if (_isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _musicController?.safeDispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _wasPlayingBeforePause = _musicController?.isPlaying.value ?? false;
      _videoController?.pause();
      _musicController?.onPause();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        _musicController?.onPlayAudio();
      }
      _wasPlayingBeforePause = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * 0.9,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.h),
            height: 5.w,
            width: 55.w,
            decoration: BoxDecoration(
              color: AppColors.grayEDF1F4,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          Gap(16.h),
          Row(
            children: [
              Gap(7.w),
              GestureDetector(
                onTap: () async {
                  await _musicController?.onPause();
                  Get.back();
                },
                child: Assets.icons.icArrowBack.image(scale: 3.5),
              ),
              Spacer(),
              if (widget.isRecordedVideo)
                GestureDetector(
                  onTap: () {
                    _showDiscardDialog();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orangeDA7000,
                      borderRadius: BorderRadius.circular(51.r),
                    ),
                    child: Text(
                      'Discard',
                      style: TextStyles.medium(
                        16.sp,
                        fontColor: AppColors.whiteFFFFFF,
                      ),
                    ),
                  ),
                ),
              Gap(15.w),
              GestureDetector(
                onTap: () {
                  if (_audioLoading ||
                      _musicController == null ||
                      _audioError != null) {
                    return;
                  }
                  _applySelectedMusic();
                },
                child: Text(
                  'Next',
                  style: TextStyles.medium(
                    16.sp,
                    fontColor:
                        (_audioLoading ||
                            _musicController == null ||
                            _audioError != null)
                        ? AppColors.gray8C9499
                        : AppColors.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          Gap(20.h),
          Expanded(
            child: SizedBox(
              height: Get.height * 0.5,
              width: double.infinity,
              child: _buildVideoPreview(),
            ),
          ),
          Gap(27.h),
          _buildMusicWaveSection(),
          Gap(35.h),
        ],
      ),
    );
  }

  Widget _buildMusicWaveSection() {
    if (_audioError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Column(
          children: [
            Text(
              _audioError!,
              textAlign: TextAlign.center,
              style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070),
            ),
            Gap(12.h),
            TextButton(
              onPressed: _audioLoading ? null : _retryAudioLoad,
              child: Text(
                'Retry',
                style: TextStyles.bold(
                  16.sp,
                  fontColor: AppColors.primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_audioLoading || _musicController == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            Gap(12.h),
            Text(
              'Loading music…',
              style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070),
            ),
          ],
        ),
      );
    }
    final c = _musicController!;
    return Obx(() {
      final duration = c.durationInMilliSec.value;
      if (duration == null ||
          duration.isNaN ||
          duration.isInfinite ||
          duration <= 0) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              Gap(8.h),
              Text(
                'Preparing waveform…',
                style: TextStyles.medium(
                  12.sp,
                  fontColor: AppColors.gray8C9499,
                ),
              ),
            ],
          ),
        );
      }
      return WaveSlider(controller: c);
    });
  }

  void _applySelectedMusic() {
    final mc = _musicController;
    final path = _localAudioPath;
    if (mc == null || path == null || path.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Music is still loading',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    final controller = Get.find<CreatePostController>();
    controller.videoDurationInMs = _effectiveVideoDurationInMs;
    final segmentMs = mc.videoDurationInMs;
    final audioDurationMs = mc.durationInMilliSec.value ?? segmentMs;
    final maxStart = (audioDurationMs - segmentMs).clamp(0, audioDurationMs);
    final startMs = maxStart > 0
        ? mc.audioStartInMilliSec.value.clamp(0, maxStart).toInt()
        : 0;
    final endMs = startMs + segmentMs;
    controller.selectedMusic = SelectedMusic(
      startMs,
      path,
      endMs,
      musicId: widget.musicId,
    );
    controller.confirmedMusic = SelectedMusic(
      startMs,
      path,
      endMs,
      musicId: widget.musicId,
    );
    controller.musicTitle = widget.musicTitle;
    controller.musicArtist = widget.musicArtist;
    controller.musicAlbumArtUrl =
        widget.albumArtUrl.isNotEmpty ? widget.albumArtUrl : null;
    controller.update();
    mc.onPause();
    widget.onMusicApplied?.call();
    Get.back();
    Future.microtask(() => controller.update());
  }

  void _showDiscardDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.whiteFFFFFF,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Discard Video?',
          style: TextStyles.bold(18.sp, fontColor: AppColors.black2F3039),
        ),
        content: Text(
          'Are you sure you want to discard this video? This action cannot be undone.',
          style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyles.medium(16.sp, fontColor: AppColors.gray8C9499),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.back();
              final controller = Get.find<CreatePostController>();
              controller.discardRecordedVideo();
            },
            child: Text(
              'Discard',
              style: TextStyles.medium(16.sp, fontColor: AppColors.redFF5353),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: AppColors.gray8C9499),
            Gap(16.h),
            Text(
              _errorMessage ?? 'Failed to load video',
              style: TextStyles.medium(16.sp, fontColor: AppColors.gray8C9499),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _videoController == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.orangeDA7000),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              color: AppColors.transparentColor,
              alignment: Alignment.center,
              child: _isPlaying
                  ? const SizedBox.shrink()
                  : Container(
                      width: 68.w,
                      height: 68.w,
                      decoration: BoxDecoration(
                        color: AppColors.black000000.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.white,
                        size: 50.sp,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
