import 'dart:convert';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/utils/app_constant.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/presentation/main/notification/controller/notification_controller.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalNotificationService {
  OneSignalNotificationService._();

  static final OneSignalNotificationService _instance =
      OneSignalNotificationService._();
  static OneSignalNotificationService get instance => _instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ── Pending payload for cold start (app killed → tap notification) ────────
  static Map<String, dynamic>? _pendingNotificationPayload;
  static DateTime _lastForegroundNotificationsRefreshAt =
      DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> initialize({String? oneSignalAppId}) async {
    final appId = oneSignalAppId ?? oneSignalAppIdConstant;
    if (appId.isEmpty || appId == 'YOUR_ONESIGNAL_APP_ID') {
      log('OneSignal App ID not set.');
      return;
    }

    if (_instance._initialized) {
      log('OneSignal already initialized.');
      return;
    }

    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);

      _setupForegroundDisplayListener();
      _setupNotificationClickListener();
      _setupOneSignalIdAndSubscription();

      await OneSignal.Notifications.requestPermission(false);

      _instance._initialized = true;
      log('OneSignal initialized successfully.');
    } catch (e, st) {
      log('OneSignal init error: $e\n$st');
    }
  }

  /// NEW: Attempt to get notification that launched the app (cold start)

  static String get oneSignalAppIdConstant =>
      oneSignalAppId; // assuming defined in constants

  static void _setupForegroundDisplayListener() {
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
      _maybeRefreshNotificationsForUnreadBadge();
    });
  }

  /// Keeps the notification list + unread badge accurate for
  /// foreground pushes.
  static void _maybeRefreshNotificationsForUnreadBadge() {
    if (!Get.isRegistered<NotificationController>()) return;

    final now = DateTime.now();
    // Throttle to avoid multiple API calls for a burst of pushes.
    if (now.difference(_lastForegroundNotificationsRefreshAt) <
        const Duration(seconds: 15))
      return;

    _lastForegroundNotificationsRefreshAt = now;
    // ignore: unawaited_futures
    Get.find<NotificationController>().loadNotifications();
  }

  static void _setupNotificationClickListener() {
    OneSignal.Notifications.addClickListener((OSNotificationClickEvent event) {
      _handleNotificationClick(event.notification, event.result);
    });
  }

  static void _handleNotificationClick(
    OSNotification? notification,
    OSNotificationClickResult? result,
  ) {
    if (notification == null) return;

    debugPrint(
      "Notification clicked → rawPayload: ${notification.additionalData}",
    );
    debugPrint("Click result: $result");

    final additionalData = notification.additionalData;
    if (additionalData == null || additionalData.isEmpty) {
      log('Notification clicked but no additionalData');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final payload = _normalizePayload(
          Map<String, dynamic>.from(additionalData),
        );
        log('Notification payload: ${jsonEncode(payload)}');

        final currentRoute = Get.currentRoute;
        final isLikelyColdStart =
            currentRoute.isEmpty ||
            currentRoute == '/' ||
            currentRoute == AppRoutes.initial ||
            currentRoute.contains('splash');

        if (isLikelyColdStart) {
          _pendingNotificationPayload = payload;
          log('Cold start / early stage → stored pending payload');
        } else {
          // Ensure the unread badge/list stay accurate after a click-driven navigation.
          _maybeRefreshNotificationsForUnreadBadge();
          // App already running → handle now
          NotificationController.navigateFromOneSignalPayload(
            payload,
            onPost: (post, contentType, commentId) async {
              String contentId = post.id ?? '';
              if (contentId.isEmpty) return;

              if (Get.currentRoute == AppRoutes.postContentDetail) {
                Get.offNamed(
                  AppRoutes.postContentDetail,
                  arguments: {
                    'contentId': contentId,
                    'contentType': contentType,
                    'commentId': commentId,
                  },
                );
              } else {
                Get.toNamed(
                  AppRoutes.postContentDetail,
                  arguments: {
                    'contentId': contentId,
                    'contentType': contentType,
                    'commentId': commentId,
                  },
                );
              }
            },
            onZeal: (post, contentType, commentId) {
              String contentId = post.id ?? '';
              if (contentId.isEmpty) return;
              if (Get.currentRoute == AppRoutes.postContentDetail) {
                Get.offNamed(
                  AppRoutes.postContentDetail,
                  arguments: {
                    'contentId': contentId,
                    'contentType': contentType,
                    'commentId': commentId,
                  },
                );
              } else {
                Get.toNamed(
                  AppRoutes.postContentDetail,
                  arguments: {
                    'contentId': contentId,
                    'contentType': contentType,
                    'commentId': commentId,
                  },
                );
              }
            },
            onProfile: (userId) {
              if (Get.currentRoute == AppRoutes.otherUserProfile) {
                Get.offNamed(AppRoutes.otherUserProfile, arguments: userId);
              } else {
                Get.toNamed(AppRoutes.otherUserProfile, arguments: userId);
              }
            },
          );
        }
      } catch (e, st) {
        log('Notification click handling error: $e\n$st');
      }
    });
  }

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    final query = map['query'];
    if (query is String && query.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(query);
        if (decoded is Map<String, dynamic>) {
          map['query'] = decoded;
        }
      } catch (_) {}
    }
    return map;
  }

  // ── Rest of your code remains mostly unchanged ────────────────────────
  static void handlePendingNotificationIfAny() {
    if (_pendingNotificationPayload == null) return;

    final payload = _pendingNotificationPayload!;
    _pendingNotificationPayload = null;

    NotificationController.navigateFromOneSignalPayload(
      payload,
      onPost: (post, contentType, commentId) {
        final contentId = post.id ?? '';
        if (contentId.isEmpty) return;

        Get.toNamed(
          AppRoutes.postContentDetail,
          arguments: {
            'contentId': contentId,
            'contentType': contentType,
            'commentId': commentId,
          },
        );
      },
      onZeal: (post, contentType, commentId) {
        final contentId = post.id ?? '';
        if (contentId.isEmpty) return;

        Get.toNamed(
          AppRoutes.postContentDetail,
          arguments: {
            'contentId': contentId,
            'contentType': contentType,
            'commentId': commentId,
          },
        );
      },
      onProfile: (userId) {
        Get.toNamed(AppRoutes.otherUserProfile, arguments: userId);
      },
    );
  }

  static void _setupOneSignalIdAndSubscription() {
    OneSignal.User.getOnesignalId().then((id) {
      if (id != null && id.isNotEmpty) {
        PrefService.setValue(PrefKeys.oneSignalId, id);
      }
    });

    OneSignal.User.pushSubscription.optIn();

    OneSignal.User.pushSubscription.addObserver((state) {
      final subId = OneSignal.User.pushSubscription.id ?? '';
      final optedIn = OneSignal.User.pushSubscription.optedIn ?? false;

      if (subId.isNotEmpty) {
        PrefService.setValue(PrefKeys.oneSignalSubscriptionId, subId);
        if (optedIn) {
          _registerDeviceTokenIfLoggedIn(subId);
        }
      }
    });
  }

  static Future<void> logoutOneSignal() async {
    try {
      //  Remove from your backend
      _removeDeviceTokenIfLoggedOut();

      //  Logout from OneSignal external user
      await OneSignal.logout();

      //  Clear saved IDs locally
      PrefService.setValue(PrefKeys.oneSignalId, null);
      PrefService.setValue(PrefKeys.oneSignalSubscriptionId, null);

      log("OneSignal cleaned up on logout");
    } catch (e) {
      log("OneSignal logout error: $e");
    }
  }

  static Future<void> registerUserToOneSignal(String userId) async {
    try {
      if (!_instance._initialized) {
        log("OneSignal not initialized");
        return;
      }

      // Link user with OneSignal
      await OneSignal.login(userId);

      // Enable push notifications
      OneSignal.User.pushSubscription.optIn();
      toggleNotification();
      // Register device token to backend
      registerDeviceTokenWithBackendIfLoggedIn();

      log("User registered to OneSignal successfully: $userId");
    } catch (e) {
      log("registerUserToOneSignal error: $e");
    }
  }

  static void _registerDeviceTokenIfLoggedIn(String deviceToken) {
    if (PrefService.getString(PrefKeys.accessToken).isEmpty) return;

    NotificationRepository().registerNotification(
      data: {"playerId": deviceToken},
      onError: (AppException error) => log(error.toString()),
      onSuccess: (ApiResponse response) => log(response.data.toString()),
    );
  }

  static void _removeDeviceTokenIfLoggedOut() {
    NotificationRepository().removeNotification(
      onError: (AppException error) => log(error.toString()),
      onSuccess: (ApiResponse response) => log(response.data.toString()),
    );
    PrefService.setValue(PrefKeys.accessToken, null);
  }

  static Future<void> toggleNotification() async {
    await NotificationRepository().toggleNotification(
      data: {"enabled": true},
      onSuccess: (ApiResponse response) async {
        try {
          await OneSignal.User.pushSubscription.optIn();
          bool isSubscribed = OneSignal.User.pushSubscription.optedIn ?? false;

          print('ONe signal login ======$isSubscribed');
        } catch (e) {
          // isNotificationOn.value = (!isNotificationOn.value);
        }
      },
      onError: (AppException error) {},
    );
  }

  static Future<void> setExternalUserId(String? externalUserId) async {
    if (!_instance._initialized) return;
    try {
      if (externalUserId != null && externalUserId.isNotEmpty) {
        await OneSignal.login(externalUserId);
      } else {
        await OneSignal.logout();
      }
    } catch (e) {
      log('setExternalUserId error: $e');
    }
  }

  static String getDeviceToken() {
    if (!_instance._initialized) return '';
    try {
      final oneSignalId = PrefService.getString(PrefKeys.oneSignalId);
      if (oneSignalId.isNotEmpty) return oneSignalId;

      final subId = PrefService.getString(PrefKeys.oneSignalSubscriptionId);
      if (subId.isNotEmpty) return subId;

      return OneSignal.User.pushSubscription.id ?? '';
    } catch (_) {
      return '';
    }
  }

  static void registerDeviceTokenWithBackendIfLoggedIn() {
    final subId =
        OneSignal.User.pushSubscription.id ??
        PrefService.getString(PrefKeys.oneSignalSubscriptionId);

    if (subId.isNotEmpty &&
        (OneSignal.User.pushSubscription.optedIn ?? false)) {
      final subId =
          OneSignal.User.pushSubscription.id ??
          PrefService.getString(PrefKeys.oneSignalSubscriptionId);
      if (subId.isNotEmpty && OneSignal.User.pushSubscription.optedIn == true) {
        _registerDeviceTokenIfLoggedIn(subId);
      }
    }
  }
}
