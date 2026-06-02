import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/models/notification_response_model.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

class NotificationRepository extends BaseRepository {
  NotificationRepository({super.apiClient});

  /// Mark all notifications as read. PUT notifications/read-all
  Future<void> markAllAsRead({
    void Function()? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.notificationReadAll),
      type: RequestType.put,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        onSuccess?.call();
      },
      onError: onError,
    );
  }

  /// Mark a single notification as read. PUT notifications/{id}/read
  Future<void> markAsRead({
    required String id,
    void Function()? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.notificationRead(id)),
      type: RequestType.put,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        onSuccess?.call();
      },
      onError: onError,
    );
  }

  Future<void> getNotifications({
    int page = 1,
    int limit = 20,
    void Function(NotificationResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.notifications),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final rawList = response.data;
          List<NotificationData> items = [];
          if (rawList is List) {
            items = rawList
                .map((e) => NotificationData.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
          final model = NotificationResponseModel(
            success: response.success,
            message: response.message,
            data: items,
            pagination: response.pagination,
          );
          onSuccess?.call(model);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Normalize app contentType to API contentType (Post | Zeal Post | Write Post | Poll).
  static String contentTypeToApi(String? contentType) {
    final t = (contentType ?? 'post').toLowerCase();
    if (t.contains('zeal')) return 'Zeal Post';
    if (t.contains('write')) return 'Write Post';
    if (t.contains('poll')) return 'Poll';
    return 'Post';
  }

  /// Delete content by type and id. DELETE /api/v1/content/{contentType}/{contentId}.
  /// [contentType] can be app format (e.g. "Write", "Zeal") or API format ("Write Post"); it is normalized.
  /// On success calls [onSuccess]; on failure calls [onError].
  Future<void> deleteContentByTypeAndId({
    required String contentId,
    required String contentType,
    void Function(ApiResponse response)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final apiContentType = contentTypeToApi(contentType);
    final endpoint = ApiEndpoints.contentByTypeAndId(apiContentType, contentId);
    await apiClient.request(
      url: getFullUrl(endpoint),
      type: RequestType.delete,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Delete failed'));
          return;
        }
        onSuccess?.call(response);
      },
      onError: onError,
    );
  }

  /// Fetch a single post/zeal/write/poll by [contentId] using the unified content API.
  /// [apiContentType] must be one of: "Post", "Zeal Post", "Write Post", "Poll".
  /// Response format: { success, message, data: { content: { ... } } } — content is stored in [PostData].
  Future<void> fetchContentByTypeAndId({
    required String contentId,
    required String apiContentType,
    void Function(PostData data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final endpoint = ApiEndpoints.contentByTypeAndId(apiContentType, contentId);

    await apiClient.request(
      url: getFullUrl(endpoint),
      type: RequestType.get,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Failed to load content'));
          return;
        }
        try {
          final data = response.data;
          if (data is! Map) {
            onError?.call(AppException(message: 'Invalid response format'));
            return;
          }
          final content = data['content'];
          if (content == null || content is! Map) {
            onError?.call(AppException(message: 'Content not found'));
            return;
          }
          final post = PostData.fromJson(Map<String, dynamic>.from(content));
          onSuccess?.call(post);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Fetch a single post/zeal/write/poll by [contentId] (legacy per-type endpoints).
  /// [contentType] drives which endpoint to call — any string containing
  /// "zeal", "write", or "poll" selects the matching endpoint; everything else
  /// falls back to posts.
  Future<void> fetchContentById({
    required String contentId,
    required String contentType,
    void Function(PostData data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final t = contentType.toLowerCase();
    final String endpoint;
    if (t.contains('zeal')) {
      endpoint = ApiEndpoints.zealById(contentId);
    } else if (t.contains('write')) {
      endpoint = ApiEndpoints.writePostById(contentId);
    } else if (t.contains('poll')) {
      endpoint = ApiEndpoints.pollById(contentId);
    } else {
      endpoint = ApiEndpoints.postById(contentId);
    }

    await apiClient.request(
      url: getFullUrl(endpoint),
      type: RequestType.get,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Failed to load content'));
          return;
        }
        try {
          final raw = response.data;
          PostData? post;
          if (raw is Map) {
            post = PostData.fromJson(Map<String, dynamic>.from(raw));
          }
          if (post != null) {
            onSuccess?.call(post);
          } else {
            onError?.call(AppException(message: 'Unable to parse content'));
          }
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  Future<void> toggleNotification({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String,dynamic> data,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.toggleNotification),
      type: RequestType.put,
      onSuccess: onSuccess,
      onError: onError,
      body: data
    );
  }


  Future<void> registerNotification({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String,dynamic> data,
  }) async {
    await apiClient.request(
        url: getFullUrl(ApiEndpoints.notificationIdRegister),
        type: RequestType.post,
        onSuccess: onSuccess,
        onError: onError,
        body: data
    );
  }
  Future<void> removeNotification({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
  }) async {
    await apiClient.request(
        url: getFullUrl(ApiEndpoints.notificationIdRegister),
        type: RequestType.delete,
        onSuccess: onSuccess,
        onError: onError,
    );
  }

}
