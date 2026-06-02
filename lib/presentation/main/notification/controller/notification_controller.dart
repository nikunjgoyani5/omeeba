import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/notification_response_model.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import 'package:omeeba_new/core/repository/profile_repository.dart';
import 'package:omeeba_new/core/utils/exports.dart';

class NotificationController extends GetxController {
  final NotificationRepository _repo = Get.find<NotificationRepository>();
  final ProfileRepository _profileRepo = ProfileRepository();

  final RxList<NotificationData> notifications = <NotificationData>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isMarkingAllRead = false.obs;
  final RxBool isLoadMoreLoading = false.obs;
  final RxBool hasLoadedOnce = false.obs;
  final RxInt currentPage = 1.obs;
  final RxBool hasNext = false.obs;
  static const int _limit = 20;

  /// Initial / refresh load — shimmer only on very first load.
  Future<void> loadNotifications() async {
    if (isLoading.value) return;
    if (!hasLoadedOnce.value) {
      isLoading.value = true;
    }
    currentPage.value = 1;
    hasNext.value = false;

    await _repo.getNotifications(
      page: 1,
      limit: _limit,
      onSuccess: (model) {
        notifications.assignAll(model.data ?? []);
        currentPage.value = model.pagination?.page ?? 1;
        hasNext.value = model.pagination?.hasNext ?? false;
        hasLoadedOnce.value = true;
        isLoading.value = false;
      },
      onError: (_) {
        isLoading.value = false;
      },
    );
  }

  /// Pull-to-refresh — clears list and shows shimmer while reloading.
  Future<void> refreshNotifications() async {
    if (isRefreshing.value) return;
    isRefreshing.value = true;
   // notifications.clear();
    currentPage.value = 1;
    hasNext.value = false;

    await _repo.getNotifications(
      page: 1,
      limit: _limit,
      onSuccess: (model) {
        notifications.assignAll(model.data ?? []);
        currentPage.value = model.pagination?.page ?? 1;
        hasNext.value = model.pagination?.hasNext ?? false;
        isRefreshing.value = false;
      },
      onError: (_) {
        isRefreshing.value = false;
      },
    );
  }

  /// Infinite scroll — load next page.
  Future<void> loadMoreNotifications() async {
    if (isLoading.value || isLoadMoreLoading.value || !hasNext.value) return;
    isLoadMoreLoading.value = true;

    await _repo.getNotifications(
      page: currentPage.value + 1,
      limit: _limit,
      onSuccess: (model) {
        notifications.addAll(model.data ?? []);
        currentPage.value = model.pagination?.page ?? (currentPage.value + 1);
        hasNext.value = model.pagination?.hasNext ?? false;
        isLoadMoreLoading.value = false;
      },
      onError: (_) {
        isLoadMoreLoading.value = false;
      },
    );
  }

  /// Returns true if any notification is currently unread.
  bool get hasUnread => notifications.any((n) => (n.status ?? '').toLowerCase() == 'unread');

  /// Mark all as read — optimistic local update, revert on failure.
  Future<void> markAllAsRead() async {
    if (isMarkingAllRead.value) return;

    // Snapshot unread items so we can revert them if the API fails.
    final unreadSnapshot = notifications.where((n) => (n.status ?? '').toLowerCase() == 'unread').toList();

    if (unreadSnapshot.isEmpty) return;

    // Optimistic: flip every notification to Read instantly.
    isMarkingAllRead.value = true;
    for (int i = 0; i < notifications.length; i++) {
      final n = notifications[i];
      if ((n.status ?? '').toLowerCase() == 'unread') {
        notifications[i] = n.copyWith(status: 'Read');
      }
    }

    await _repo.markAllAsRead(
      onSuccess: () {
        isMarkingAllRead.value = false;
      },
      onError: (_) {
        // Revert optimistic update on failure.
        for (final original in unreadSnapshot) {
          final i = notifications.indexWhere((n) => n.id == original.id);
          if (i != -1) notifications[i] = original;
        }
        isMarkingAllRead.value = false;
      },
    );
  }

