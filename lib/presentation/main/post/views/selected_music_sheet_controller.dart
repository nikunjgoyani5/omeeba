import 'dart:async';
import 'dart:math' as math;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/widgets/debounce_action.dart';

class SelectedMusicSheetController extends GetxController {
  /// Full source video length (ms). Does not shrink when music is shorter.
  int fullVideoDurationInMs;

  /// Waveform “clip” length = `min(fullVideoDurationInMs, musicDurationMs)` after audio loads.
  int videoDurationInMs;
  SelectedMusic selectedMusic;

  PlayerController audioPlayer = PlayerController();
  Rx<int?> durationInMilliSec = Rx(null);
  Rx<int> audioStartInMilliSec = Rx(0);

  RxBool isPlaying = false.obs;
  Timer? _segmentLoopTimer;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _completionSubscription;

  SelectedMusicSheetController(
    int initialVideoDurationMs,
    this.selectedMusic,
  )   : fullVideoDurationInMs = initialVideoDurationMs,
        videoDurationInMs = initialVideoDurationMs;

  ScrollController scrollController = ScrollController();
  RxList<double> waves = RxList();
  double oneBarValue = 0;
  final double borderWidth = 10;
  final double barWidth = 2;
  final double barHorizontalMargin = 1;
  final double barInBoxCount = 30;
  RxDouble currentProgress = 0.0.obs;
  RxDouble scrollOffset = 0.0.obs;
  bool _isAdjustingScroll = false;
  bool _isPreparing = false;
  bool _segmentLoopInFlight = false;
  bool _disposed = false;
  int _initialScrollAttachAttempts = 0;
  static const int _maxInitialScrollAttachAttempts = 50;

  double get barTotalWidth => barWidth + (barHorizontalMargin * 2);

  double get boxWidth => barTotalWidth * barInBoxCount;

  int get previousBar => (scrollOffset.value / barTotalWidth).toInt();

  int get currentBars => (previousBar + (currentProgress.value * barInBoxCount)).toInt();

  /// Max horizontal scroll (px) so the clip window stays within the track.
  double get maxScrollOffsetPx {
    final d = durationInMilliSec.value;
    if (d == null || d <= 0) return 0;
    final maxStartMs = (d - videoDurationInMs).clamp(0, d);
    final px = (maxStartMs / 1000) * barTotalWidth * oneBarValue;
    if (px.isNaN || px.isInfinite || px < 0) return 0;
    return px;
  }

  /// Latest moment (ms) where clip can start (track end − clip length).
  int get maxSelectableStartMs {
    final d = durationInMilliSec.value;
    if (d == null || d <= 0) return 0;
    return (d - videoDurationInMs).clamp(0, d);
  }

  @override
  void onClose() {
    safeDispose();
    super.onClose();
  }

