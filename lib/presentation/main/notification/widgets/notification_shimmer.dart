import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';

class NotificationShimmer extends StatelessWidget {
  const NotificationShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: 6,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.5, color: AppColors.grayEDF1F4),
      itemBuilder: (_, __) => _buildItem(),
    );
  }

  Widget _buildItem() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + icon badge
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 4),
                child: _box(48.w, 48.w, shape: BoxShape.circle),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: _box(22.w, 22.w, shape: BoxShape.circle),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(200.w, 14.h),
                SizedBox(height: 6.h),
                _box(140.w, 13.h),
                SizedBox(height: 6.h),
                _box(60.w, 11.h),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          _box(50.w, 50.w),
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
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(6.r) : null,
      ),
    );
  }
}
