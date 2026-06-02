import 'dart:math' as math;

import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_loader.dart';
import 'package:omeeba_new/presentation/main/other_user_profile/controller/other_user_profile_controller.dart';

/// Bottom sheet with Unfollow option. Matches app UI theme.
class UnfollowBottomSheet extends StatelessWidget {
  const UnfollowBottomSheet({super.key, required this.controller});

  final OtherUserProfileController controller;

  static void show({required OtherUserProfileController controller}) {
    Get.bottomSheet(
      UnfollowBottomSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5.w,
              width: 55.h,
              decoration: BoxDecoration(
                color: AppColors.grayEDF1F4,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            Gap(20.h),
            Text(
              'Unfollow?',
              style: TextStyles.semiBold(20.sp, fontColor: AppColors.black2F3039),
            ),
            Gap(8.h),
            Text(
              "You won't see their posts in your feed. They can still see your posts.",
              textAlign: TextAlign.center,
              style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
            ),
            Gap(24.h),
            Obx(() {
              final loading = controller.followActionLoading.value;
              return SizedBox(
                width: double.infinity,
                child: loading
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: CommonLoader(size: 28, color: AppColors.primaryColor),
                        ),
                      )
                    : InkWell(
                        onTap: () async {
                          await controller.unfollowUser(
                            onSuccess: () => Get.back(),
                            onError: (msg) {
                              AppFunctions().showToast(msg, bgColor: AppColors.red);
                            },
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: AppColors.grayEDF1F4,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: Text(
                              'Unfollow',
                              style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                            ),
                          ),
                        ),
                      ),
              );
            }),
            Gap(12.h),
            InkWell(
              onTap: () => Get.back(),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [AppColors.primaryColor, AppColors.primaryDark],
                    stops: const [-0.0864, 0.798],
                    transform: GradientRotation((320.33 - 90) * math.pi / 180),
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF),
                  ),
                ),
              ),
            ),
            Gap(8.h),
          ],
        ),
      ),
    );
  }
}
