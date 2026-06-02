import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/models/search_hashtag_model.dart';
import 'package:omeeba_new/core/models/search_user_model.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

/// Explore / Trending / Polls API. Same response shape as [PostListResponseModel].
class ExploreRepository extends BaseRepository {
  ExploreRepository({super.apiClient});

  /// Fetches explore content by contentType: explore | write | poll
  Future<void> getExploreFeed({
    required String contentType,
    int page = 1,
    int limit = 20,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'contentType': contentType, 'page': page, 'limit': limit};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.explore),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostDataResponse? dataResponse;
          final raw = response.data;
          if (raw is Map<String, dynamic>) {
            dataResponse = PostDataResponse.fromJson(raw);
          } else if (raw is List) {
            final posts = raw.map((e) => PostData.fromJson(Map<String, dynamic>.from(e as Map))).toList();
            dataResponse = PostDataResponse(posts: posts, isFollowing: null);
          } else {
            dataResponse = PostDataResponse(posts: [], isFollowing: null);
          }
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

  /// Explore search. type: users | posts | zeals | hashtag
  Future<void> searchExplore({
    required String query,
    required String type,
    int page = 1,
    int limit = 20,
    void Function(List<SearchUserData> users)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{
      'query': query,
      'type': type,
      // 'page': page,
      // 'limit': limit,
    };

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.exploreSearch),
      type: RequestType.post,
      body: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final rawList = response.data;
          List<SearchUserData> users = [];
          if (rawList is List) {
            users = rawList.map((e) => SearchUserData.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
          onSuccess?.call(users);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Explore search with type=posts or type=zeals. Returns list of [PostData].
  Future<void> searchExploreContent({
    required String query,
    required String type,
    int page = 1,
    int limit = 20,
    void Function(List<PostData> list)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{
      'query': query,
      'type': type,
    };

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.exploreSearch),
      type: RequestType.post,
      body: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final rawList = response.data;
          List<PostData> list = [];
          if (rawList is List) {
            list = rawList
                .map((e) => PostData.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
          onSuccess?.call(list);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Explore search with type=hashtag. Returns list of [SearchHashtagData].
  Future<void> searchExploreHashtags({
    required String query,
    void Function(List<SearchHashtagData> list)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{
      'query': query,
      'type': 'hashtag',
    };

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.exploreSearch),
      type: RequestType.post,
      body: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final rawList = response.data;
          List<SearchHashtagData> list = [];
          if (rawList is List) {
            list = rawList
                .map((e) => SearchHashtagData.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
          onSuccess?.call(list);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  /// Explore by hashtag. Same API; contentType: write | post | zeal | poll (passed on tab select).
  Future<void> getHashtagContent({
    required String hashtag,
    required String contentType,
    void Function(List<SearchUserData>)? onUsersSuccess,
    void Function(List<PostData>)? onPostsSuccess,
    void Function(List<SearchHashtagData>)? onHashtagsSuccess,
    void Function(AppException)? onError,
  }) async {
    final tag = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
    final queryParams = <String, dynamic>{'contentType': contentType};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.exploreHashtag(tag)),
      type: RequestType.get,
      queryParams: queryParams,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final rawList = response.data;
          if (rawList is! List) {
            if (contentType == 'user') onUsersSuccess?.call([]);
            if (contentType == 'post' || contentType == 'zeal') onPostsSuccess?.call([]);
            if (contentType == 'hashtag') onHashtagsSuccess?.call([]);
            return;
          }
          final list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (contentType == 'user') {
            onUsersSuccess?.call(list.map((e) => SearchUserData.fromJson(e)).toList());
          } else if (contentType == 'post' || contentType == 'zeal') {
            onPostsSuccess?.call(list.map((e) => PostData.fromJson(e)).toList());
          } else if (contentType == 'hashtag') {
            onHashtagsSuccess?.call(list.map((e) => SearchHashtagData.fromJson(e)).toList());
          }
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }
}