  /// Resolve navigation destination for [notification] and invoke the matching callback.
  ///
  /// Exact type strings received from the API:
  ///   'Post Comment' | 'Write Comment' | 'Zeal Comment'
  ///   'Post Liked'   | 'Write Liked'   | 'Zeal Liked'
  ///   'New Follower'
  ///
  /// No extra API call is made — PostData is built directly from the data
  /// already embedded in the notification (content.images, content.videos,
  /// content.thumbnail). This makes navigation instant and reliable.
  void navigateForNotification(
    NotificationData notification, {
    required void Function(PostData post, String contentType, String? commentId) onPost,
    required void Function(PostData post, String contentType, String? commentId) onZeal,
    required void Function(String userId) onProfile,
  }) {
    final type = notification.type ?? '';
    final senderId = notification.sender?.id ?? '';
    final content = notification.contentType;


    // ── New Follower → sender's profile ──────────────────────────────────────
    if (type == 'New Follower') {
      if (senderId.isNotEmpty) onProfile(senderId);
      return;
    }

    // ── Resolve content ID ────────────────────────────────────────────────────
    // API may put the ID either in top-level `contentId` OR inside `content._id`.
    final contentId =
        (notification.contentId?.isNotEmpty == true ? notification.contentId : notification.content?.id) ?? '';

    if (contentId.isEmpty) return; // nothing to navigate to

    // ── Map exact type string → flags ─────────────────────────────────────────
    final bool isZeal;
    final bool isComment;
     String contentType;

    switch (type) {
      case 'Post Comment':
        contentType = 'Post';
        isZeal = false;
        isComment = true;
        break;
      case 'Post Liked':
        contentType = 'Post';
        isZeal = false;
        isComment = false;
        break;
      case 'Write Comment':
        contentType = 'Write';
        isZeal = false;
        isComment = true;
        break;
      case 'Write Liked':
        contentType = 'Write';
        isZeal = false;
        isComment = false;
        break;
      case 'Zeal Comment':
        contentType = 'Zeal';
        isZeal = true;
        isComment = true;
        break;
      case 'Zeal Liked':
        contentType = 'Zeal';
        isZeal = true;
        isComment = false;
        break;

      case 'Poll Liked':
        contentType = 'Poll';
        isZeal = false;
        isComment = false;
        break;

      case 'Poll Comment':
        contentType = 'Poll';
        isZeal = false;
        isComment = true;
        break;

      case 'Comment Liked':
        contentType = content!;
        isZeal = content == "Zeal Post";
        isComment = true;
        break;

      case 'Comment Reply':
        contentType = content!;
        isZeal = content == "Zeal Post";
        isComment = true;
        break;

      case 'Mention In Comment':
        contentType = content!;
        isZeal = content == "Zeal Post";
        isComment = true;
        break;

      case 'Mention In Post':
        contentType = 'Post';
        isZeal = false;
        isComment = true;
        break;

      case 'Mention In Zeal':
        contentType = 'Zeal';
        isZeal = false;
        isComment = true;
        break;

      case 'Mention In Write':
        contentType = 'Write';
        isZeal = false;
        isComment = true;
        break;

      case 'Poll Voted':
        contentType = 'Poll';
        isZeal = false;
        isComment = true;
        break;

      case 'Poll Ended':
        contentType = 'Poll';
        isZeal = false;
        isComment = true;
        break;
      default:
        return; // unknown type — do nothing
    }

    // ── Build PostData from notification content (no extra network call) ───────
    final c = notification.content;
    final post = PostData(
      id: contentId,
      contentType: contentType,
      images: c?.images,
      videos: c?.videos,
      // Zeal needs mediaUrl for the video player
      mediaUrl: c?.videos?.isNotEmpty == true ? c!.videos!.first : null,
      thumbnailUrl: c?.thumbnail ?? (c?.images?.isNotEmpty == true ? c!.images!.first : null),
      userId: UserId(
        id: senderId,
        name: notification.sender?.name,
        username: notification.sender?.username,
        profileImage: notification.sender?.profileImage,
      ),
    );

    final commentId = isComment ? notification.metadata?.commentId : null;

    if (isZeal) {
      contentType = "Zeal";
      onZeal(post, contentType, commentId);
    } else {
      onPost(post, contentType, commentId);
    }
  }

