import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

/// Home feed API (page-based pagination). Response shape matches [PostListResponseModel].
class HomeRepository extends BaseRepository {
  HomeRepository({super.apiClient});

  /// Fetches home feed.
  /// Your backend uses page-based pagination:
  /// `?page=1&limit=20`
  Future<void> getFeed({
    int page = 1,
    int limit = 20,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.home),
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

  /// Submit vote for a poll. Returns updated poll data on success.
  Future<void> submitPollVote({
    required String pollId,
    required String optionId,
    void Function(PostData? updatedPost)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.pollVote(pollId)),
      type: RequestType.post,
      body: {'optionId': optionId},
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          PostData? updatedPost;
          final raw = response.data["poll"];
          if (raw is Map<String, dynamic>) {
            updatedPost = PostData.fromJson(raw);
          }
          onSuccess?.call(updatedPost);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }
}
