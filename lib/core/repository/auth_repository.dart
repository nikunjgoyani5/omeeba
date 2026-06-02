import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';




class AuthRepository extends BaseRepository {
  AuthRepository({super.apiClient});

  Future<void> login({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.login),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
      body: body,
    );
  }

  Future<void> signUp({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.register),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
      body: body,
    );
  }

  Future<void> otpVerification({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.verifyOtp),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
      body: body,
    );
  }

  Future<void> resendOtp({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.resendOtp),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
      body: body,
    );
  }

  Future<void> forgotPass({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.forgotPass),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
      body: body,
    );
  }

  Future<void> resetPassword({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.resetPass),
      type: RequestType.post,
      onSuccess: onSuccess,
      onError: onError,
      body: body,
    );
  }

  Future<void> changePassword({
    Function(ApiResponse data)? onSuccess,
    Function(AppException error)? onError,
    required Map<String, dynamic> body,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.changePass),
      type: RequestType.put,
      onSuccess: onSuccess,
      onError: onError,
      body: body,
    );
  }
}
