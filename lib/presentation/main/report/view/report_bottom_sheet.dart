import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/presentation/main/report/controller/report_controller.dart';
import 'package:omeeba_new/core/models/reports_categories_model.dart';
import 'dart:math' as math;

import '../../../../core/widgets/common_loader.dart';

class ReportBottomSheet extends StatelessWidget {
  const ReportBottomSheet({
    super.key,
    required this.postId,
    required this.postType,
    this.isCommentReport = false,
    this.isCommentIsReplyReport = false,
  });

  final String postId, postType;
  final bool isCommentReport;
  final bool isCommentIsReplyReport;

  /// Opens report bottom sheet. Returns [true] if report was submitted successfully,
  /// [false] if user closed without submitting or on error, [null] if dismissed without result.
  static Future<bool?> show({
    required String postId,
    required String postType,
    bool isCommentReport = false,
    bool isCommentIsReplyReport = false,
  }) async {
    // Call API after bottom sheet is shown

    return Get.bottomSheet<bool?>(
      ReportBottomSheet(
        postId: postId,
        postType: postType,
        isCommentReport: isCommentReport,
        isCommentIsReplyReport: isCommentIsReplyReport,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ReportController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        switch (controller.currentStep.value) {
          case ReportStep.submitted:
            Get.back(result: true);
            break;
          case ReportStep.selectCategory:
            Get.back(result: false);
            break;
          default:
            controller.goBack();
        }
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        height: Get.height * 0.9,
        decoration: BoxDecoration(
          color: AppColors.whiteFFFFFF,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
        ),
        child: Obx(() => _buildStepContent(controller, context)),
      ),
    );
  }

  Widget _buildStepContent(ReportController controller, BuildContext context) {
    switch (controller.currentStep.value) {
      case ReportStep.selectCategory:
        return _buildSelectCategoryStep(controller);
      case ReportStep.selectSubCategory:
        return _buildSelectSubCategoryStep(controller);
      case ReportStep.addDetails:
        return _buildAddDetailsStep(controller, context);
      case ReportStep.submitted:
        return _buildSubmittedStep(controller);
    }
  }