  /// Follow a user (e.g. from "New Follower" notification).
  /// On success, updates isFollowingSender for matching notifications.
  Future<void> followUser(String userId, {void Function()? onSuccess, void Function(String message)? onError}) async {
    if (userId.isEmpty) return;
    await _profileRepo.followUser(
      userId: userId,
      onSuccess: () {
        _updateNotificationsFollowStatus(userId, true);
        onSuccess?.call();
      },
      onError: (AppException e) {
        onError?.call(e.message);
      },
    );
  }

  /// Unfollow a user. Call after user confirms in unfollow sheet.
  /// On success, updates isFollowingSender for matching notifications.
  Future<void> unfollowUser(String userId, {void Function()? onSuccess, void Function(String message)? onError}) async {
    if (userId.isEmpty) return;
    await _profileRepo.unfollowUser(
      userId: userId,
      onSuccess: () {
        _updateNotificationsFollowStatus(userId, false);
        onSuccess?.call();
      },
      onError: (AppException e) {
        onError?.call(e.message);
      },
    );
  }

  void _updateNotificationsFollowStatus(String userId, bool isFollowing) {
    for (int i = 0; i < notifications.length; i++) {
      if (notifications[i].sender?.id == userId) {
        notifications[i] = notifications[i].copyWith(isFollowingSender: isFollowing);
      }
    }
  }

  /// Called when the user taps a notification row.
  /// Immediately marks it as read locally, then confirms with the API.
  void onNotificationTap(NotificationData notification) {
    final id = notification.id;
    if (id == null) return;

    // Already read — no need to call API.
    if ((notification.status ?? '').toLowerCase() == 'read') return;

    // Optimistic local update — flip status before the API round-trip.
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      notifications[index] = notification.copyWith(status: 'Read');
    }

