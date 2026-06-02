import 'dart:developer';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import '../exceptions/app_exception.dart';
import '../models/api_response.dart';
import '../routes/app_routes.dart';
import '../utils/app_prefrence.dart';
import 'onesignal_notification_service.dart';

enum RequestType { get, post, put, patch, delete }

class ApiClient {
  final dio.Dio _dio;
  static bool _isHandlingUnauthorized = false;

  ApiClient({dio.BaseOptions? options})
    : _dio = dio.Dio(
        options ??
            dio.BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
            ),
      );

  ApiResponse? _parseResponse(dynamic responseData) {
    if (responseData == null) return null;

    try {
      if (responseData is Map<String, dynamic>) {
        return ApiResponse.fromJson(responseData);
      }
    } catch (e) {
      log("Error parsing response: $e");
      return null;
    }

    return null;
  }

  Future request({
    required String url,
    required RequestType type,
    Map<String, dynamic>? body,
    dio.FormData? formData,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    void Function(int, int)? onSendProgress,
  }) async {
    log("URL: $url");
    if (body != null) {
      log("Request: $body");
    }
    if (formData != null) {
      log("Request: $formData");
    }
    if (queryParams != null) {
      log("queryParams: $queryParams");
    }

    try {
      final token = PrefService.getString(PrefKeys.accessToken);
      if (token.isNotEmpty) {
        log("Token:\n$token");
      }

      final requestHeaders = <String, String>{
        'Content-Type': formData == null ? 'application/json' : 'multipart/form-data',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        ...?headers,
      };

      _dio.options.headers.clear();
      _dio.options.headers.addAll(requestHeaders);

      dio.Response response;
      switch (type) {
        case RequestType.get:
          response = await _dio.get(url, queryParameters: queryParams);
          break;
        case RequestType.post:
          response = await _dio.post(
            url,
            data: formData ?? body,
            queryParameters: queryParams,
            onSendProgress: onSendProgress,
          );
          break;
        case RequestType.put:
          response = await _dio.put(url, data: formData ?? body, queryParameters: queryParams);
          break;
        case RequestType.patch:
          response = await _dio.patch(url, data: body, queryParameters: queryParams);
          break;
        case RequestType.delete:
          response = await _dio.delete(url, data: body, queryParameters: queryParams);
          break;
      }

      log("Response: ${response.data}");
      log("Status Code: ${response.statusCode}");

      ApiResponse parsedResponse = _parseResponse(response.data) ?? ApiResponse(success: false);

      final statusCode = response.statusCode ?? 0;

      if (statusCode >= 200 && statusCode < 300) {
        if (!parsedResponse.isSuccess) {
          log("API Error Response: ${response.data}");
          onError?.call(AppException(message: parsedResponse.message ?? 'Something went wrong'));
        } else {
          onSuccess?.call(parsedResponse);
        }
      } else {
        log("HTTP Error Status: $statusCode");
        if (statusCode == 401) {
          await _handleUnauthorizedLogout();
        }
        onError?.call(AppException(message: parsedResponse.message ?? 'Something went wrong'));
      }
    } on dio.DioException catch (e) {
      AppException exception = ExceptionHandler.handleDioException(e);
      log("Original error: ${exception.message}");
      // AppFunctions().showToast(exception.message, bgColor: AppColors.red);
      if (exception.statusCode == 401) {
        await _handleUnauthorizedLogout();
      }
      onError?.call(exception);
    } catch (e) {
      AppException exception = ExceptionHandler.handleGenericException(e);
      log("Original error11: ${e.toString()}");
      onError?.call(exception);
    }
  }

  Future<void> _handleUnauthorizedLogout() async {
    if (_isHandlingUnauthorized) return;
    final isLoggedIn = PrefService.getBool(PrefKeys.isLogin);
    if (!isLoggedIn) return;

    _isHandlingUnauthorized = true;
    try {
      await OneSignalNotificationService.setExternalUserId(null);
      await PrefService.clear();
      Get.offAllNamed(AppRoutes.login);
    } finally {
      _isHandlingUnauthorized = false;
    }
  }
}
