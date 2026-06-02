import 'package:dio/dio.dart';

/// Custom exception class for app-wide error handling
class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  AppException({required this.message, this.statusCode, this.originalError});

  @override
  String toString() => message;
}

/// Exception handler that converts technical errors to user-friendly messages
class ExceptionHandler {
  /// Handle Dio exceptions and convert to user-friendly messages
  static AppException handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException(
          message: 'Connection timeout. Please check your internet connection and try again.',
          statusCode: null,
          originalError: error,
        );

      case DioExceptionType.badResponse:
        return _handleHttpError(
          statusCode: error.response?.statusCode ?? 0,
          responseData: error.response?.data,
          originalError: error,
        );

      case DioExceptionType.cancel:
        return AppException(
          message: 'Request was cancelled. Please try again.',
          statusCode: null,
          originalError: error,
        );

      case DioExceptionType.connectionError:
        return AppException(
          message: 'Unable to connect to the server. Please check your internet connection.',
          statusCode: null,
          originalError: error,
        );

      case DioExceptionType.badCertificate:
        return AppException(
          message: 'Security certificate error. Please try again later.',
          statusCode: null,
          originalError: error,
        );

      case DioExceptionType.unknown:
        if (error.message?.contains('SocketException') == true ||
            error.message?.contains('Network is unreachable') == true) {
          return AppException(
            message: 'No internet connection. Please check your network settings.',
            statusCode: null,
            originalError: error,
          );
        }
        return AppException(
          message: 'Something went wrong. Please try again later.',
          statusCode: null,
          originalError: error,
        );
    }
  }

  /// Handle HTTP status codes directly (for successful responses with error status codes)
  static AppException handleHttpError({required int statusCode, dynamic responseData}) {
    return _handleHttpError(statusCode: statusCode, responseData: responseData, originalError: null);
  }

  /// Handle HTTP status codes and convert to user-friendly messages
  static AppException _handleHttpError({required int statusCode, dynamic responseData, dynamic originalError}) {
    // Try to extract error message from response
    String? apiMessage = _extractErrorMessage(responseData);

    switch (statusCode) {
      case 400:
        return AppException(
          message: apiMessage ?? 'Invalid request. Please check your input and try again.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 401:
        return AppException(
          message: apiMessage ?? 'Your session has expired. Please log in again.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 403:
        return AppException(
          message: apiMessage ?? 'You don\'t have permission to perform this action.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 404:
        return AppException(
          message: apiMessage ?? 'The requested resource was not found.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 408:
        return AppException(
          message: 'Request timeout. Please try again.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 409:
        return AppException(
          message: apiMessage ?? 'A conflict occurred. Please try again.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 422:
        return AppException(
          message: apiMessage ?? 'Validation error. Please check your input.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 429:
        return AppException(
          message: 'Too many requests. Please wait a moment and try again.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 500:
        return AppException(
          message: 'Server error. Our team has been notified. Please try again later.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 502:
        return AppException(
          message: 'Server is temporarily unavailable. Please try again later.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 503:
        return AppException(
          message: 'Service is temporarily unavailable. Please try again later.',
          statusCode: statusCode,
          originalError: originalError,
        );

      case 504:
        return AppException(
          message: 'Server timeout. Please try again later.',
          statusCode: statusCode,
          originalError: originalError,
        );

      default:
        if (statusCode >= 400 && statusCode < 500) {
          return AppException(
            message: apiMessage ?? 'Client error occurred. Please try again.',
            statusCode: statusCode,
            originalError: originalError,
          );
        } else if (statusCode >= 500) {
          return AppException(
            message: apiMessage ?? 'Server error occurred. Please try again later.',
            statusCode: statusCode,
            originalError: originalError,
          );
        } else {
          return AppException(
            message: apiMessage ?? 'An unexpected error occurred. Please try again.',
            statusCode: statusCode,
            originalError: originalError,
          );
        }
    }
  }

  /// Extract user-friendly error message from API response
  static String? _extractErrorMessage(dynamic responseData) {
    if (responseData == null) return null;

    try {
      // Handle string response
      if (responseData is String) {
        return responseData.isNotEmpty ? responseData : null;
      }

      // Handle Map response
      if (responseData is Map) {
        // Prioritize 'error' field over 'message' for validation errors
        // Check 'error' field first if it exists
        if (responseData.containsKey('error')) {
          final errorValue = responseData['error'];
          if (errorValue is String && errorValue.isNotEmpty) {
            return errorValue;
          }
        }

        // Common error message keys in API responses
        final errorKeys = ['message', 'msg', 'errorMessage', 'error_message', 'detail', 'description', 'reason'];

        // Try to find error message in common keys
        for (final key in errorKeys) {
          if (responseData.containsKey(key)) {
            final value = responseData[key];
            if (value is String && value.isNotEmpty) {
              return value;
            }
          }
        }

        // Handle nested error objects
        if (responseData.containsKey('errors')) {
          final errors = responseData['errors'];
          if (errors is Map && errors.isNotEmpty) {
            // Get first error value
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              return firstError.first.toString();
            } else if (firstError is String) {
              return firstError;
            }
          } else if (errors is List && errors.isNotEmpty) {
            return errors.first.toString();
          }
        }

        // Handle validation errors
        if (responseData.containsKey('validation')) {
          final validation = responseData['validation'];
          if (validation is Map && validation.isNotEmpty) {
            final firstField = validation.keys.first;
            final fieldErrors = validation[firstField];
            if (fieldErrors is List && fieldErrors.isNotEmpty) {
              return fieldErrors.first.toString();
            }
          }
        }
      }

      // Handle List response (sometimes errors come as arrays)
      if (responseData is List && responseData.isNotEmpty) {
        return responseData.first.toString();
      }
    } catch (e) {
      // If extraction fails, return null to use default message
      return null;
    }

    return null;
  }

  /// Handle generic exceptions
  static AppException handleGenericException(dynamic error) {
    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      return handleDioException(error);
    }

    // Handle other types of exceptions
    final errorMessage = error.toString();

    if (errorMessage.contains('FormatException') || errorMessage.contains('type')) {
      return AppException(message: 'Invalid data format. Please try again.', originalError: error);
    }

    return AppException(message: 'An unexpected error occurred. Please try again.', originalError: error);
  }
}