  /// Manual lifecycle for controllers created with `SelectedMusicSheetController(...)`
  /// (not put into GetX dependency tree). Safe to call multiple times.
  void safeDispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _segmentLoopTimer?.cancel();
    _positionSubscription?.cancel();
    _completionSubscription?.cancel();
    scrollController.removeListener(_onScrollCombined);
    scrollController.dispose();
    isPlaying.value = false;
    // Plugin may throw on stop/release/dispose if codec was already released by Android.
    // Never let teardown exceptions bubble and crash the app.
    unawaited(audioPlayer.stopPlayer().catchError((_) {}));
    try {
      audioPlayer.release();
    } catch (_) {}
  }

  Future<void> initPlayer() async {
    if (_isPreparing || _disposed) return;
    _isPreparing = true;
    debugPrint('SelectedMusic: full video (s): ${fullVideoDurationInMs / 1000}');
    debugPrint('SelectedMusic: ${selectedMusic.toJson()}');
    try {
      if ((selectedMusic.downloadedURL ?? '').isEmpty) {
        return;
      }
      await audioPlayer.preparePlayer(path: selectedMusic.downloadedURL ?? '');
      if (_disposed) return;
      await audioPlayer.seekTo(selectedMusic.audioStartMS ?? 0);
      audioStartInMilliSec.value = selectedMusic.audioStartMS ?? 0;

      // Player may report -1 until metadata is ready (audio_waveforms API, ms).
      var rawMs = await audioPlayer.getDuration();
      if (rawMs < 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        rawMs = await audioPlayer.getDuration();
      }
      durationInMilliSec.value = rawMs > 0 ? rawMs : null;
      _syncSegmentDuration();
      oneBarValue = (barInBoxCount / (videoDurationInMs / 1000));
      _rebuildWaves();
      if (_disposed) return;
      scrollController.removeListener(_onScrollCombined);
      scrollController.addListener(_onScrollCombined);
      _initialScrollAttachAttempts = 0;
      DebounceAction.shared.call(_tryInitialScrollAndPlay);
    } catch (e) {
      debugPrint('SelectedMusic: error loading audio: $e');
    } finally {
      _isPreparing = false;
    }
  }

  /// [ScrollController.animateTo] requires an attached [Scrollable]. The debounced
  /// [initPlayer] callback can run before the waveform builds — retry next frame.
  void _tryInitialScrollAndPlay() {
    if (_disposed) return;
    if (!scrollController.hasClients) {
      _initialScrollAttachAttempts++;
      if (_initialScrollAttachAttempts > _maxInitialScrollAttachAttempts) {
        debugPrint(
          'SelectedMusic: scroll view not attached after $_maxInitialScrollAttachAttempts frames, skipping initial scroll',
        );
        playPause();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryInitialScrollAndPlay());
      return;
    }
    final target =
        ((selectedMusic.audioStartMS ?? 0) / 1000) * barTotalWidth * oneBarValue;
    // Avoid ballistic animation during first attach; a direct jump is safer when
    // waveform/layout just mounted and scroll extents can still settle.
    scrollController.jumpTo(math.min(target, maxScrollOffsetPx));
    playPause();
  }

  /// Waveform segment length = `min(fullVideoDurationInMs, music track length)`.
  void _syncSegmentDuration() {
    final m = durationInMilliSec.value;
    if (m != null && m > 0) {
      final seg = math.min(fullVideoDurationInMs, m);
      videoDurationInMs = seg < 1 ? 1 : seg;
    } else {
      final v = fullVideoDurationInMs;
      videoDurationInMs = v < 1 ? 1 : v;
    }
  }

  void updateVideoDuration(int newDurationMs) {
    if (newDurationMs <= 0) return;
    fullVideoDurationInMs = newDurationMs;
    _syncSegmentDuration();
    oneBarValue = (barInBoxCount / (videoDurationInMs / 1000));
    _rebuildWaves();
    final d = durationInMilliSec.value;
    if (d != null && d > 0) {
      audioStartInMilliSec.value = audioStartInMilliSec.value.clamp(0, (d - videoDurationInMs).clamp(0, d));
    }
    _clampScrollToValidRange();
    if (scrollController.hasClients && oneBarValue > 0) {
      _isAdjustingScroll = true;
      scrollController.jumpTo((audioStartInMilliSec.value / 1000) * barTotalWidth * oneBarValue);
      scrollOffset.value = scrollController.offset;
      _isAdjustingScroll = false;
    }
    if (isPlaying.value) {
      _segmentLoopTimer?.cancel();
      _scheduleSegmentLoopTimer();
    }
  }

  void _rebuildWaves() {
    waves.clear();
    final durationMs = durationInMilliSec.value ?? 0;
    if (durationMs <= 0 || oneBarValue <= 0) return;
    // One bar per barTotalWidth; floor so total width ≤ track — UI adds trailing spacer to exact [waveTrackWidthPx].
    final exactBars = oneBarValue * (durationMs / 1000.0);
    final n = math.max(1, exactBars.floor());
    for (var i = 0; i < n; i++) {
      waves.add(i.toDouble());
    }
  }

  /// Pixel width of the full audio track (matches scroll ↔ time mapping).
  double get waveTrackWidthPx {
    final d = durationInMilliSec.value;
    if (d == null || d <= 0 || oneBarValue <= 0) return 0;
    return (d / 1000.0) * barTotalWidth * oneBarValue;
  }

  void _clampScrollToValidRange() {
    if (!scrollController.hasClients) return;
    final maxOffset = maxScrollOffsetPx;
    final clamped = scrollController.offset.clamp(0.0, maxOffset);
    if ((clamped - scrollController.offset).abs() < 0.5) return;
    // Run after current frame so we don't mutate position while ScrollActivity
    // is in its own tick (can assert in Flutter internals).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !scrollController.hasClients) return;
      final latestMax = maxScrollOffsetPx;
      final latest = scrollController.offset.clamp(0.0, latestMax);
      if ((latest - scrollController.offset).abs() >= 0.5) {
        scrollController.jumpTo(latest);
      }
    });
  }

  void _onScrollCombined() {
    if (scrollController.hasClients) {
      final so = scrollController.offset.clamp(0.0, maxScrollOffsetPx).toDouble();
      scrollOffset.value = so;
    }
    _onScroll();
  }

  void _onScroll() {
    if (_disposed) return;
    if (_isAdjustingScroll) {
      return;
    }
    currentProgress.value = 0.0;
    if (isPlaying.value == true) {
      onPause();
    } else {
      DebounceAction.shared.call(() async {
        if (_disposed) return;
        final durationMs = durationInMilliSec.value;
        if (durationMs != null && durationMs > 0) {
          final maxStart = maxSelectableStartMs;
          final so = scrollController.offset.clamp(0.0, maxScrollOffsetPx).toDouble();
          final rawSec = ((so / barTotalWidth) / oneBarValue).floor();
          var startMs = rawSec * 1000;
          startMs = startMs.clamp(0, maxStart);
          audioStartInMilliSec.value = startMs;
          scrollOffset.value = so.toDouble();
          onPlayAudio();
        }
      });
    }
  }

  Future<void> playPause() async {
    (isPlaying.value) ? await onPause() : await onPlayAudio();
  }

  void _attachPlaybackListeners() {
    _positionSubscription?.cancel();
    _completionSubscription?.cancel();
    currentProgress.value = 0.0;

    _positionSubscription = audioPlayer.onCurrentDurationChanged.listen((event) {
      final rel = (event.milliseconds.inMilliseconds + 100) - audioStartInMilliSec.value;
      currentProgress.value = (rel / videoDurationInMs).clamp(0.0, 1.0);
    });

    _completionSubscription = audioPlayer.onCompletion.listen((_) async {
      if (!isPlaying.value) return;
      _segmentLoopTimer?.cancel();
      await _loopSegmentFromStart();
    });
  }

  /// Repeats the [videoDurationInMs] window while the user stays in music selection.
  Future<void> _loopSegmentFromStart() async {
    if (!isPlaying.value || _segmentLoopInFlight) return;
    _segmentLoopTimer?.cancel();
    _segmentLoopInFlight = true;
    try {
      await audioPlayer.seekTo(audioStartInMilliSec.value);
      currentProgress.value = 0.0;
      await audioPlayer.startPlayer();
      audioPlayer.setFinishMode(finishMode: FinishMode.pause);
      _scheduleSegmentLoopTimer();
    } catch (e) {
      debugPrint('SelectedMusic: loop segment error: $e');
    } finally {
      _segmentLoopInFlight = false;
    }
  }

  void _scheduleSegmentLoopTimer() {
    _segmentLoopTimer?.cancel();
    if (videoDurationInMs <= 0) return;
    _segmentLoopTimer = Timer(Duration(milliseconds: videoDurationInMs), () async {
      if (!isPlaying.value) return;
      await _loopSegmentFromStart();
    });
  }

  Future<void> onPlayAudio() async {
    if (_disposed) return;
    _attachPlaybackListeners();
    try {
      await audioPlayer.seekTo(audioStartInMilliSec.value);
      if (_disposed) return;
      await audioPlayer.startPlayer();
      audioPlayer.setFinishMode(finishMode: FinishMode.pause);

      isPlaying.value = true;
      _scheduleSegmentLoopTimer();
    } catch (e) {
      debugPrint('SelectedMusic: onPlay error: $e');
    }
  }

  Future<void> onPause() async {
    if (_disposed) return;
    try {
      _segmentLoopTimer?.cancel();
      await audioPlayer.pausePlayer();
      await _positionSubscription?.cancel();
      await _completionSubscription?.cancel();
      _positionSubscription = null;
      _completionSubscription = null;
      isPlaying.value = false;
    } catch (e) {
      debugPrint('SelectedMusic: onPause error: $e');
    }
  }
}

class SelectedMusic {
  int? audioStartMS;
  String? downloadedURL;
  int? endMilliSec;

  /// Library track id from `zeals/music` when user picks a song (POST zeal `musicId`).
  String? musicId;

  SelectedMusic(
    this.audioStartMS,
    this.downloadedURL,
    this.endMilliSec, {
    this.musicId,
  });

  Map<String, dynamic> toJson() {
    return {
      'downloadedURL': downloadedURL,
      'audioStartMS': audioStartMS,
      'endMilliSec': endMilliSec,
      'musicId': musicId,
    };
  }
}
