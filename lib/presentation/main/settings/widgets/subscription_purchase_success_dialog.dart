import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/presentation/main/settings/widgets/verified_badge_success.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/text_styles.dart';

class SubscriptionPurchaseSuccessDialog {
  static void show(BuildContext context) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 15.w),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            color: AppColors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 70.h,
                width: 70.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.primaryColor,
                  size: 40.sp,
                ),
              ),

              SizedBox(height: 16.h),

              Text(
                "Subscription Activated ",
                textAlign: TextAlign.center,
                style: TextStyles.medium(21.sp),
              ),

              SizedBox(height: 12.h),

              Text(
                "Your subscription has been successfully activated. You are now a premium member and can enjoy all exclusive features.",
                textAlign: TextAlign.center,
                style: TextStyles.regular(16.sp),
              ),

              SizedBox(height: 24.h),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  Get.back();
                  Get.to(() => const VerifiedBadgeSuccess());

                },
                child: Container(
                  height: 40.h,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: const [
                        AppColors.primaryColor,
                        AppColors.primaryDark,
                      ],
                      stops: const [-0.0864, 0.798],
                      transform: GradientRotation(
                        (320.33 - 90) * math.pi / 180,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Center(
                    child: Text(
                      'OK',
                      style: TextStyles.medium(
                        16.sp,
                        fontColor: AppColors.whiteFFFFFF,
                      ),
                    ),
                  ),
                ),
              ),

              // CommonButtonWidget(
              //   height: 44.h,
              //   color: AppColors.gray8C9499,
              //   borderRadius: 40,
              //   onPressed: () {
              //     Get.back();
              //   },
              //   child: Center(
              //     child: Text('OK', style: TextStyles.medium(16.sp, fontColor: AppColors.white)),
              //   ),
              // ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
