import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

/// Shimmer placeholder for trending and polls tab (list view).
class ExploreListShimmer extends StatelessWidget {
  const ExploreListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        color: AppColors.whiteFFFFFF,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (_) => _buildShimmerItem()),
        ),
      ),
    );
  }

  Widget _buildShimmerItem() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _shimmerBox(35.w, 35.h, shape: BoxShape.circle),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerBox(120.w, 14.h),
                      SizedBox(height: 6.h),
                      _shimmerBox(60.w, 12.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _shimmerBox(double.infinity, 14.h),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _shimmerBox(double.infinity, 12.h),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _shimmerBox(80.w, 20.h),
                SizedBox(width: 20.w),
                _shimmerBox(60.w, 20.h),
                SizedBox(width: 20.w),
                _shimmerBox(24.w, 24.h),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Container(height: 12.h, width: double.infinity, color: AppColors.grayEDF1F4),
        ],
      ),
    );
  }

  Widget _shimmerBox(double width, double height, {BoxShape shape = BoxShape.rectangle}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(6.r) : null,
        color: AppColors.grayEDF1F4,
      ),
    );
  }
}
