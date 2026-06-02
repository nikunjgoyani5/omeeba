import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/models/reports_categories_model.dart';
import '../../../../core/repository/post_repository.dart';
import '../../../../core/repository/report_repository.dart';
import '../../../../core/utils/app_functions.dart';

enum ReportStep { selectCategory, selectSubCategory, addDetails, submitted }

class ReportController extends GetxController {
  Rx<ReportStep> currentStep = ReportStep.selectCategory.obs;
  Rx<ReportsCategory?> selectedCategory = Rx<ReportsCategory?>(null);
  Rx<ReportsCategory?> selectedSubCategory = Rx<ReportsCategory?>(null);
  RxString reportDetails = ''.obs;
  RxString reportSubmitMessage = ''.obs;
  final TextEditingController detailsController = TextEditingController();
  final int maxCharacters = 280;
  final ReportRepository _postsRepo = Get.find<ReportRepository>();
  final RxList<ReportsCategory> reportsCategories = <ReportsCategory>[].obs;
  PostRepository postRepository = PostRepository();
  final RxBool isReportCategoriesLoading = false.obs;
  final RxBool isReportSubmitting = false.obs;
  final RxBool hasCalledApi = false.obs;
  @override
  void onInit() {
    super.onInit();
    detailsController.addListener(() {
      reportDetails.value = detailsController.text;
    });
  }

  @override
  void onClose() {
    detailsController.dispose();
    super.onClose();
  }

  Future<void> getReportsCategories(BuildContext context) async {
    if (hasCalledApi.value || isReportCategoriesLoading.value) {
      return; // Prevent duplicate API calls
    }

    hasCalledApi.value = true;
    isReportCategoriesLoading.value = true;
    reportsCategories.clear(); // Clear previous data

    _postsRepo.getReportsCategories(
      onSuccess: (data) {
        if (data.categories != null) {
          reportsCategories.addAll(data.categories!);
        }
        isReportCategoriesLoading.value = false;
        update();
      },
      onError: (error) {
        isReportCategoriesLoading.value = false;
        AppFunctions.showCustomToast(context, message: error.message, isSuccess: false);
      },
    );
  }

  Future<void> submitReport(BuildContext context, {required String contentId, required String contentType}) async {
    isReportSubmitting.value = true;
    _postsRepo.submitReport(
      body: {
        "contentType": contentType,
        "contentId": contentId,
        "subCategoryId": selectedSubCategory.value?.id,
        "details": detailsController.text.trim(),
      },
      onSuccess: (data) {
        isReportSubmitting.value = false;
        currentStep.value = ReportStep.submitted;
        reportSubmitMessage.value = data.message ?? "";
        update();
      },
      onError: (error) {
        isReportSubmitting.value = false;
        AppFunctions.showCustomToast(context, message: error.message, isSuccess: false);
      },
    );
  }

  Future<void> reportComment(BuildContext context,{required String commentId}) async {
    try {
      await postRepository.reportComment(
        id: commentId,
        body: {

          "subCategoryId": selectedSubCategory.value?.id,
          "details": detailsController.text.trim(),
        },

        onSuccess: (data) {
          isReportSubmitting.value = false;
          currentStep.value = ReportStep.submitted;
          reportSubmitMessage.value = data.message ?? "";
          update();

        },
        onError: (AppException error) {
          isReportSubmitting.value = false;
          AppFunctions.showCustomToast(context, message: error.message, isSuccess: false);
        },
      );
    } catch (error) {

      debugPrint('like unlike error ${error.toString()}');
    }
  }

  Future<void> reportToReplyComment(BuildContext context,{required String commentId}) async {
    try {
      await postRepository.reportToReplyComment(
        id: commentId,
        body: {

          "subCategoryId": selectedSubCategory.value?.id,
          "details": detailsController.text.trim(),
        },

        onSuccess: (data) {
          isReportSubmitting.value = false;
          currentStep.value = ReportStep.submitted;
          reportSubmitMessage.value = data.message ?? "";
          update();

        },
        onError: (AppException error) {
          isReportSubmitting.value = false;
          AppFunctions.showCustomToast(context, message: error.message, isSuccess: false);
        },
      );
    } catch (error) {

      debugPrint('like unlike error ${error.toString()}');
    }
  }

  void selectCategory(ReportsCategory category) {
    selectedCategory.value = category;
    if (category.subCategories != null && category.subCategories!.isNotEmpty) {
      currentStep.value = ReportStep.selectSubCategory;
    } else {
      currentStep.value = ReportStep.addDetails;
    }
  }

  void selectSubCategory(ReportsCategory subCategory) {
    selectedSubCategory.value = subCategory;
    currentStep.value = ReportStep.addDetails;
  }

  void goBack() {
    switch (currentStep.value) {
      case ReportStep.selectSubCategory:
        currentStep.value = ReportStep.selectCategory;
        selectedSubCategory.value = null;
        break;
      case ReportStep.addDetails:
        if (selectedCategory.value != null &&
            selectedCategory.value!.subCategories != null &&
            selectedCategory.value!.subCategories!.isNotEmpty) {
          currentStep.value = ReportStep.selectSubCategory;
        } else {
          currentStep.value = ReportStep.selectCategory;
        }
        break;
      case ReportStep.submitted:
        currentStep.value = ReportStep.addDetails;
        break;
      default:
        break;
    }
  }

  void reset() {
    currentStep.value = ReportStep.selectCategory;
    selectedCategory.value = null;
    selectedSubCategory.value = null;
    reportDetails.value = '';
    detailsController.clear();
    hasCalledApi.value = false; // Reset API call flag
    reportsCategories.clear(); // Clear categories for fresh data
  }

  bool get canSubmit => reportDetails.value.trim().isNotEmpty;
}
