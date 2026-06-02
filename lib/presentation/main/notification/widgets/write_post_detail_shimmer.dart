import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';

/// Shimmer matching CommonWritePostItem: profile row, title, bullet points, action row.
class WritePostDetailShimmer extends StatelessWidget {
  const WritePostDetailShimmer({super.key});

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
            // Author header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _box(35.w, 35.h, shape: BoxShape.circle),
                  SizedBox(width: 12.w),
                  _box(100.w, 14.h),
                  SizedBox(width: 5.w),
                  _box(6.w, 6.h, shape: BoxShape.circle),
                  SizedBox(width: 5.w),
                  _box(40.w, 14.h),
                  const Spacer(),
                  _box(18.w, 18.h),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            // Title line
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _box(double.infinity, 18.h),
            ),
            SizedBox(height: 12.h),
            // Bullet points
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(6.w, 6.h),
                  SizedBox(width: 8.w),
                  Expanded(child: _box(double.infinity, 14.h)),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(6.w, 6.h),
                  SizedBox(width: 8.w),
                  Expanded(child: _box(200.w, 14.h)),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(6.w, 6.h),
                  SizedBox(width: 8.w),
                  Expanded(child: _box(160.w, 14.h)),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            // Divider / content end
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _box(double.infinity, 1.h),
            ),
            SizedBox(height: 12.h),
            // Action row (like, comment, share)
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
