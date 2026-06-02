import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';

/// Shimmer matching ZealDetailScreen: full video area, right actions, bottom-left profile + caption.
class ZealDetailShimmer extends StatelessWidget {
  const ZealDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Video area (full screen)
        Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.grayEDF1F4,
          child: Center(
            child: _box(64.w, 64.w, shape: BoxShape.circle),
          ),
        ),
        // Right side: action buttons column
        Positioned(
          right: 12.w,
          bottom: 80.h,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _box(28.w, 28.h),
              SizedBox(height: 20.h),
              _box(28.w, 28.h),
              SizedBox(height: 20.h),
              _box(28.w, 28.h),
              SizedBox(height: 8.h),
              _box(24.w, 14.h),
              SizedBox(height: 20.h),
              _box(24.w, 14.h),
              SizedBox(height: 20.h),
              _box(24.w, 14.h),
            ],
          ),
        ),
        // Bottom left: profile + caption
        Positioned(
          left: 12.w,
          bottom: 20.h,
          right: 80.w,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _box(35.w, 35.w, shape: BoxShape.circle),
                  SizedBox(width: 12.w),
                  _box(100.w, 16.h),
                ],
              ),
              SizedBox(height: 8.h),
              _box(double.infinity, 14.h),
              SizedBox(height: 6.h),
              _box(180.w, 14.h),
            ],
          ),
        ),
      ],
    );
  }

  Widget _box(double w, double h, {BoxShape shape = BoxShape.rectangle}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.grayEDF1F4,
        shape: shape,
        borderRadius:
            shape == BoxShape.rectangle ? BorderRadius.circular(6.r) : null,
      ),
    );
  }
}
