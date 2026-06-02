import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/gradient_circular_progress.dart';
import 'verified_badge_success.dart';

class ProcessingBottomSheet extends StatefulWidget {
  const ProcessingBottomSheet({super.key});

  @override
  State<ProcessingBottomSheet> createState() => _ProcessingBottomSheetState();
}

class _ProcessingBottomSheetState extends State<ProcessingBottomSheet> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startProgress();
  }

  void _startProgress() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _progress += 1.0;
          if (_progress >= 100.0) {
            _progress = 100.0;
            timer.cancel();
            _onProgressComplete();
          }
        });
      }
    });
  }

  void _onProgressComplete() {
    // Wait a brief moment to show 100% completion
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Close all bottom sheets
        // Pop the current ProcessingBottomSheet
        Navigator.of(context).pop();
        
        // Pop the ChoosePlanBottomSheet if it exists
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        // Pop the VerifiedBadgeBottomSheet if it exists
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        // Navigate to VerifiedBadgeSuccess
        Get.to(() => const VerifiedBadgeSuccess());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(22.sp),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.30,
        decoration: BoxDecoration(color: AppColors.whiteFFFFFF, borderRadius: BorderRadius.circular(45.r)),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circular Progress Indicator
                  Container(
                    height: 5.h,
                    width: 60.w,
                    decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
                  ),
                  Gap(12.h),
                  SizedBox(
                    width: 70.w,
                    height: 70.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.greyC4CACE,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          padding: EdgeInsets.all(10),
                          width: 70.w,
                          height: 70.w,
                          child: GradientCircularProgress(
                            value: _progress / 100,
                            radius: 26.w,
                            strokeWidth: 6.w,
                            backgroundColor: AppColors.white,
                            gradientColors: [
                              AppColors.gray707070.withValues(alpha: 0.15),
                              AppColors.gray707070.withValues(alpha: 0.15),
                              AppColors.gray707070.withValues(alpha: 0.18),
                              AppColors.gray707070.withValues(alpha: 0.2),
                              AppColors.gray707070.withValues(alpha: 0.22),
                              AppColors.gray707070.withValues(alpha: 0.25),
                              AppColors.gray707070.withValues(alpha: 0.3),
                              AppColors.gray707070.withValues(alpha: 0.05),
                              AppColors.gray707070.withValues(alpha: 0.07),
                              AppColors.gray707070.withValues(alpha: 0.1),
                              AppColors.gray707070.withValues(alpha: 0.15),
                            ],
                          ),
                        ),
                        // Percentage text
                        Text('${_progress.toInt()}%', style: TextStyles.semiBold(10.sp, fontColor: AppColors.white)),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  // Processing text
                  Text('Processing...', style: TextStyles.semiBold(22.sp, fontColor: AppColors.black2F3039)),
                  SizedBox(height: 12.h),
                  // Instruction text
                  Text(
                    'Stay on this screen to finish processing',
                    style: TextStyles.regular(18.sp, fontColor: AppColors.black2F3039),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
