import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/music_library_item_model.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

/// Zeals feed API (page-based) with item=zeels.
class ZealsRepository extends BaseRepository {
  ZealsRepository({super.apiClient});

  Future<void> getZeals({
    int page = 1,
    int limit = 20,
    void Function(PostListResponseModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit, 'item': 'zeels'};

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

  /// Music library for reel audio selection. GET [ApiEndpoints.zealsMusic]
  Future<void> getMusicLibrary({
    void Function(List<MusicLibraryItem> items)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.zealsMusic),
      type: RequestType.get,
      onSuccess: (response) {
        try {
          final raw = response.data;
          if (raw is! List) {
            onSuccess?.call([]);
            return;
          }
          final items = <MusicLibraryItem>[];
          for (final e in raw) {
            if (e is Map<String, dynamic>) {
              items.add(MusicLibraryItem.fromJson(e));
            } else if (e is Map) {
              items.add(MusicLibraryItem.fromJson(Map<String, dynamic>.from(e)));
            }
          }
          onSuccess?.call(items);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }
}

