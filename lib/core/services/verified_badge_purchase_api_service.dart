import 'dart:developer' as developer;
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:omeeba_new/presentation/main/myprofile/controller/my_profile_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';
import '../exceptions/app_exception.dart';
import '../models/api_response.dart';
import '../utils/app_constant.dart';
import '../utils/exports.dart';

class VerifiedBadgePurchaseApiService {
  final ApiClient _apiClient = ApiClient();
  String? _cachedPackageName;

  Future<void> syncVerifiedBadgePurchase({
    required String productId,
    required PurchaseDetails purchase,
  }) async {
    try {
      developer.log(
        'Verifying purchase. productId=$productId purchaseId=${purchase.purchaseID} status=${purchase.status}',
        name: 'VerifiedBadgePurchaseApiService',
      );

      // Determine which endpoint to use based on platform
      final endpoint = Platform.isIOS
          ? ApiEndpoints.verifyApplePurchase
          : ApiEndpoints.verifyGooglePurchase;

      final url = '$baseUrl$endpoint';

      Map<String, dynamic> requestBody;

      if (Platform.isIOS) {
        // iOS: Send receiptData and productId
        // For StoreKit 2, serverVerificationData contains a JWT token
        // For StoreKit 1, it contains base64-encoded receipt
        final receiptData = _extractReceiptData(purchase);

        if (receiptData.isEmpty) {
          developer.log(
            'Warning: Receipt data is empty for purchase ${purchase.purchaseID}',
            name: 'VerifiedBadgePurchaseApiService',
          );
          return;
        }

        // Detect receipt format: StoreKit 2 uses JWT tokens (starts with "eyJ")
        // StoreKit 1 uses base64-encoded receipts
        final isJWT = receiptData.startsWith('eyJ');
        final receiptFormat = isJWT ? 'JWT' : 'Base64';

        developer.log(
          'Receipt data format: ${isJWT ? "JWT (StoreKit 2)" : "Base64 (StoreKit 1)"}\n'
          'Receipt data preview: ${receiptData.substring(0, receiptData.length > 100 ? 100 : receiptData.length)}...\n'
          'Full receipt data: $receiptData',
          name: 'VerifiedBadgePurchaseApiService',
        );

        // Send receipt data with format indicator to help backend
        // Backend should use App Store Server API for JWT tokens
        // Backend should use old receipt validation API for Base64 receipts
        requestBody = {
          'receiptData': "$receiptData",
          'productId': productId,
          'receiptFormat': receiptFormat, // Help backend identify format
        };

        developer.log(
          'Calling iOS verification API: $url\n'
          'productId: $productId\n'
          'receiptData length: ${receiptData.length}\n'
          'receiptFormat: $receiptFormat\n'
          'Note: Backend must use App Store Server API for JWT tokens',
          name: 'VerifiedBadgePurchaseApiService',
        );
      } else {
        // Android: Send productId, packageName, and purchaseToken
        final purchaseToken = _extractReceiptData(purchase);
        final packageName = await _getPackageName();

        if (purchaseToken.isEmpty) {
          developer.log(
            'Warning: Purchase token is empty for purchase ${purchase.purchaseID}',
            name: 'VerifiedBadgePurchaseApiService',
          );
        }

        if (packageName.isEmpty) {
          developer.log(
            'Error: Package name is empty',
            name: 'VerifiedBadgePurchaseApiService',
          );
          return;
        }

        requestBody = {
          'productId': productId,
          'packageName': packageName,
          'purchaseToken': purchaseToken,
        };

        developer.log(
          'Calling Android verification API: $url\n'
          'productId: $productId\n'
          'packageName: $packageName\n'
          'purchaseToken length: ${purchaseToken.length}',
          name: 'VerifiedBadgePurchaseApiService',
        );
      }

      // Call verification API
      await _apiClient.request(
        url: url,
        type: RequestType.post,
        body: requestBody,
        onSuccess: (ApiResponse response) {
          developer.log(
            'Purchase verification successful: ${response.message}',
            name: 'VerifiedBadgePurchaseApiService',
          );
          debugPrint('Purchase verified successfully: ${response.data}');
          Get.find<MyProfileController>().loadProfile(silent: true);
        },
        onError: (AppException error) {
          developer.log(
            'Purchase verification failed: ${error.message}',
            name: 'VerifiedBadgePurchaseApiService',
            error: error,
          );
          debugPrint('Purchase verification error: ${error.message}');
          // Note: We don't throw here to avoid blocking purchase completion
          // The purchase is already successful from StoreKit/Play Billing perspective
        },
      );
    } catch (e, stackTrace) {
      developer.log(
        'Exception verifying purchase: $e\n$stackTrace',
        name: 'VerifiedBadgePurchaseApiService',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('Exception verifying purchase: $e');
      // Don't throw - purchase is already successful from store perspective
    }
  }

  /// Get Android package name (cached for performance)
  Future<String> _getPackageName() async {
    if (_cachedPackageName != null) {
      return _cachedPackageName!;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _cachedPackageName = packageInfo.packageName;
      return _cachedPackageName!;
    } catch (e) {
      developer.log(
        'Error getting package name: $e',
        name: 'VerifiedBadgePurchaseApiService',
        error: e,
      );
      return '';
    }
  }

  /// Extract receipt data from purchase details
  /// For iOS StoreKit 2: serverVerificationData contains JWT token
  /// For iOS StoreKit 1: serverVerificationData contains base64 receipt
  /// For Android: serverVerificationData contains purchase token
  String _extractReceiptData(PurchaseDetails purchase) {
    try {
      final verificationData = purchase.verificationData;

      // Prefer serverVerificationData (more secure, recommended)
      if (verificationData.serverVerificationData.isNotEmpty) {
        final receiptData = verificationData.serverVerificationData;

        // Log what we're extracting
        developer.log(
          'Extracted receipt data from serverVerificationData\n'
          'Length: ${receiptData.length}\n'
          'Starts with: ${receiptData.substring(0, receiptData.length > 50 ? 50 : receiptData.length)}...\n'
          'Purchase ID: ${purchase.purchaseID}',
          name: 'VerifiedBadgePurchaseApiService',
        );

        return receiptData;
      }

      // Fallback: try localVerificationData (less secure, but might be needed)
      if (verificationData.localVerificationData.isNotEmpty) {
        developer.log(
          'Using localVerificationData as fallback for purchase ${purchase.purchaseID}\n'
          'Warning: localVerificationData is less secure than serverVerificationData',
          name: 'VerifiedBadgePurchaseApiService',
        );
        return verificationData.localVerificationData;
      }

      developer.log(
        'No receipt data found for purchase ${purchase.purchaseID}\n'
        'serverVerificationData empty: ${verificationData.serverVerificationData.isEmpty}\n'
        'localVerificationData empty: ${verificationData.localVerificationData.isEmpty}',
        name: 'VerifiedBadgePurchaseApiService',
      );
      return '';
    } catch (e, stackTrace) {
      developer.log(
        'Error extracting receipt data: $e\n$stackTrace',
        name: 'VerifiedBadgePurchaseApiService',
        error: e,
        stackTrace: stackTrace,
      );
      return '';
    }
  }
}
