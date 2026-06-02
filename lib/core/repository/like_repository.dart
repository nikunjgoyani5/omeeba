
import '../exceptions/app_exception.dart';
import '../models/api_response.dart';
import '../models/follow_list_response_model.dart';
import '../models/userlikelist_model.dart';
import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import 'base_repository.dart';

class LikeRepository extends BaseRepository {

  Future<void> likeUnlikeContent({
    required Map<String, dynamic> body,
    void Function(ApiResponse data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.likeUnlikeContent),
      type: RequestType.post,
      body: body,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          onSuccess?.call(response);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  // Future<void> getLikedUsers({
  //   required String contentId,
  //   required String contentType,
  //   String search = '',
  //   int page = 1,
  //   int limit = 50,
  //   void Function(FollowListResponseModel data)? onSuccess,
  //   void Function(AppException error)? onError,
  // }) async {
  //   final queryParams = <String, dynamic>{
  //     'contentId': contentId,
  //     'contentType': contentType,
  //     'search': search,
  //     'page': page,
  //     'limit': limit,
  //   };
  //
  //   await apiClient.request(
  //     url: getFullUrl(ApiEndpoints.likedUsers),
  //     type: RequestType.get,
  //     queryParams: queryParams,
  //     onSuccess: (response) {
  //       if (!response.isSuccess) {
  //         onError?.call(AppException(message: response.message ?? 'Request failed'));
  //         return;
  //       }
  //       try {
  //         final raw = response.data;
  //         List<dynamic> listRaw = [];
  //         if (raw is List) {
  //           listRaw = raw;
  //         } else if (raw is Map<String, dynamic>) {
  //           final nested = raw['users'] ?? raw['data'] ?? raw['results'] ?? [];
  //           if (nested is List) listRaw = nested;
  //         }
  //         final users = listRaw
  //             .whereType<Map>()
  //             .map((e) => FollowListItem.fromJson(Map<String, dynamic>.from(e)))
  //             .toList();
  //         onSuccess?.call(
  //           FollowListResponseModel(
  //             success: response.success,
  //             message: response.message,
  //             data: users,
  //             pagination: response.pagination,
  //           ),
  //         );
  //       } catch (e) {
  //         onError?.call(AppException(message: e.toString()));
  //       }
  //     },
  //     onError: onError,
  //   );
  // }




  // Future<void> getLikedUsers({
  //   required String contentType,
  //   required String contentId,
  //   void Function(UserLikeListModel data)? onSuccess,
  //   void Function(AppException error)? onError,
  // }) async {
  //   await apiClient.request(
  //     url: getFullUrl(
  //       '/content-likes/$contentType/$contentId/users',
  //     ),
  //     type: RequestType.get,
  //     onSuccess: (response) {
  //       if (!response.isSuccess) {
  //         onError?.call(
  //           AppException(
  //             message: response.message ?? 'Failed to load users',
  //           ),
  //         );
  //         return;
  //       }
  //
  //       try {
  //         final model = UserLikeListModel.fromJson(response.data);
  //         onSuccess?.call(model);
  //       } catch (e) {
  //         onError?.call(
  //           AppException(message: e.toString()),
  //         );
  //       }
  //     },
  //
  //     onError: onError,
  //   );
  // }

}