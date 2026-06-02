import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

import '../models/api_response.dart';
import '../models/reports_categories_model.dart';

/// Home feed API (page-based pagination). Response shape matches [PostListResponseModel].
class ReportRepository extends BaseRepository {
  ReportRepository({super.apiClient});

  /// Fetches home feed.
  /// Your backend uses page-based pagination:
  /// `?page=1&limit=20`
  Future<void> getReportsCategories({
    void Function(CategoryData data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.reports),
      type: RequestType.get,
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        try {
          final res = CategoryData.fromJson(response.data);
          onSuccess?.call(res);
        } catch (e) {
          onError?.call(AppException(message: e.toString()));
        }
      },
      onError: onError,
    );
  }

  Future<void> submitReport({
    required Map<String, dynamic> body,
    void Function(ApiResponse data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.reportsSubmit),
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
}
