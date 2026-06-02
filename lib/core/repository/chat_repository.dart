import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

class ChatRepository extends BaseRepository {
  ChatRepository({super.apiClient});

  Future<void> chatsList({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String page,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.chatList(page)),
      type: RequestType.get,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> chatsRequestList({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required String page,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.chatRequestList(page)),
      type: RequestType.get,
      onSuccess: onSuccess,
      onError: onError,
    );
  }
  Future<void> uploadMedia({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    File? image,
    bool shouldRemoveImage = false,
  }) async {
    // Create FormData for multipart request
    final formData = dio.FormData.fromMap({});

    // Add image file if provided
    if (image != null) {
      final fileName = image.path.split('/').last;
      formData.files.add(
        MapEntry('file', await dio.MultipartFile.fromFile(image.path, filename: fileName)),
      );
    }

    await apiClient.request(
      url: getFullUrl(ApiEndpoints.uploadMedia),
      type: RequestType.post
      ,
      formData: formData,
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}
