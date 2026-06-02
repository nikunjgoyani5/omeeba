import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';

/// Network quality for adaptive video: preload count and optional quality URL selection.
enum NetworkQuality {
  fast,
  medium,
  slow,
}

/// Estimates network quality (connection type + optional speed test) so zeal videos
/// can adapt: e.g. fewer preloads on slow networks, and lower quality URL when available.
class NetworkQualityService extends GetxService {
  static const _cacheValidDuration = Duration(minutes: 2);
  static const _speedTestBytes = 51200; // 50 KB
  static const _fastSpeedBps = 500000; // 500 KB/s
  static const _slowSpeedBps = 100000; // 100 KB/s

  final Rx<NetworkQuality> quality = NetworkQuality.medium.obs;
  DateTime? _lastChecked;
  bool _checkRunning = false;

  NetworkQuality get currentQuality => quality.value;
  bool get isFast => quality.value == NetworkQuality.fast;
  bool get isSlow => quality.value == NetworkQuality.slow;
  bool get isMedium => quality.value == NetworkQuality.medium;

  /// Number of next videos to preload (0, 1, or 2) based on network.
  int get preloadCount {
    switch (quality.value) {
      case NetworkQuality.fast:
        return 2;
      case NetworkQuality.medium:
        return 1;
      case NetworkQuality.slow:
        return 0;
    }
  }

  /// Prefer high-quality URL on fast, low-quality on slow. Returns the best URL for current network.
  String? getPreferredMediaUrl(PostData? post) {
    if (post == null) return null;
    final high = post.mediaUrlHigh ?? post.mediaUrl;
    final low = post.mediaUrlLow;
    final fallback = post.mediaUrl ?? high;
    if (high == null && low == null) return fallback;
    switch (quality.value) {
      case NetworkQuality.fast:
        return high ?? fallback;
      case NetworkQuality.slow:
        return (low != null && low.isNotEmpty) ? low : fallback;
      case NetworkQuality.medium:
        return high ?? low ?? fallback;
    }
  }

  /// Call when Zeals tab is shown or periodically. Updates quality from connection type
  /// and optionally runs a quick speed test if a test URL is provided.
  Future<void> updateQuality({String? speedTestUrl}) async {
    if (_checkRunning) return;
    _checkRunning = true;
    try {
      final results = await Connectivity().checkConnectivity();
      final hasWifi = results.any((r) =>
          r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
      final hasMobile = results.any((r) => r == ConnectivityResult.mobile);
      final hasNone = results.isEmpty ||
          results.any((r) => r == ConnectivityResult.none);

      if (hasNone || (!hasWifi && !hasMobile)) {
        quality.value = NetworkQuality.slow;
        _lastChecked = DateTime.now();
        return;
      }

      if (hasWifi && !hasMobile) {
        quality.value = NetworkQuality.fast;
        _lastChecked = DateTime.now();
        return;
      }

      if (speedTestUrl != null &&
          speedTestUrl.isNotEmpty &&
          (_lastChecked == null ||
              DateTime.now().difference(_lastChecked!) > _cacheValidDuration)) {
        final measured = await _measureSpeed(speedTestUrl);
        if (measured != null) {
          if (measured >= _fastSpeedBps) {
            quality.value = NetworkQuality.fast;
          } else if (measured >= _slowSpeedBps) {
            quality.value = NetworkQuality.medium;
          } else {
            quality.value = NetworkQuality.slow;
          }
          _lastChecked = DateTime.now();
          return;
        }
      }

      if (hasMobile && !hasWifi) {
        quality.value = NetworkQuality.medium;
        _lastChecked = DateTime.now();
      }
    } finally {
      _checkRunning = false;
    }
  }

  Future<double?> _measureSpeed(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Range', 'bytes=0-${_speedTestBytes - 1}');
      final stopwatch = Stopwatch()..start();
      final response = await request.close();
      int received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        if (received >= _speedTestBytes) break;
      }
      stopwatch.stop();
      client.close();
      if (stopwatch.elapsedMilliseconds <= 0) return null;
      final bps = received * 1000 / stopwatch.elapsedMilliseconds;
      return bps;
    } catch (_) {
      return null;
    }
  }

  /// Invalidate cache so next updateQuality runs a fresh check.
  void invalidateCache() {
    _lastChecked = null;
  }
}