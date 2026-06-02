import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';

/// Shimmer-like skeleton that roughly matches MyProfileView layout:
/// cover, avatar, stats, filter tabs and grid/list content.
class MyProfileShimmer extends StatelessWidget {
  const MyProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      body: SafeArea(
        child: Column(
          children: [
            // Header (cover + avatar + basic info)
            _buildHeader(),
            // Filter bar (same height as _ProfileFilterBar)
            _buildFilterBar(),
            // Bottom content grid / list placeholder
            Expanded(child: _buildGridPlaceholder()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 300.h,
      child: Stack(
        children: [
          // Cover placeholder
          Container(height: 140.h, width: double.infinity, color: AppColors.grayEDF1F4),
          // Avatar
          Positioned(
            left: 12.w,
            top: 80.h,
            child: Container(
              width: 120.w,
              height: 120.w,
              padding: EdgeInsets.all(5.sp),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.grayEDF1F4, width: 2.w),
                color: AppColors.white,
              ),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.grayEDF1F4),
              ),
            ),
          ),
          // Name + stats + bio placeholders
          Positioned(
            left: 16.w,
            right: 16.w,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),
                  Container(width: 160.w, height: 20.h, color: AppColors.grayEDF1F4),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Container(width: 80.w, height: 14.h, color: AppColors.grayEDF1F4),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: _dot(),
                      ),
                      Container(width: 100.w, height: 14.h, color: AppColors.grayEDF1F4),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: _dot(),
                      ),
                      Container(width: 100.w, height: 14.h, color: AppColors.grayEDF1F4),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Container(width: 260.w, height: 20.h, color: AppColors.grayEDF1F4),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 48.h,
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        border: Border(bottom: BorderSide(color: AppColors.whiteEAEAEA, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(5, (index) {
          final isSelected = index == 0;
          return Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isSelected ? AppColors.black000000 : Colors.transparent, width: 2),
                ),
              ),
              child: Icon(
                Icons.square_rounded,
                size: 18.sp,
                color: isSelected ? AppColors.black000000 : AppColors.greyC4CACE,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGridPlaceholder() {
    // Mimic a 3-column grid like the posts/zeals tabs.
    return Container(
      color: AppColors.whiteFFFFFF,
      padding: EdgeInsets.all(1.w),
      child: GridView.builder(
        padding: EdgeInsets.all(1.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2.w,
          mainAxisSpacing: 2.w,
          childAspectRatio: 1,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          return Container(color: AppColors.grayEDF1F4);
        },
      ),
    );
  }

  Widget _dot() {
    return Container(
      width: 6.w,
      height: 6.w,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.grayC4C4C4),
    );
  }
}
