import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

class PostRepository extends BaseRepository {
  PostRepository({super.apiClient});

  Future<void> searchUserForMention({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String page,
    required String search,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.userSearch(page, search)),
      type: RequestType.get,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> createPost({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    List<File>? imageList,
    required Map<String, dynamic> data,
  }) async {
    // Create FormData for multipart request
    final formData = dio.FormData.fromMap(data);

    // Add image file if provided
    if (imageList != null) {
      for (int i = 0; i < imageList.length; i++) {
        final fileName = imageList[i].path.split('/').last;
        formData.files.add(MapEntry('images', await dio.MultipartFile.fromFile(imageList[i].path, filename: fileName)));
      }
    }

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.createPost),
      type: RequestType.post,
      formData: formData,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> getComments({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> queryParam,
  }) async {
    await apiClient.request(
      queryParams: queryParam,
      url: getFullUrl(ApiEndpoints.getComments),
      type: RequestType.get,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> createComment({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> data,
  }) async {
    await apiClient.request(
      body: data,
      url: getFullUrl(ApiEndpoints.getComments),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> likeUnlikeComment({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String id,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.likeUnlikeComment(id)),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> likeUnlikeCommentReply({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String id,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.likeUnlikeCommentReply(id)),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> deleteComment({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String id,
  }) async {
    await apiClient.request(
      url: getFullUrl("${ApiEndpoints.getComments}/$id"),
      type: RequestType.delete,
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

  Future<void> reportComment({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String id,
    Map<String, dynamic>? body,
  }) async {
    await apiClient.request(
      url: getFullUrl("${ApiEndpoints.getComments}/$id/report"),
      type: RequestType.post,
      body: body,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> reportToReplyComment({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String id,
    Map<String, dynamic>? body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.reportReplyToReply(id)),
      type: RequestType.post,
      body: body,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> createCommentReply({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String id,
    Map<String, dynamic>? body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.commentReply(id)),
      type: RequestType.post,
      body: body,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> createCommentReplyToReply({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String id,
    Map<String, dynamic>? body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.replyToReply(id)),
      type: RequestType.post,
      body: body,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> deleteCommentReply({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String id,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.deleteReply(id)),
      type: RequestType.delete,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> savePost({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> data,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.savePost),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
      body: data,
    );
  }

  /// [contentType] optional: "all" | "Post" | "Write Post" | "Zeal Post" | "Poll"
  Future<void> getSavedList({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    String contentType = 'all',
    int page = 1,
    int limit = 10,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.getSavedList),
      type: RequestType.post,
      body: {'contentType': contentType, 'page': page, 'limit': limit},
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> getEligibleUserList({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.getEligibleUserList),
      type: RequestType.get,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> deleteSingleMessageAPI({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String messageId,
    required String roomId,
  }) async {

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.deleteSingleMessage(roomId, messageId)),
      type: RequestType.delete,
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}