    // Fire-and-forget — revert on failure.
    _repo.markAsRead(
      id: id,
      onError: (_) {
        // Revert to unread if API call fails.
        final i = notifications.indexWhere((n) => n.id == id);
        if (i != -1) {
          notifications[i] = notification;
        }
      },
    );
  }

  /// Handles navigation from OneSignal push notification payload
  /// (same logic as navigateForNotification, but works with raw Map instead of NotificationData)
  static void navigateFromOneSignalPayload(
    Map<String, dynamic> payload, {
    required void Function(PostData post, String contentType, String? commentId) onPost,
    required void Function(PostData post, String contentType, String? commentId) onZeal,
    required void Function(String userId) onProfile,
  }) {
    // Extract common fields with fallback / safe access
    final type = (payload['type'] as String?)?.trim() ?? '';

    if (type.isEmpty) {
      // Optional: fallback navigation
      Get.back();
      return;
    }

    final senderId =
        payload['senderId']?.toString() ?? payload['userId']?.toString() ?? payload['sender']?['id']?.toString() ?? '';

    // ── New Follower ───────────────────────────────────────────────────────────
    if (type == 'New Follower') {
      if (senderId.isNotEmpty) {
        onProfile(senderId);
      }
      return;
    }

    // ── Resolve content ID (support different payload shapes) ──────────────────
    String? contentId = payload['contentId']?.toString();
    String? content = payload['contentType']?.toString();

    // Fallbacks in case contentId is nested
    contentId ??= payload['query'] is Map ? (payload['query'] as Map)['contentId']?.toString() : null;
    contentId ??= payload['content'] is Map ? (payload['content'] as Map)['id']?.toString() : null;
    contentId ??= payload['postId']?.toString(); // sometimes apps use this key


    if (contentId == null || contentId.isEmpty) {
      // nothing to navigate to → fallback
      Get.back();
      return;
    }

    // ── Map type to flags (same as original) ──────────────────────────────────
    bool isZeal = false;
    bool isComment = false;
    String contentType = '';

    switch (type) {
      case 'Post Comment':
        contentType = 'Post';
        isZeal = false;
        isComment = true;
        break;
      case 'Post Liked':
        contentType = 'Post';
        isZeal = false;
        isComment = false;
        break;
      case 'Write Comment':
        contentType = 'Write';
        isZeal = false;
        isComment = true;
        break;
      case 'Write Liked':
        contentType = 'Write';
        isZeal = false;
        isComment = false;
        break;
      case 'Zeal Comment':
        contentType = 'Zeal';
        isZeal = true;
        isComment = true;
        break;
      case 'Zeal Liked':
        contentType = 'Zeal';
        isZeal = true;
        isComment = false;
        break;
      case 'Poll Liked':
        contentType = 'Poll';
        isZeal = false;
        isComment = false;
        break;

      case 'Poll Comment':
        contentType = 'Poll';
        isZeal = false;
        isComment = true;
        break;

      case 'Comment Liked':
        contentType = content!;
        isZeal = content == "Zeal Post";
        isComment = true;
        break;

      case 'Comment Reply':
        contentType = content!;
        isZeal = content == "Zeal Post";
        isComment = true;
        break;

      case 'Mention In Comment':
        contentType = content!;
        isZeal = content == "Zeal Post";
        isComment = true;
        break;


      case 'Mention In Post':
        contentType = 'Post';
        isZeal = false;
        isComment = true;
        break;

      case 'Mention In Zeal':
        contentType = 'Zeal';
        isZeal = true;
        isComment = true;
        break;

      case 'Mention In Write':
        contentType = 'Write';
        isZeal = false;
        isComment = true;
        break;

      case 'Poll Voted':
        contentType = 'Poll';
        isZeal = false;
        isComment = false;
        break;

      case 'Poll Ended':
        contentType = 'Poll';
        isZeal = false;
        isComment = false;
        break;

      /// this type update to future
      /// Verified Badge Activated,Verified Badge Expired, Subscription Payment Success,Content Reported,Moderation Action,Aggregated Likes, Verified Badge Activated,Content Shared, Content Shared With You, New Snap Received, Snap Viewed,

      default:
        // unknown type → fallback
        Get.back();
        return;
    }

    List<String>? safeList<T>(dynamic value) {
      if (value is List) {
        return value.whereType<String>().toList();
      }
      if (value is String && value.isNotEmpty) {
        return [value];
      }
      return null;
    }

    // ── Build minimal PostData from payload ──────
    final contentMap = payload['content'] is Map<String, dynamic>
        ? payload['content'] as Map<String, dynamic>
        : <String, dynamic>{};
    final imageUrl = payload['image']?.toString();

    final images = imageUrl != null && imageUrl.isNotEmpty ? [imageUrl] : <String>[];

    final videos = safeList<String>(contentMap['videos']) ?? safeList<String>(payload['videos']);

    final thumbnail =
        contentMap['thumbnail']?.toString() ??
        payload['thumbnail']?.toString() ??
        (images.isNotEmpty == true ? images.first : null);

    final mediaUrl = videos?.isNotEmpty == true ? videos!.first : null;

    final userMap = payload['sender'] is Map ? payload['sender'] as Map : payload;

    final post = PostData(
      id: contentId,
      contentType: contentType,
      images: images,
      videos: videos,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnail,

      userId: UserId(
        id: senderId,
        name: userMap['name']?.toString() ?? payload['senderName']?.toString(),
        username: userMap['username']?.toString() ?? payload['senderUsername']?.toString(),
        profileImage: userMap['profileImage']?.toString() ?? payload['senderProfileImage']?.toString(),
      ),
    );

    final commentId = isComment
        ? (payload['commentId']?.toString() ?? payload['metadata']?['commentId']?.toString())
        : null;

    if (isZeal) {
      contentType = "Zeal";
      onZeal(post, contentType, commentId);
    } else {
      onPost(post, contentType, commentId);
    }
  }

}
