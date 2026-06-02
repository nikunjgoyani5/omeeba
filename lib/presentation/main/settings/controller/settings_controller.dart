import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/auth_repository.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import 'package:omeeba_new/core/repository/post_repository.dart';
import 'package:omeeba_new/core/services/verified_badge_iap_service.dart';
import 'package:omeeba_new/core/services/verified_badge_purchase_api_service.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';
import 'package:omeeba_new/core/utils/validators.dart';
import 'package:omeeba_new/presentation/main/home/controller/home_controller.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../../../core/repository/home_repository.dart';
import '../../myprofile/controller/my_profile_controller.dart';

class SettingsController extends GetxController {
  // iOS Product IDs
  static const String verifiedBadgeWeeklyIdIOS = 'omeeba_weekly_subscription';
  static const String verifiedBadgeMonthlyIdIOS = 'omeeba_monthly_subscription';
  static const String verifiedBadgeYearlyIdIOS = 'omeeba_yearly_subscription';

  // Android Product IDs (keeping existing ones, update if needed)
  static const String verifiedBadgeWeeklyIdAndroid = 'orange_tick_weekly';
  static const String verifiedBadgeMonthlyIdAndroid = 'orange_tick_monthly';
  static const String verifiedBadgeYearlyIdAndroid = 'orange_tick_yearly';

  // Platform-specific product IDs getter
  static Set<String> get verifiedBadgeProductIds {
    if (Platform.isIOS) {
      return {
        verifiedBadgeWeeklyIdIOS,
        verifiedBadgeMonthlyIdIOS,
        verifiedBadgeYearlyIdIOS,
      };
    } else {
      return {
        verifiedBadgeWeeklyIdAndroid,
        verifiedBadgeMonthlyIdAndroid,
        verifiedBadgeYearlyIdAndroid,
      };
    }
  }

  // Getter for current platform's weekly ID
  static String get verifiedBadgeWeeklyId =>
      Platform.isIOS ? verifiedBadgeWeeklyIdIOS : verifiedBadgeWeeklyIdAndroid;

  // Getter for current platform's monthly ID
  static String get verifiedBadgeMonthlyId => Platform.isIOS
      ? verifiedBadgeMonthlyIdIOS
      : verifiedBadgeMonthlyIdAndroid;

  // Getter for current platform's yearly ID
  static String get verifiedBadgeYearlyId =>
      Platform.isIOS ? verifiedBadgeYearlyIdIOS : verifiedBadgeYearlyIdAndroid;

  MyProfileController? myProfileController;
  TextEditingController currentPassword = TextEditingController();
  TextEditingController newPassword = TextEditingController();
  TextEditingController reTypingPassword = TextEditingController();
  final HomeRepository _homeRepo = Get.find<HomeRepository>();
  bool isSecure = false;
  bool isSecureCurrent = false;
  bool isConfirmPasswordSecure = false;
  RxBool isNotificationOn = false.obs;

  final PostRepository _postRepository = PostRepository();
  static const int _savedLimit = 10;

  final VerifiedBadgeIapService _verifiedBadgeIapService =
      VerifiedBadgeIapService();
  final VerifiedBadgePurchaseApiService _verifiedBadgePurchaseApiService =
      VerifiedBadgePurchaseApiService();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _verifiedBadgePurchaseTimeout;

  final RxBool verifiedBadgeIapAvailable = false.obs;
  final RxBool verifiedBadgePlansLoading = false.obs;
  final RxnString verifiedBadgePlansError = RxnString();
  final RxList<ProductDetails> verifiedBadgePlans = <ProductDetails>[].obs;

  /// Default selected plan is monthly.
  final RxString selectedVerifiedBadgePlanId = verifiedBadgeMonthlyId.obs;

  final RxBool verifiedBadgePurchaseInProgress = false.obs;
  final RxnString verifiedBadgePurchaseError = RxnString();

