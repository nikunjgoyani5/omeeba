import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/widgets/common_button.dart';
import 'package:intl/intl.dart';
import 'package:omeeba_new/presentation/main/settings/widgets/web_view_screen.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/app_constant.dart';
import '../../../../core/widgets/common_profile_image.dart';
import '../../../../gen/assets.gen.dart';
import '../../myprofile/controller/my_profile_controller.dart';
import '../controller/settings_controller.dart';
import 'choose_plan_bottom_sheet.dart';

class VerifiedBadgeBottomSheet extends StatefulWidget {
  const VerifiedBadgeBottomSheet({super.key});

  @override
  State<VerifiedBadgeBottomSheet> createState() => _VerifiedBadgeBottomSheetState();
}

class _VerifiedBadgeBottomSheetState extends State<VerifiedBadgeBottomSheet> {
  late final SettingsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<SettingsController>();
    controller.loadVerifiedBadgePlansIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.w),
            child: Container(
              height: 22.w,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: AppColors.grayEDF1F4,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.015),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.885,
              decoration: BoxDecoration(
                color: AppColors.whiteFFFFFF,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Fixed header with drag handle
                    SizedBox(height: 10.h),
                    Container(
                      height: 5.h,
                      width: 60.w,
                      decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 12.h),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: Icon(Icons.keyboard_arrow_left, size: 35.sp, color: AppColors.black2F3039),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Text('Verified Badge', style: TextStyles.bold(22.sp, fontColor: AppColors.black2F3039)),
                        ],
                      ),
                    ),
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Profile Picture
                            Container(
                              width: 120.w,
                              height: 120.h,
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.grayEDF1F4, width: 2),
                                shape: BoxShape.circle,
                              ),
                              child: CommonProfileImage(imageUrl: PrefService.getString(PrefKeys.userProfile)),
                            ),


                            SizedBox(height: 8.h),

                            // Name with verified badge
                            Flexible(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 15.h),
                                child: SizedBox(
                                  width: 230.w,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          Get
                                              .find<MyProfileController>()
                                              .profile
                                              .value
                                              ?.name ?? PrefService.getString(
                                              PrefKeys.name),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyles.bold(24.sp,
                                              fontColor: AppColors.black2F3039),
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      if (Get
                                          .find<MyProfileController>()
                                          .profile
                                          .value
                                          ?.isVerifiedBadge == true)...[
                                        Assets.icons.icVerifyBadge.svg(
                                            width: 30.w, height: 30.h),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 25.h),

                            // Benefits List (old UI kept as requested)
                            // Padding(
                            //   padding: EdgeInsets.symmetric(horizontal: 24.w),
                            //   child: Column(
                            //     children: [
                            //       _buildBenefitItem(
                            //         icon: Assets.icons.icVerifyBadge.svg(width: 30.w, height: 30.h),
                            //         title: 'Get Verified badge',
                            //         description: 'Stand out with exclusive benefits.',
                            //       ),
                            //       SizedBox(height: 18.h),
                            //       _buildBenefitItem(
                            //         icon: Assets.icons.icPrioritySupport.svg(width: 30.w, height: 30.h),
                            //         title: 'Priority Support',
                            //         description: 'Get faster responses and dedicated support from our team.',
                            //       ),
                            //       SizedBox(height: 18.h),
                            //       _buildBenefitItem(
                            //         icon: Assets.icons.icAddFree.svg(width: 30.w, height: 30.h),
                            //         title: 'Ad-Free Experience',
                            //         description: 'Enjoy uninterrupted browsing without any advertisements.',
                            //       ),
                            //     ],
                            //   ),
                            // ),
                            _buildNewBenefitsSection(),
                            SizedBox(height: 30.h),
                            Divider(color: AppColors.grayEDF1F4),
                            // Pricing
                            SizedBox(height: 12.h),
                            Obx(() {
                              if (controller.verifiedBadgePlansLoading.value) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16.w,
                                      height: 16.w,
                                      child: const CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      'Loading plans...',
                                      style: TextStyles.medium(14.sp, fontColor: AppColors.g8C9499ray),
                                    ),
                                  ],
                                );
                              }

                              final error = controller.verifiedBadgePlansError.value;
                              if (error != null && error.isNotEmpty) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                                  child: Text(
                                    error,
                                    style: TextStyles.medium(13.sp, fontColor: AppColors.redFF5353),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }

                              final product = controller.selectedVerifiedBadgePlan;
                              if (product == null) {
                                return Text(
                                  'No plans found.',
                                  style: TextStyles.medium(14.sp, fontColor: AppColors.g8C9499ray,
                                )
                                );
                              }

                              final title = _planTitle(product.id);
                              final perDay = _perDayText(product.rawPrice, product.currencyCode, product.id);
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${product.price} ${title.toLowerCase()} / ',
                                    style: TextStyles.medium(14.sp, fontColor: AppColors.black000000),
                                  ),
                                  Text(perDay, style: TextStyles.medium(14.sp, fontColor: AppColors.g8C9499ray)),
                                ],
                              );
                            }),
                            SizedBox(height: 8.h),
                            // Buttons
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: Column(
                                children: [
                                  Obx(() {
                                    final disabled =
                                        controller.verifiedBadgePlansLoading.value ||
                                        controller.verifiedBadgePurchaseInProgress.value ||
                                        controller.selectedVerifiedBadgePlan == null;
                                    return Opacity(
                                      opacity: disabled ? 0.6 : 1,
                                      child: IgnorePointer(
                                        ignoring: disabled,
                                        child: CommonButtonWidget(
                                          child: Text(
                                            controller.verifiedBadgePurchaseInProgress.value
                                                ? "Processing..."
                                                : "Subscribe",
                                            style: TextStyles.medium(18.sp, fontColor: AppColors.white),
                                          ),
                                          onPressed: () async {
                                            await controller.purchaseSelectedVerifiedBadgePlan(context);
                                          },
                                        ),
                                      ),
                                    );
                                  }),
                                  SizedBox(height: 12.h),
                                  // View Plan Button (Gray)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        // Show Choose Your Plan bottom sheet on top without closing current one
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => const ChoosePlanBottomSheet(),
                                        ).then((_) => controller.clearVerifiedBadgePurchaseState());
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.grayEDF1F4,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'View Plan',
                                        style: TextStyles.medium(18.sp, fontColor: AppColors.black2F3039),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 25.h),

                            // Bottom Links
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildBottomLink(
                                    'Privacy Policy',
                                    () => Get.to(
                                      () => CommonWebViewScreen(
                                        url: '$socketUrl/privacy.html',
                                        name: 'Privacy Policy',
                                      ),
                                    ),
                                  ),
                                  _buildBottomLink(
                                    'Terms & Conditions',
                                    () => Get.to(
                                      () => CommonWebViewScreen(
                                        url: '$socketUrl/terms.html',
                                        name: 'Terms & Conditions',
                                      ),
                                    ),
                                  ),
                                  _buildBottomLink('Restore Purchase', () async {
                                    await controller.restoreVerifiedBadgePurchases();
                                  }),
                                ],
                              ),
                            ),
                            Obx(() {
                              final err = controller.verifiedBadgePurchaseError.value;
                              if (err == null || err.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: EdgeInsets.only(top: 10.h, left: 24.w, right: 24.w),
                                child: Text(
                                  err,
                                  style: TextStyles.medium(13.sp, fontColor: AppColors.redFF5353),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }),
                            SizedBox(height: 5.h),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({required Widget icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyles.semiBold(16.sp, fontColor: AppColors.black000000)),
              SizedBox(height: 4.h),
              Text(description, style: TextStyles.regular(12.sp, fontColor: AppColors.g8C9499ray)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewBenefitsSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get Verified. Be Recognized.',
            style: TextStyles.semiBold(21.sp, fontColor: AppColors.black2F3039, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 2.h),
          Text(
            "Show your audience you're serious, authentic, and here to stand out.",
            style: TextStyles.regular(13.sp, fontColor: AppColors.g8C9499ray, fontWeight: FontWeight.w400),
          ),
          SizedBox(height: 16.h),
          _buildChecklistItem('Verified badge on your profile'),
          SizedBox(height: 10.h),
          _buildChecklistItem('Build trust with your audience'),
          SizedBox(height: 10.h),
          _buildChecklistItem('Stand out across Omeeba'),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 2.h),
          width: 16.w,
          height: 16.w,
          child: Assets.icons.iccheck.svg(width: 16.w, height: 16.h),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: TextStyles.medium(15.sp, fontColor: AppColors.black2F3039, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomLink(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(text, style: TextStyles.semiBold(10.sp, fontColor: AppColors.black000000)),
    );
  }

  String _planTitle(String productId) {
    // Check for weekly (both iOS and Android)
    if (productId == SettingsController.verifiedBadgeWeeklyIdIOS ||
        productId == SettingsController.verifiedBadgeWeeklyIdAndroid) {
      return 'Weekly';
    }
    // Check for monthly (both iOS and Android)
    if (productId == SettingsController.verifiedBadgeMonthlyIdIOS ||
        productId == SettingsController.verifiedBadgeMonthlyIdAndroid) {
      return 'Monthly';
    }
    // Check for yearly (both iOS and Android)
    if (productId == SettingsController.verifiedBadgeYearlyIdIOS ||
        productId == SettingsController.verifiedBadgeYearlyIdAndroid) {
      return 'Yearly';
    }
    return 'Plan';
  }

  String _perDayText(double rawPrice, String currencyCode, String productId) {
    int days;
    // Check for weekly (both iOS and Android)
    if (productId == SettingsController.verifiedBadgeWeeklyIdIOS ||
        productId == SettingsController.verifiedBadgeWeeklyIdAndroid) {
      days = 7;
    }
    // Check for monthly (both iOS and Android)
    else if (productId == SettingsController.verifiedBadgeMonthlyIdIOS ||
        productId == SettingsController.verifiedBadgeMonthlyIdAndroid) {
      days = 30;
    }
    // Check for yearly (both iOS and Android)
    else if (productId == SettingsController.verifiedBadgeYearlyIdIOS ||
        productId == SettingsController.verifiedBadgeYearlyIdAndroid) {
      days = 365;
    } else {
      days = 30;
    }
    final formatter = NumberFormat.simpleCurrency(name: currencyCode);
    final perDay = rawPrice / days;
    return 'Only ${formatter.format(perDay)} Day';
  }
}
