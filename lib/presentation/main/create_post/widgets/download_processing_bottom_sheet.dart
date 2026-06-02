import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';
import 'package:omeeba_new/core/widgets/gradient_circular_progress.dart';
import '../../../../gen/assets.gen.dart';

class DownloadProcessingBottomSheet extends StatelessWidget {
  final ValueListenable<double> progress;
  final String title;
  final String subtitle;
  final String? thumbnail;

  const DownloadProcessingBottomSheet({
    super.key,
    required this.progress,
    this.title = 'Processing...',
    this.subtitle = 'Stay on this screen to finish processing',
    this.thumbnail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.24,
          maxHeight: MediaQuery.of(context).size.height * 0.30,
        ),
        decoration: BoxDecoration(
          color: AppColors.whiteFFFFFF,
          borderRadius: BorderRadius.circular(32.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.black000000.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
              child: ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (context, value, child) {
                  final clamped = value.clamp(0, 100);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        height: 5.h,
                        width: 60.w,
                        decoration: BoxDecoration(
                          color: AppColors.grayEDF1F4,
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      Gap(24.h),
                      SizedBox(
                        width: 83.w,
                        height: 83.w,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18.r),
                              child: SizedBox(
                                width: 77.w,
                                height: 77.w,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildThumbnail(),
                                    Container(
                                      color: Colors.black.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(7.w),
                                      child: GradientCircularProgress(
                                        value: clamped / 100,
                                        radius: 31.w,
                                        strokeWidth: 5.2.w,
                                        backgroundColor: AppColors.whiteFFFFFF
                                            .withValues(alpha: 0.28),
                                        gradientColors: [
                                          AppColors.orangeDA7000,
                                          AppColors.primaryColor,
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              '${clamped.toInt()}%',
                              style: TextStyles.semiBold(
                                11.sp,
                                fontColor: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Gap(20.h),
                      Text(
                        title,
                        style: TextStyles.semiBold(
                          20.sp,
                          fontColor: AppColors.black2F3039,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Gap(5.h),
                      Text(
                        subtitle,
                        style: TextStyles.regular(
                          14.sp,
                          fontColor: AppColors.gray707070,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (thumbnail != null) {
      final file = File(thumbnail!);

      if (file.existsSync() && !file.path.endsWith('.mp4')) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    return Container(
      color: AppColors.grayEDF1F4,
      padding: EdgeInsets.all(20.w),
      child: Assets.icons.icPlaceholderZeel.svg(alignment: Alignment.center),
    );
  }
}
