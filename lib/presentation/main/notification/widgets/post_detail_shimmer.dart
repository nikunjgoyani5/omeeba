import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';

class PostDetailShimmer extends StatelessWidget {
  const PostDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                _box(40.r, 40.r, shape: BoxShape.circle),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(120.w, 14.h),
                      SizedBox(height: 6.h),
                      _box(80.w, 12.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Caption line
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _box(double.infinity, 14.h),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _box(200.w, 14.h),
          ),
          SizedBox(height: 12.h),
          // Image block
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.width,
            color: AppColors.grayEDF1F4,
            child: Center(
              child: _box(80.w, 80.w, shape: BoxShape.circle),
            ),
          ),
          SizedBox(height: 12.h),
          // Action bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _box(80.w, 24.h),
                SizedBox(width: 20.w),
                _box(80.w, 24.h),
                SizedBox(width: 20.w),
                _box(40.w, 24.h),
              ],
            ),
          ),
        ],
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