  ProductDetails? get selectedVerifiedBadgePlan {
    for (final p in verifiedBadgePlans) {
      if (p.id == selectedVerifiedBadgePlanId.value) return p;
    }
    return verifiedBadgePlans.isNotEmpty ? verifiedBadgePlans.first : null;
  }

  void selectVerifiedBadgePlan(String productId) {
    selectedVerifiedBadgePlanId.value = productId;
  }

  Future<void> loadVerifiedBadgePlansIfNeeded({bool force = false}) async {
    if (!force && verifiedBadgePlans.isNotEmpty) {
      _ensureDefaultPlanSelection();
      return;
    }

    verifiedBadgePlansLoading.value = true;
    verifiedBadgePlansError.value = null;

    try {
      final available = await _verifiedBadgeIapService.isAvailable();
      verifiedBadgeIapAvailable.value = available;
      if (!available) {
        verifiedBadgePlansLoading.value = false;
        verifiedBadgePlansError.value =
            'In-app purchases are not available on this device.';
        return;
      }

      final response = await _verifiedBadgeIapService.queryProducts(
        verifiedBadgeProductIds,
      );

      // Check for StoreKit errors
      if (response.error != null) {
        verifiedBadgePlansLoading.value = false;
        final errorCode = response.error!.code;
        final errorMessage = response.error!.message;

        // Provide more helpful error messages based on error code
        String userFriendlyMessage;
        if (errorCode == 'storekit_unknown' ||
            errorMessage.contains('Failed to get response')) {
          userFriendlyMessage =
              'Unable to connect to App Store. Please check:\n'
              '1. Your internet connection\n'
              '2. Products are configured in App Store Connect\n'
              '3. You are signed in with a sandbox tester account (for testing)\n'
              '4. Product IDs match: ${verifiedBadgeProductIds.join(", ")}';
        } else {
          userFriendlyMessage = errorMessage.isNotEmpty
              ? errorMessage
              : 'Failed to load subscription plans. Error code: $errorCode';
        }

        verifiedBadgePlansError.value = userFriendlyMessage;
        return;
      }

      final plans = response.productDetails.toList();

      // Check if products were found - StoreKit can return empty list even without error
      if (plans.isEmpty) {
        verifiedBadgePlansLoading.value = false;
        final notFoundIds = response.notFoundIDs;
        if (notFoundIds.isNotEmpty) {
          verifiedBadgePlansError.value =
              'Products not found in App Store Connect:\n'
              '${notFoundIds.join(", ")}\n\n'
              'Please ensure these products are:\n'
              '1. Created in App Store Connect\n'
              '2. Approved and available\n'
              '3. Match the exact product IDs';
        } else {
          verifiedBadgePlansError.value =
              'No subscription plans found. Please ensure products are configured in App Store Connect:\n'
              '${verifiedBadgeProductIds.join(", ")}';
        }
        verifiedBadgePlans.clear();
        return;
      }

      plans.sort(
        (a, b) => _verifiedBadgePlanSortKey(
          a.id,
        ).compareTo(_verifiedBadgePlanSortKey(b.id)),
      );
      verifiedBadgePlans.assignAll(plans);
      _ensureDefaultPlanSelection();

      verifiedBadgePlansLoading.value = false;
    } catch (e) {
      verifiedBadgePlansLoading.value = false;
      verifiedBadgePlansError.value =
          'Failed to load subscription plans: ${e.toString()}';
      verifiedBadgePlans.clear();
    }
  }

  int _verifiedBadgePlanSortKey(String productId) {
    // Check for weekly (both iOS and Android)
    if (productId == verifiedBadgeWeeklyIdIOS ||
        productId == verifiedBadgeWeeklyIdAndroid) {
      return 1;
    }
    // Check for monthly (both iOS and Android)
    if (productId == verifiedBadgeMonthlyIdIOS ||
        productId == verifiedBadgeMonthlyIdAndroid) {
      return 2;
    }
    // Check for yearly (both iOS and Android)
    if (productId == verifiedBadgeYearlyIdIOS ||
        productId == verifiedBadgeYearlyIdAndroid) {
      return 3;
    }
    return 99;
  }

