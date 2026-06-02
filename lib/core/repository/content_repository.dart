import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

import '../models/api_response.dart';
import '../models/userlikelist_model.dart';

/// Single repository for creating content: write post, create poll, upload zeal video, create zeal.
class ContentRepository extends BaseRepository {
  ContentRepository({super.apiClient});

  /// Creates a text post.
  Future<void> writePost({
    required String content,
    required List<String> mentionedUserIds,
    void Function(ApiResponse data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'mentionedUserIds': mentionedUserIds,
    };
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.writePosts),
      type: RequestType.post,
      body: body,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(
            AppException(message: response.message ?? 'Request failed'),
          );
          return;
        }
        onSuccess?.call(response);
      },
      onError: onError,
    );
  }

  /// Creates a poll.
  Future<void> createPoll({
    required String caption,
    required List<String> options,
    required String duration,
    void Function(ApiResponse data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final body = <String, dynamic>{
      'caption': caption,
      'options': options,
      'duration': duration,
    };
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.polls),
      type: RequestType.post,
      body: body,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(
            AppException(message: response.message ?? 'Request failed'),
          );
          return;
        }
        onSuccess?.call(response);
      },
      onError: onError,
    );
  }

  /// Uploads zeal video file; returns upload data (e.g. zealDraftId) in onSuccess.
  Future<void> uploadZealVideo({
    required File file,
    void Function(double progress)? onProgress,
    void Function(dynamic data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final formData = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(
        file.path,
        filename: file.path.split(RegExp(r'[/\\]')).last,
      ),
    });
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.zealsUpload),
      type: RequestType.post,
      formData: formData,
      onSendProgress: (sent, total) {
        if (total > 0) {
          onProgress?.call((sent / total * 100).clamp(0, 100));
        }
      },
      onSuccess: (response) {
        onSuccess?.call(response.data);
      },
      onError: onError,
    );
  }

  /// Creates zeal after upload.
  /// [audioAction]: `replace` | `original` | `mute`.
  /// `musicId`, `musicStartTime`, and `musicEndTime` are only sent when [audioAction] is `replace`.
  Future<void> createZeal({
    required String zealDraftId,
    required String caption,
    List<String>? mentionedUserIds,
    required String audioAction,
    String? musicId,
    int? musicStartTime,
    int? musicEndTime,
    bool isDevelopByAi = false,
    void Function(dynamic data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    final body = <String, dynamic>{
      'zealDraftId': zealDraftId,
      'caption': caption,
      'mentionedUserIds': mentionedUserIds ?? [],
      'audioAction': audioAction,
      'isDevelopByAi': isDevelopByAi,
    };
    if (audioAction == 'replace') {
      body['musicId'] = musicId;
      body['musicStartTime'] = musicStartTime;
      body['musicEndTime'] = musicEndTime;
    }
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.zeals),
      type: RequestType.post,
      body: body,
      onSuccess: (response) => onSuccess?.call(response.data),
      onError: onError,
    );
  }

  Future<void> getLikedUsers({
    required String contentType,
    required String contentId,
    void Function(UserLikeListModel data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(
        'content-likes/${Uri.encodeComponent(contentType)}/$contentId/users',
      ),
      type: RequestType.get,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(
            AppException(
              message: response.message ?? 'Failed to load users',
            ),
          );
          return;
        }

        try {
          final raw = response.data;
          UserLikeListModel model;

          if (raw is Map<String, dynamic> && raw.containsKey('data')) {

            model = UserLikeListModel.fromJson(raw);
          } else if (raw is Map<String, dynamic>) {
            model = UserLikeListModel.fromJson({
              'success': true,
              'message': response.message ?? '',
              'data': raw,
            });
          } else if (raw is List) {
            model = UserLikeListModel.fromJson({
              'success': true,
              'message': response.message ?? '',
              'data': {'users': raw},
            });
          } else {
            model = UserLikeListModel.fromJson({
              'success': true,
              'message': response.message ?? '',
              'data': {'users': []},
            });
          }
          onSuccess?.call(model);
        } catch (e) {
          onError?.call(
            AppException(message: e.toString()),
          );
        }
      },

      onError: onError,
    );
  }


}
