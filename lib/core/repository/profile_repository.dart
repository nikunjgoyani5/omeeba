import 'package:dio/dio.dart' as dio;
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/follow_list_response_model.dart';
import 'package:omeeba_new/core/models/mention_user_model.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/models/user_profile_response_model.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

class ProfileRepository extends BaseRepository {
  ProfileRepository({super.apiClient});

  /// Follow a user. POST follow/{userId}
  Future<void> followUser({
    required String userId,
    void Function()? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.followUser(userId)),
      type: RequestType.post,
      onSuccess: (_) => onSuccess?.call(),
      onError: onError,
    );
  }

  /// Unfollow a user. DELETE follow/{userId}
  Future<void> unfollowUser({
    required String userId,
    void Function()? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.unfollowUser(userId)),
      type: RequestType.delete,
      onSuccess: (_) => onSuccess?.call(),
      onError: onError,
    );
  }

  /// Get list of users that [userId] is following. Query: userId, page, limit.
  Future<void> getFollowing({
    required String userId,
    int page = 1,
    int limit = 20,
    void Function(FollowListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'userId': userId, 'page': page, 'limit': limit};
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.followFollowing),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final list = response.data is List
              ? (response.data as List)
                  .map((e) => FollowListItem.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList()
              : <FollowListItem>[];
          onSuccess?.call(FollowListResponseModel(
            success: response.success,
            message: response.message,
            data: list,
            pagination: response.pagination,
          ));
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Get list of followers of [userId]. Query: userId, page, limit.
  Future<void> getFollowers({
    required String userId,
    int page = 1,
    int limit = 20,
    void Function(FollowListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'userId': userId, 'page': page, 'limit': limit};
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.followFollowers),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final list = response.data is List
              ? (response.data as List)
                  .map((e) => FollowListItem.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList()
              : <FollowListItem>[];
          onSuccess?.call(FollowListResponseModel(
            success: response.success,
            message: response.message,
            data: list,
            pagination: response.pagination,
          ));
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  Future<void> getOtherUserProfile({
    required String userId,
    void Function(UserProfileResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.otherUserProfile(userId)),
      type: RequestType.get,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final model = UserProfileResponseModel.fromJson(response.toJson());
          onSuccess?.call(model);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  Future<void> getProfile({
    void Function(UserProfileResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userProfile),
      type: RequestType.get,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }

        try {
          final model = UserProfileResponseModel.fromJson(response.toJson());
          onSuccess?.call(model);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Update profile with optional images, using multipart/form-data.
  Future<void> updateProfile({
    required String name,
    required String username,
    required String bio,
    String? coverImagePath,
    String? profileImagePath,
    bool removeCoverImage = false,
    bool removeProfileImage = false,
    void Function(UserProfileResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final formDataMap = <String, dynamic>{'name': name, 'username': username, 'bio': bio};

    if (coverImagePath != null && coverImagePath.isNotEmpty) {
      formDataMap['coverImage'] = await dio.MultipartFile.fromFile(coverImagePath);
    } else if (removeCoverImage) {
      formDataMap['coverImage'] = '';
    }

    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      formDataMap['profileImage'] = await dio.MultipartFile.fromFile(profileImagePath);
    } else if (removeProfileImage) {
      formDataMap['profileImage'] = '';
    }

    final formData = dio.FormData.fromMap(formDataMap);

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userProfile),
      type: RequestType.put,
      formData: formData,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final model = UserProfileResponseModel.fromJson(response.toJson());
          onSuccess?.call(model);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Search users by query (for mentions). Pagination: page, limit.
  Future<void> searchUsers({
    required String query,
    int page = 1,
    int limit = 4,
    void Function(List<MentionUser> users, bool hasNext)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'username': query, 'page': page, 'limit': limit};
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.searchUsers),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          List<MentionUser> users = [];
          final data = response.data;
          if (data is List) {
            for (final e in data) {
              if (e is Map<String, dynamic>) {
                users.add(MentionUser.fromJson(e));
              }
            }
          } else if (data is Map<String, dynamic>) {
            final list = data['users'] ?? data['data'];
            if (list is List) {
              for (final e in list) {
                if (e is Map<String, dynamic>) {
                  users.add(MentionUser.fromJson(e));
                }
              }
            }
          }
          final hasNext = response.pagination?.hasNext ?? false;
          onSuccess?.call(users, hasNext);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Fetch another user's posts by [userId]. Same endpoint as [getMyPosts] with an extra `userId` query param.
  Future<void> getOtherUserPosts({
    required String userId,
    int page = 1,
    int limit = 10,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'userId': userId, 'page': page, 'limit': limit};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userPosts),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          final model = PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
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

  /// Fetch another user's zeals by [userId].
  Future<void> getOtherUserZeals({
    required String userId,
    int page = 1,
    int limit = 10,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'userId': userId, 'page': page, 'limit': limit};
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userZeals),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          onSuccess?.call(PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
            pagination: response.pagination,
          ));
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Fetch another user's write-posts by [userId].
  Future<void> getOtherUserWritePosts({
    required String userId,
    int page = 1,
    int limit = 10,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'userId': userId, 'page': page, 'limit': limit};
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userWritePosts),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          onSuccess?.call(PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
            pagination: response.pagination,
          ));
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Fetch another user's polls by [userId].
  Future<void> getOtherUserPolls({
    required String userId,
    int page = 1,
    int limit = 10,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'userId': userId, 'page': page, 'limit': limit};
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userPolls),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          onSuccess?.call(PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
            pagination: response.pagination,
          ));
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Fetch another user's mentioned-posts by [userId].
  Future<void> getOtherUserMentionedPosts({
    required String userId,
    int page = 1,
    int limit = 10,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'userId': userId, 'page': page, 'limit': limit};
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userMentionedPosts),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          onSuccess?.call(PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
            pagination: response.pagination,
          ));
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Fetch current user's posts. Response shape matches [PostListResponseModel] (data: list of PostData, pagination).
  Future<void> getMyPosts({
    int page = 1,
    int limit = 15,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userPosts),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          final model = PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
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

  /// Fetch current user's write-posts. Response shape matches [PostListResponseModel] (data: list of PostData, pagination).
  Future<void> getMyWritePosts({
    int page = 1,
    int limit = 10,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userWritePosts),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          final model = PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
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

  /// Fetch current user's polls. Response shape matches [PostListResponseModel] (data: list of PostData, pagination).
  Future<void> getMyPolls({
    int page = 1,
    int limit = 10,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userPolls),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          final model = PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
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

  /// Fetch current user's mentioned-posts. Response shape matches [PostListResponseModel] (data: list of PostData, pagination).
  Future<void> getMyMentionedPosts({
    int page = 1,
    int limit = 10,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userMentionedPosts),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          final model = PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
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

  /// Fetch current user's zeals. Response shape matches [PostListResponseModel] (data: list of PostData, pagination).
  Future<void> getMyZeals({
    int page = 1,
    int limit = 10,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userZeals),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse dataResponse = _parsePostDataResponse(response.data);
          final model = PostListResponseModel(
            success: response.success,
            message: response.message,
            data: dataResponse,
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

  static PostDataResponse _parsePostDataResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) return PostDataResponse.fromJson(raw);
    if (raw is List) {
      final posts = raw.map((e) => PostData.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      return PostDataResponse(posts: posts, isFollowing: null);
    }
    return PostDataResponse(posts: [], isFollowing: null);
  }
}