  void _ensureDefaultPlanSelection() {
    final currentId = selectedVerifiedBadgePlanId.value;
    final currentExists = verifiedBadgePlans.any((p) => p.id == currentId);
    if (currentExists) return;

    final hasMonthly = verifiedBadgePlans.any(
      (p) => p.id == verifiedBadgeMonthlyId,
    );
    if (hasMonthly) {
      selectedVerifiedBadgePlanId.value = verifiedBadgeMonthlyId;
      return;
    }
    if (verifiedBadgePlans.isNotEmpty) {
      selectedVerifiedBadgePlanId.value = verifiedBadgePlans.first.id;
    }
  }

  Future<void> purchaseSelectedVerifiedBadgePlan(BuildContext context) async {
    final product = selectedVerifiedBadgePlan;
    if (product == null) {
      AppFunctions.showCustomToast(
        context,
        message: 'Plans not loaded yet.',
        isSuccess: false,
      );
      return;
    }

    verifiedBadgePurchaseError.value = null;
    verifiedBadgePurchaseInProgress.value = true;
    _startVerifiedBadgePurchaseTimeout();
    try {
      final started = await _verifiedBadgeIapService.buySubscription(product);
      if (!started) {
        _cancelVerifiedBadgePurchaseTimeout();
        verifiedBadgePurchaseInProgress.value = false;
        verifiedBadgePurchaseError.value = 'Unable to start purchase';
        _showVerifiedBadgeToast('Unable to start purchase.');
      }
    } catch (e) {
      _cancelVerifiedBadgePurchaseTimeout();
      verifiedBadgePurchaseInProgress.value = false;
      verifiedBadgePurchaseError.value = 'Unable to start purchase';
      _showVerifiedBadgeToast('Unable to start purchase.');
    }
  }

  Future<void> restoreVerifiedBadgePurchases() async {
    verifiedBadgePurchaseError.value = null;
    verifiedBadgePurchaseInProgress.value = true;
    _startVerifiedBadgePurchaseTimeout();
    try {
      await _verifiedBadgeIapService.restorePurchases();
    } catch (e) {
      _cancelVerifiedBadgePurchaseTimeout();
      verifiedBadgePurchaseInProgress.value = false;
      verifiedBadgePurchaseError.value = 'Restore failed';
      _showVerifiedBadgeToast('Restore failed.');
    }
  }

  /// Call when the Verified Badge / Choose Plan sheet is closed so the button
  /// does not stay on "Processing..." if the user dismissed the IAP dialog.
  void clearVerifiedBadgePurchaseState() {
    _verifiedBadgePurchaseTimeout?.cancel();
    _verifiedBadgePurchaseTimeout = null;
    verifiedBadgePurchaseInProgress.value = false;
    verifiedBadgePurchaseError.value = null;
  }

  /// Uses overlay-free Fluttertoast so it's safe from Timer/stream callbacks
  /// (Get.context can be root and has no overlay, causing FToast to throw).
  void _showVerifiedBadgeToast(String message, {bool isSuccess = false}) {
    try {
      AppFunctions().showToast(
        message,
        bgColor: isSuccess ? AppColors.green : AppColors.red,
        textColor: Colors.white,
      );
    } catch (_) {
      // Avoid unhandled exception if toast fails
    }
  }

  void _cancelVerifiedBadgePurchaseTimeout() {
    _verifiedBadgePurchaseTimeout?.cancel();
    _verifiedBadgePurchaseTimeout = null;
  }

  void _startVerifiedBadgePurchaseTimeout() {
    _verifiedBadgePurchaseTimeout?.cancel();
    _verifiedBadgePurchaseTimeout = Timer(const Duration(seconds: 5), () {
      try {
        if (verifiedBadgePurchaseInProgress.value) {
          verifiedBadgePurchaseInProgress.value = false;
          verifiedBadgePurchaseError.value = null;
          _showVerifiedBadgeToast('Purchase cancelled or closed.');
        }
      } finally {
        _verifiedBadgePurchaseTimeout = null;
      }
    });
  }

