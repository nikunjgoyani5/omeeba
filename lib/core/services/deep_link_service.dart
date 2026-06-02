import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/presentation/main/zeals/views/zeal_detail_screen.dart';

/// Handles https://…/share/... links on Omeeba domains (App Links / Universal Links).
/// Pending links are delivered after login via [handlePendingShareLinkIfAny] from the dashboard.
class DeepLinkService {
  DeepLinkService._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _uriSubscription;

  /// Cold start / pre-login: wait until [handlePendingShareLinkIfAny].
  static _PendingShare? _pendingShare;

  static bool _isLoggedIn() {
    return PrefService.getString(PrefKeys.accessToken).isNotEmpty &&
        PrefService.getBool(PrefKeys.isLogin) == true;
  }

  static bool _shouldQueueForLater() {
    if (!_isLoggedIn()) return true;
    // Main shell registers this; avoids navigating before [DashboardBinding] runs.
    if (!Get.isRegistered<NotificationRepository>()) return true;
    final route = Get.currentRoute;
    if (route.isEmpty ||
        route == '/' ||
        route == AppRoutes.initial ||
        route.toLowerCase().contains('splash')) {
      return true;
    }
    if (route == AppRoutes.login ||
        route == AppRoutes.signUp ||
        route == AppRoutes.forgotPassword) {
      return true;
    }
    return false;
  }

  /// Parses supported share URLs:
  /// - /share/post/{id}
  /// - /share/write-post/{id}
  /// - /share/poll/{id}
  /// - /share/zeal/{id}
  static bool _isOmeebaShareHost(String host) {
    const allowed = {
      'omeeba.app',
      'www.omeeba.app',
      'omeeba.co.in',
      'www.omeeba.co.in',
    };
    return allowed.contains(host.toLowerCase());
  }

  static _PendingShare? _parseShareUri(Uri uri) {
    if (!_isOmeebaShareHost(uri.host)) return null;

    final segments =
        uri.pathSegments.where((s) => s.isNotEmpty).map((s) => s.toLowerCase()).toList();
    if (segments.length < 3) return null;
    if (segments[0] != 'share') return null;

    final typeSegment = segments[1];
    final id = segments[2];
    if (id.isEmpty) return null;

    String contentType;
    switch (typeSegment) {
      case 'post':
        contentType = 'post';
        break;
      case 'write-post':
        contentType = 'write';
        break;
      case 'poll':
        contentType = 'poll';
        break;
      case 'zeal':
        contentType = 'zeal';
        break;
      default:
        return null;
    }
    return _PendingShare(contentId: id, contentType: contentType);
  }

  static void _navigateForShare(_PendingShare share) {
    if (share.contentId.isEmpty) return;

    if (share.contentType == 'zeal') {
      Get.to(
        () => const ZealDetailScreen(),
        arguments: <String, dynamic>{'contentId': share.contentId},
      );
      return;
    }

    final args = <String, dynamic>{
      'contentId': share.contentId,
      'contentType': share.contentType,
    };

    final onPostDetail = Get.currentRoute == AppRoutes.postContentDetail;
    if (onPostDetail) {
      Get.offNamed(AppRoutes.postContentDetail, arguments: args);
    } else {
      Get.toNamed(AppRoutes.postContentDetail, arguments: args);
    }
  }

  static void _dispatchUri(Uri uri) {
    final parsed = _parseShareUri(uri);
    if (parsed == null) return;

    if (_shouldQueueForLater()) {
      _pendingShare = parsed;
      return;
    }
    _navigateForShare(parsed);
  }

  /// Call from [main] after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> initialize() async {
    await _subscribeToStream();

    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dispatchUri(initial);
      });
    }
  }

  static Future<void> _subscribeToStream() async {
    await _uriSubscription?.cancel();
    _uriSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _dispatchUri(uri);
        });
      },
      onError: (_) {},
    );
  }

  /// Invoke after the user reaches the main shell (e.g. dashboard [onReady]),
  /// after [OneSignalNotificationService.handlePendingNotificationIfAny].
  static void handlePendingShareLinkIfAny() {
    final pending = _pendingShare;
    if (pending == null) return;
    if (!_isLoggedIn()) return;
    _pendingShare = null;
    _navigateForShare(pending);
  }
}

class _PendingShare {
  _PendingShare({required this.contentId, required this.contentType});

  final String contentId;
  final String contentType;
}
