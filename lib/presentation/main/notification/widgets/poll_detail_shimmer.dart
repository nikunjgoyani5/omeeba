import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';

/// Shimmer matching PollCard: profile row, question, option bars, action row.
class PollDetailShimmer extends StatelessWidget {
  const PollDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        color: AppColors.whiteFFFFFF,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _box(35.w, 35.h, shape: BoxShape.circle),
                  SizedBox(width: 10.w),
                  _box(90.w, 14.h),
                  SizedBox(width: 5.w),
                  _box(6.w, 6.h, shape: BoxShape.circle),
                  SizedBox(width: 5.w),
                  _box(36.w, 14.h),
                  const Spacer(),
                  _box(18.w, 18.h),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            // Poll question
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _box(double.infinity, 16.h),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _box(220.w, 14.h),
            ),
            SizedBox(height: 16.h),
            // Poll options (bars)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  _optionBar(),
                  SizedBox(height: 12.h),
                  _optionBar(),
                  SizedBox(height: 12.h),
                  _optionBar(),
                  SizedBox(height: 12.h),
                  _optionBar(),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            // Action row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _box(20.w, 20.h),
                  SizedBox(width: 4.w),
                  _box(24.w, 14.h),
                  SizedBox(width: 20.w),
                  _box(20.w, 20.h),
                  SizedBox(width: 4.w),
                  _box(24.w, 14.h),
                  SizedBox(width: 20.w),
                  _box(20.w, 20.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionBar() {
    return Container(
      width: double.infinity,
      height: 44.h,
      decoration: BoxDecoration(
        color: AppColors.grayEDF1F4,
        borderRadius: BorderRadius.circular(8.r),
      ),
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
