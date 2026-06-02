import 'package:omeeba_new/core/utils/exports.dart';

import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import '../models/api_response.dart';
import '../utils/app_constant.dart';
import '../utils/app_prefrence.dart';

/// Performs a backend-only purchase status verification call.
/// This is intentionally silent (no toast/snackbar/UI feedback).
class PurchaseStatusApiService {
  final ApiClient _apiClient = ApiClient();

  Future<void> verifySilently() async {
    try {
      final token = PrefService.getString(PrefKeys.accessToken);
      await _apiClient.request(
        url: '$baseUrl${ApiEndpoints.purchaseStatus}',
        type: RequestType.get,
        headers: {if (token.isNotEmpty) 'Authorization': 'Bearer $token'},
        onSuccess: (ApiResponse response) {
          // Debug log only; no user-facing UI.
          debugPrint('Purchase status success: ${response.toJson()}');
        },
      );
    } catch (_) {
      // Intentionally ignored: this call is for backend-side verification only.
    }
  }
}