  Future<void> _handleVerifiedBadgePurchaseSuccess({
    required PurchaseDetails purchase,
    required String productId,
  }) async {
    await _verifiedBadgePurchaseApiService.syncVerifiedBadgePurchase(
      productId: productId,
      purchase: purchase,
    );
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!verifiedBadgeProductIds.contains(purchase.productID)) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          verifiedBadgePurchaseInProgress.value = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _cancelVerifiedBadgePurchaseTimeout();
          verifiedBadgePurchaseInProgress.value = false;
          verifiedBadgePurchaseError.value = null;
          await _handleVerifiedBadgePurchaseSuccess(
            purchase: purchase,
            productId: purchase.productID,
          );
          await _verifiedBadgeIapService.completePurchaseIfNeeded(purchase);
          while (Get.isBottomSheetOpen ?? false) {
            Get.back();
          }
          // Get.to(() => const VerifiedBadgeSuccess());
          break;
        case PurchaseStatus.error:
          _cancelVerifiedBadgePurchaseTimeout();
          verifiedBadgePurchaseInProgress.value = false;
          final errorMsg = purchase.error?.message ?? 'Purchase failed';
          verifiedBadgePurchaseError.value = errorMsg;
          _showVerifiedBadgeToast(errorMsg);
          break;
        case PurchaseStatus.canceled:
          _cancelVerifiedBadgePurchaseTimeout();
          verifiedBadgePurchaseInProgress.value = false;
          verifiedBadgePurchaseError.value = 'Purchase cancelled';
          _showVerifiedBadgeToast('Purchase cancelled.');
          break;
      }
    }
  }

  /// Tab index 0=Post, 1=Zeal Post, 2=Write Post, 3=Poll
  static String _contentTypeForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Post';
      case 1:
        return 'Zeal Post';
      case 2:
        return 'Write Post';
      case 3:
        return 'Poll';
      default:
        return 'Post';
    }
  }

  final RxList<PostData> savedPosts = <PostData>[].obs;
  final RxBool savedPostsLoading = false.obs;
  final RxBool savedPostsLoadMoreLoading = false.obs;
  final RxInt savedPostsPage = 1.obs;
  final RxBool savedPostsHasNext = false.obs;

  final RxList<PostData> savedZeals = <PostData>[].obs;
  final RxBool savedZealsLoading = false.obs;
  final RxBool savedZealsLoadMoreLoading = false.obs;
  final RxInt savedZealsPage = 1.obs;
  final RxBool savedZealsHasNext = false.obs;

  final RxList<PostData> savedWrites = <PostData>[].obs;
  final RxBool savedWritesLoading = false.obs;
  final RxBool savedWritesLoadMoreLoading = false.obs;
  final RxInt savedWritesPage = 1.obs;
  final RxBool savedWritesHasNext = false.obs;

  final RxList<PostData> savedPolls = <PostData>[].obs;
  final RxBool savedPollsLoading = false.obs;
  final RxBool savedPollsLoadMoreLoading = false.obs;
  final RxInt savedPollsPage = 1.obs;
  final RxBool savedPollsHasNext = false.obs;

  RxList<PostData> _listForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return savedPosts;
      case 1:
        return savedZeals;
      case 2:
        return savedWrites;
      case 3:
        return savedPolls;
      default:
        return savedPosts;
    }
  }

  RxBool _loadingForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return savedPostsLoading;
      case 1:
        return savedZealsLoading;
      case 2:
        return savedWritesLoading;
      case 3:
        return savedPollsLoading;
      default:
        return savedPostsLoading;
    }
  }

  RxBool _loadMoreLoadingForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return savedPostsLoadMoreLoading;
      case 1:
        return savedZealsLoadMoreLoading;
      case 2:
        return savedWritesLoadMoreLoading;
      case 3:
        return savedPollsLoadMoreLoading;
      default:
        return savedPostsLoadMoreLoading;
    }
  }

  RxInt _pageForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return savedPostsPage;
      case 1:
        return savedZealsPage;
      case 2:
        return savedWritesPage;
      case 3:
        return savedPollsPage;
      default:
        return savedPostsPage;
    }
  }

  RxBool _hasNextForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return savedPostsHasNext;
      case 1:
        return savedZealsHasNext;
      case 2:
        return savedWritesHasNext;
      case 3:
        return savedPollsHasNext;
      default:
        return savedPostsHasNext;
    }
  }

  List<PostData> _parseSavedData(dynamic data) {
    if (data == null) return [];
    if (data is! List) return [];
    final list = <PostData>[];
    for (final e in data) {
      if (e is Map<String, dynamic>) {
        list.add(PostData.fromJson(e));
      } else if (e is Map) {
        list.add(PostData.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    for (final p in list) {
      p.isSaved = true;
    }
    return list;
  }

  /// Load saved content for tab. Call when screen opens (tab 0) or when user switches tab.
  Future<void> loadSavedContent(int tabIndex, {bool refresh = true}) async {
    final loading = _loadingForTab(tabIndex);
    final list = _listForTab(tabIndex);
    final page = _pageForTab(tabIndex);
    final hasNext = _hasNextForTab(tabIndex);
    if (loading.value && !refresh) return;
    loading.value = true;
    final currentPage = refresh ? 1 : page.value;
    if (refresh) {
      page.value = 1;
      hasNext.value = false;
    }

    await _postRepository.getSavedList(
      contentType: _contentTypeForTab(tabIndex),
      page: currentPage,
      limit: _savedLimit,
      onSuccess: (ApiResponse response) {
        final parsed = _parseSavedData(response.data);
        if (refresh) {
          list.assignAll(parsed);
        } else {
          list.addAll(parsed);
        }
        final p = response.pagination;
        if (p != null) {
          page.value = p.page ?? currentPage;
          hasNext.value = p.hasNext ?? false;
        }
        loading.value = false;
      },
      onError: (AppException error) {
        loading.value = false;
      },
    );
  }

  /// Remove item from saved list immediately and call save (toggle) API in background. On error, re-insert and show toast.
  void unsaveAndRemoveFromList(
    BuildContext context,
    String type,
    String postId,
    RxList<PostData> list,
    int index,
  ) {
    if (index < 0 || index >= list.length) return;
    final removed = list[index];
    list.removeAt(index);
    list.refresh();

    _postRepository.savePost(
      data: {"contentType": type, "contentId": postId},
      onSuccess: (ApiResponse response) {
        Get.find<HomeController>().feedData.value!.posts![index].isSaved = response.data['isSaved'];
        Get.find<HomeController>().feedData.refresh();
      },
      onError: (AppException error) {
        list.insert(index, removed);
        list.refresh();
        AppFunctions.showCustomToast(
          context,
          message: error.message,
          isSuccess: false,
        );
      },
    );
  }

  /// Load more for current tab (pagination).
  Future<void> loadMoreSavedContent(int tabIndex) async {
    final loadMoreLoading = _loadMoreLoadingForTab(tabIndex);
    final hasNext = _hasNextForTab(tabIndex);
    final page = _pageForTab(tabIndex);
    if (loadMoreLoading.value || !hasNext.value) return;
    loadMoreLoading.value = true;
    final nextPage = page.value + 1;
    await _postRepository.getSavedList(
      contentType: _contentTypeForTab(tabIndex),
      page: nextPage,
      limit: _savedLimit,
      onSuccess: (ApiResponse response) {
        final parsed = _parseSavedData(response.data);
        _listForTab(tabIndex).addAll(parsed);
        final p = response.pagination;
        if (p != null) {
          page.value = p.page ?? nextPage;
          hasNext.value = p.hasNext ?? false;
        }
        loadMoreLoading.value = false;
      },
      onError: (_) {
        loadMoreLoading.value = false;
      },
    );
  }

  @override
  void onInit() {
    if (Get.isRegistered<MyProfileController>()) {
      myProfileController = Get.find<MyProfileController>();
    }
    initNotification();
    _purchaseSubscription = _verifiedBadgeIapService.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (e) {
        _cancelVerifiedBadgePurchaseTimeout();
        verifiedBadgePurchaseInProgress.value = false;
        final msg = e?.toString() ?? 'Purchase failed';
        verifiedBadgePurchaseError.value = msg;
        _showVerifiedBadgeToast(msg);
      },
    );
    super.onInit();
  }

  @override
  void onClose() {
    _verifiedBadgePurchaseTimeout?.cancel();
    _purchaseSubscription?.cancel();
    currentPassword.dispose();
    newPassword.dispose();
    reTypingPassword.dispose();
    super.onClose();
  }

  initNotification() async {
    final box = Hive.box('settings');
    bool? savedValue = box.get('notification_status');
    if (savedValue != null) {
      isNotificationOn.value = savedValue;
      if (savedValue) {
        await OneSignal.User.pushSubscription.optIn();
      } else {
        await OneSignal.User.pushSubscription.optOut();
      }
    } else {
      bool isSubscribed = OneSignal.User.pushSubscription.optedIn ?? false;
      isNotificationOn.value = isSubscribed;
      await box.put('notification_status', isSubscribed);
    }
  }

  RxBool isLoading = false.obs;
  AuthRepository authRepository = AuthRepository();

  String passwordError = '';
  String cPassError = '';
  String currentPassError = '';

  bool onTapChangePass() {
    validatePass();
    validateCPass();
    validateCurrentPass();

    if (passwordError.isEmpty &&
        cPassError.isEmpty &&
        currentPassError.isEmpty) {
      return true;
    } else {
      return false;
    }
  }

  validatePass() {
    passwordError = ValidationUtils.validatePassword(newPassword.text) ?? '';
    update();
  }

  validateCurrentPass() {
    if (currentPassword.text.isEmpty) {
      currentPassError = "Password is required";
    } else {
      currentPassError = '';
    }
    update();
  }

  validateCPass() {
    if (reTypingPassword.text.isEmpty) {
      cPassError = "Password is required";
    } else if (newPassword.text.isNotEmpty &&
        newPassword.text != reTypingPassword.text) {
      cPassError = "Password doesn't match";
    } else {
      cPassError = '';
    }
    update();
  }

  void updateCommentCount(String postId, int newCount) {
    final list = savedPosts; // or zeals
    final index = list.indexWhere((e) => e.id == postId);
    if (index != -1) {
      list[index].commentCount = newCount;
      list.refresh();
    }
  }

  Future<void> changePassApi(BuildContext context) async {
    isLoading.value = true;
    await authRepository.changePassword(
      body: {
        "oldPassword": currentPassword.text,
        "newPassword": newPassword.text,
      },
      onSuccess: (ApiResponse response) {
        try {
          isLoading.value = false;
          Get.back();
          currentPassword.clear();
          newPassword.clear();
          reTypingPassword.clear();
          AppFunctions.showCustomToast(
            context,
            message: response.message ?? 'Password changed!',
            isSuccess: true,
          );
        } catch (e) {
          debugPrint('error:::${e.toString()} ');
          isLoading.value = false;
          AppFunctions.showCustomToast(
            context,
            message: response.message ?? 'Something went wrong!!',
            isSuccess: false,
          );
        }
      },
      onError: (AppException error) {
        isLoading.value = false;
        String message = error.message;
        AppFunctions.showCustomToast(
          context,
          message: message,
          isSuccess: false,
        );
      },
    );
    isLoading.value = false;
  }

  void submitPollVote(String postId, String optionId) {
    final list = savedPolls;
    final index = list.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    final post = list[index];
    if (post.hasVoted == true) return;
    final opts = post.options;
    if (opts == null || opts.isEmpty) return;

    final previousPost = PostData(
      id: post.id,
      contentType: post.contentType,
      userId: post.userId,
      mentionedUsers: post.mentionedUsers,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      shareCount: post.shareCount,
      isLiked: post.isLiked,
      isSaved: post.isSaved,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      caption: post.caption,
      images: post.images,
      videos: post.videos,
      mediaUrl: post.mediaUrl,
      thumbnailUrl: post.thumbnailUrl,
      music: post.music,
      musicStartTime: post.musicStartTime,
      musicEndTime: post.musicEndTime,
      content: post.content,
      options: opts
          .map(
            (o) => PollOptionItem(
              optionId: o.optionId,
              optionText: o.optionText,
              voteCount: o.voteCount,
              votePercentage: o.votePercentage,
            ),
          )
          .toList(),
      totalVotes: post.totalVotes,
      status: post.status,
      duration: post.duration,
      hasVoted: post.hasVoted,
      votedOptionId: post.votedOptionId,
      createdBy: post.createdBy,
    );

    final currentTotal = post.totalVotes ?? 0;
    final newTotal = currentTotal + 1;
    final newOptions = <PollOptionItem>[];
    for (final o in opts) {
      final isSelected = o.optionId == optionId;
      final count = (o.voteCount ?? 0) + (isSelected ? 1 : 0);
      newOptions.add(
        PollOptionItem(
          optionId: o.optionId,
          optionText: o.optionText,
          voteCount: count,
          votePercentage: newTotal > 0 ? ((count / newTotal) * 100).round() : 0,
        ),
      );
    }
    final optimisticPost = post.copyWith(
      options: newOptions,
      totalVotes: newTotal,
      hasVoted: true,
      votedOptionId: optionId,
    );
    _setMyPollsAt(index, optimisticPost);

    _homeRepo.submitPollVote(
      pollId: postId,
      optionId: optionId,
      onSuccess: (updatedPost) {
        final currentList = savedPolls;
        if (index >= currentList.length || currentList[index].id != postId)
          return;
        final current = currentList[index];
        final merged = current.copyWith(
          options: updatedPost?.options ?? current.options,
          totalVotes: updatedPost?.totalVotes ?? current.totalVotes,
          hasVoted: updatedPost?.hasVoted ?? true,
          votedOptionId: updatedPost?.votedOptionId ?? optionId,
        );
        _setMyPollsAt(index, merged);
      },
      onError: (_) {
        final currentList = savedPolls;
        if (index < currentList.length && currentList[index].id == postId) {
          _setMyPollsAt(index, previousPost);
        }
      },
    );
  }

  void _setMyPollsAt(int index, PostData newPost) {
    final list = savedPolls;
    if (index < 0 || index >= list.length) return;
    final updated = List<PostData>.from(list)..[index] = newPost;
    savedPolls.value = updated;
  }

  NotificationRepository notificationRepository = NotificationRepository();

  Future<void> toggleNotification(BuildContext context) async {
    final box = Hive.box('settings');
    bool newValue = isNotificationOn.value;
    isLoading.value = true;
    await notificationRepository.toggleNotification(
      data: {"enabled": isNotificationOn.value},
      onSuccess: (ApiResponse response) async {
        try {
          if (isNotificationOn.value) {
            await OneSignal.User.pushSubscription.optOut();
          } else {
            await OneSignal.User.pushSubscription.optIn();
          }
          box.put('notification_status', newValue); // add new for
          bool isSubscribed = OneSignal.User.pushSubscription.optedIn ?? false;

          print('ONe signal ======$isSubscribed');
        } catch (e) {
          isNotificationOn.value = (!isNotificationOn.value);
        }
      },
      onError: (AppException error) {
        isNotificationOn.value = (!isNotificationOn.value);
      },
    );
  }
}