  Widget _buildSelectCategoryStep(ReportController controller) {
    return Column(
      children: [
        Container(
          height: 5.w,
          width: 55.h,
          decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
        ),
        Gap(20.h),
        _buildHeader('Report', showClose: false, onBack: () => Get.back(result: false)),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Gap(45.h),
                Text(
                  'Why are you reporting this post?',
                  style: TextStyles.semiBold(23.sp, fontColor: AppColors.black2F3039),
                ),
                Gap(6.h),
                Text(
                  "We'll check for all Community Guidelines, so don't worry about making the perfect choice.",
                  style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
                  textAlign: TextAlign.center,
                ),
                Gap(24.h),
                Obx(() {
                  if (controller.isReportCategoriesLoading.value) {
                    return _buildCategoryShimmer();
                  }
                  if (controller.reportsCategories.isEmpty) {
                    return Column(
                      children: [
                        Gap(50.h),
                        Icon(Icons.category_outlined, size: 48.sp, color: AppColors.gray8C9499),
                        Gap(16.h),
                        Text(
                          'No categories available',
                          style: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499),
                        ),
                        Gap(8.h),
                        Text(
                          'Please try again later',
                          style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: controller.reportsCategories
                        .map(
                          (category) => _buildCategoryItem(
                            category,
                            controller.selectedCategory.value?.id == category.id,
                            () => controller.selectCategory(category),
                          ),
                        )
                        .toList(),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectSubCategoryStep(ReportController controller) {
    return Column(
      children: [
        Container(
          height: 5.w,
          width: 55.h,
          decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
        ),
        Gap(15.h),
        _buildHeader('Report', showClose: false, onBack: controller.goBack),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Gap(45.h),
                Text(
                  'Select a specific reason',
                  style: TextStyles.semiBold(22.sp, fontColor: AppColors.black2F3039),
                  textAlign: TextAlign.center,
                ),
                Gap(6.h),
                Text(
                  "Choose the option that best describes your concern.",
                  style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
                  textAlign: TextAlign.center,
                ),
                Gap(24.h),
                if (controller.selectedCategory.value?.subCategories != null)
                  ...controller.selectedCategory.value!.subCategories!.map(
                    (subCategory) => _buildCategoryItem(
                      subCategory,
                      controller.selectedSubCategory.value?.id == subCategory.id,
                      () => controller.selectSubCategory(subCategory),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddDetailsStep(ReportController controller, BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 5.w,
            width: 55.h,
            decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
          ),
          Gap(15.h),
          _buildHeader('Report', showClose: false, onBack: controller.goBack),
          Gap(45.h),
          Text(
            'Add more details',
            style: TextStyles.semiBold(23.sp, fontColor: AppColors.black2F3039),
            textAlign: TextAlign.center,
          ),
          Gap(12.h),
          Obx(
            () => Text(
              controller.reportDetails.value.isNotEmpty
                  ? "Providing more context can help our team review your report faster and more accurately."
                  : "Providing more context can help our team review this report faster and more accurately.",
              style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
              textAlign: TextAlign.center,
            ),
          ),
          Gap(28.h),
          Container(
            decoration: BoxDecoration(
              // color: AppColors.greyF5F5F5,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.gray8C9499.withValues(alpha: 0.40)),
            ),
            child: Obx(
              () => TextField(
                maxLines: 5,
                maxLength: 280,
                controller: controller.detailsController,
                decoration: InputDecoration(
                  hintText: 'Explain the issue in a few words.',
                  hintStyle: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16.w),

                  counter: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '${controller.reportDetails.value.length} / ${controller.maxCharacters}',
                      style: TextStyles.medium(14.sp, fontColor: AppColors.gray8C9499),
                    ),
                  ),
                ),
                style: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
              ),
            ),
          ),
          Gap(32.h),
          Obx(
            () => SizedBox(
              width: double.infinity,
              child: CommonButton(
                color: controller.detailsController.text.isEmpty ? AppColors.lightPrimaryColor : null,
                onPressed: controller.canSubmit
                    ? () {
                        isCommentReport
                            ? isCommentIsReplyReport
                                  ? controller.reportToReplyComment(context, commentId: postId)
                                  : controller.reportComment(context, commentId: postId)
                            : controller.submitReport(context, contentId: postId, contentType: postType);
                      }
                    : null,
                child: controller.isReportSubmitting.value
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [CommonLoader(size: 25, color: AppColors.white)],
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                        alignment: Alignment.center,
                        child: Text(
                          "Submit Report",
                          style: TextStyles.medium(16.0, fontColor: AppColors.whiteFFFFFF).copyWith(letterSpacing: 0.5),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedStep(ReportController controller) {
    return Column(
      children: [
        Container(
          height: 5.w,
          width: 55.h,
          decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
        ),
        Gap(15.h),
        _buildHeader('Report', showClose: true, onBack: () => Get.back(result: true)),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    shape: BoxShape.circle,

                    gradient: LinearGradient(
                      colors: const [
                        AppColors.primaryColor, // #DA7000
                        AppColors.primaryDark, // #984005
                      ],
                      stops: const [-0.0864, 0.798], // -8.64% and 79.8%
                      transform: GradientRotation(
                        (320.33 - 90) * math.pi / 180, // Convert 320.33deg to radians (≈ 4.016 radians)
                      ),
                    ),
                  ),
                  child: Icon(Icons.check, color: AppColors.whiteFFFFFF, size: 40.sp),
                ),
                Gap(24.h),
                Text('Report submitted', style: TextStyles.semiBold(23.sp, fontColor: AppColors.black2F3039)),
                Gap(12.h),
                Text(
                  controller.reportSubmitMessage.value,
                  textAlign: TextAlign.center,
                  style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String title, {required bool showClose, required VoidCallback onBack}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!showClose)
          InkWell(onTap: onBack, child: Image.asset(Assets.icons.icArrowBack.path, scale: 3.5))
        else
          InkWell(
            // onTap: onBack,
            child: Icon(Icons.close, color: AppColors.transparentColor, size: 24.sp),
          ),

        Text(title, style: TextStyles.semiBold(20.sp, fontColor: AppColors.black2F3039)),

        InkWell(
          onTap: onBack,
          child: Icon(Icons.close, color: showClose ? AppColors.black2F3039 : AppColors.transparentColor),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(ReportsCategory category, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor.withValues(alpha: 0.1) : AppColors.grayEDF1F4,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: AppColors.primaryColor) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                category.name ?? '',
                style: TextStyles.medium(16.sp, fontColor: isSelected ? AppColors.primaryColor : AppColors.black000000),
              ),
            ),
            Image.asset(Assets.icons.icArrowNext.path, scale: 3.5),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryShimmer() {
    return Column(
      children: List.generate(
        5,
        (index) => Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
          height: 60.h,
          decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
