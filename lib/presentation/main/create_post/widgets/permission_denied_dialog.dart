import 'dart:math' as math;

import 'package:permission_handler/permission_handler.dart';

import '../../../../core/utils/exports.dart';

class PermissionDeniedDialog extends StatelessWidget {
  final String deniedPermission;
  final Function? onBackPressed;

  const PermissionDeniedDialog({
    super.key,
    required this.deniedPermission,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.black141414.withValues(alpha: 2000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.grayA4A4A4.withValues(alpha: 0.2),
              ),
              child: Icon(
                Icons.lock_outline,
                color: AppColors.redFF5353,
                size: 32.sp,
              ),
            ),
            SizedBox(height: 16.h),

            // Title
            Text(
              'Permission Required',
              style: TextStyles.semiBold(
                18.sp,
                fontColor: AppColors.whiteFFFFFF,
              ),
            ),
            SizedBox(height: 12.h),

            // Message
            Text(
              'This app needs access to your Camera to capture and upload content.',
              textAlign: TextAlign.center,
              style: TextStyles.regular(14.sp, fontColor: AppColors.grayA4A4A4),
            ),
            SizedBox(height: 20.h),

            // Single Permission Row
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.grayA4A4A4.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.close_rounded,
                    color: AppColors.redFF5353,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    deniedPermission,
                    style: TextStyles.regular(
                      13.sp,
                      fontColor: AppColors.whiteFFFFFF,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: CommonButtonWidget(
                    height: 44.h,
                    color: AppColors.gray8C9499,
                    borderRadius: 40,
                    onPressed: () {
                      Get.back();
                    },
                    child: Center(
                      child: Text(
                        'Go Back',
                        style: TextStyles.medium(
                          14.sp,
                          fontColor: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Gap(10.w),

                // Yes / Logout button - now using gradient style
                Expanded(
                  child: Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: const [
                          AppColors.greyE5E4DC,
                          AppColors.greyE5E4DC,
                        ],
                        stops: const [-0.0864, 0.798],
                        transform: GradientRotation(
                          (320.33 - 90) * math.pi / 180,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await openAppSettings();
                          onBackPressed?.call();
                          Get.back();
                        },
                        borderRadius: BorderRadius.circular(40),
                        child: Center(
                          child: Text(
                            'Grant Permission',
                            style: TextStyles.medium(
                              13.sp,
                              fontColor: AppColors.black000000,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
