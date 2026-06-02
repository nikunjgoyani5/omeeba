import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/repository/base_repository.dart';
import 'package:omeeba_new/core/services/api_endpoints.dart';
import 'package:omeeba_new/core/services/api_service.dart';

class ContactRepository extends BaseRepository {
  ContactRepository({super.apiClient});

  /// POST [ApiEndpoints.contact] with JSON body.
  Future<void> submitContact({
    required String name,
    required String email,
    required String subject,
    required String message,
    void Function(ApiResponse data)? onSuccess,
    void Function(AppException error)? onError,
  }) async {
    await apiClient.request(
      url: getFullUrl(ApiEndpoints.contact),
      type: RequestType.post,
      body: {
        'name': name,
        'email': email,
        'subject': subject,
        'message': message,
      },
      onSuccess: (response) {
        if (!response.isSuccess) {
          onError?.call(AppException(message: response.message ?? 'Request failed'));
          return;
        }
        onSuccess?.call(response);
      },
      onError: onError,
    );
  }
}
