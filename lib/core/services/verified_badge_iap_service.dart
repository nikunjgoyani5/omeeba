import 'dart:developer' as developer;
import 'dart:io';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../presentation/main/settings/widgets/subscription_purchase_success_dialog.dart';

class VerifiedBadgeIapService {
  VerifiedBadgeIapService({InAppPurchase? inAppPurchase})
      : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  Stream<List<PurchaseDetails>> get purchaseStream => _inAppPurchase.purchaseStream;

  Future<bool> isAvailable() async {
    try {
      return await _inAppPurchase.isAvailable();
    } catch (e) {
      developer.log('Error checking IAP availability: $e', name: 'VerifiedBadgeIapService');
      return false;
    }
  }

  Future<ProductDetailsResponse> queryProducts(Set<String> productIds) async {
    try {
      developer.log('Querying products: $productIds', name: 'VerifiedBadgeIapService');
      final response = await _inAppPurchase.queryProductDetails(productIds);

      if (response.error != null) {
        developer.log(
          'StoreKit error: ${response.error!.message}, code: ${response.error!.code}, details: ${response.error!.details}',
          name: 'VerifiedBadgeIapService',
        );
      }

      if (response.productDetails.isEmpty) {
        developer.log(
          'No products found. Requested IDs: $productIds. Not found IDs: ${response.notFoundIDs}',
          name: 'VerifiedBadgeIapService',
        );
      } else {
        developer.log(
          'Found ${response.productDetails.length} products: ${response.productDetails.map((p) => p.id).join(", ")}',
          name: 'VerifiedBadgeIapService',
        );
      }

      return response;
    } catch (e, stackTrace) {
      developer.log(
        'Exception querying products: $e\n$stackTrace',
        name: 'VerifiedBadgeIapService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> buySubscription(ProductDetails product) async {
    try {
      if(Platform.isAndroid){
        final GooglePlayProductDetails googleProduct =
        product as GooglePlayProductDetails;
        final offerToken =
            googleProduct.productDetails.subscriptionOfferDetails!.first.offerIdToken;
        final purchaseParam = GooglePlayPurchaseParam(productDetails: product,offerToken: offerToken);
        return _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }else{
        developer.log('Starting purchase for product: ${product.id}', name: 'VerifiedBadgeIapService');
        final purchaseParam = PurchaseParam(productDetails: product);
        return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }

    } catch (e) {
      developer.log('Error starting purchase: $e', name: 'VerifiedBadgeIapService', error: e);
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    try {
      developer.log('Restoring purchases...', name: 'VerifiedBadgeIapService');
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      developer.log('Error restoring purchases: $e', name: 'VerifiedBadgeIapService', error: e);
      rethrow;
    }
  }

  Future<void> completePurchaseIfNeeded(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      try {
        developer.log('Completing purchase: ${purchase.productID}', name: 'VerifiedBadgeIapService');
        await _inAppPurchase.completePurchase(purchase);
        SubscriptionPurchaseSuccessDialog.show(Get.context!);
      } catch (e) {
        developer.log('Error completing purchase: $e', name: 'VerifiedBadgeIapService', error: e);
        rethrow;
      }
    }
  }
}

