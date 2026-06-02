import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';

/// Shimmer / skeleton placeholder for chat list items.
class ChatShimmer extends StatelessWidget {
  const ChatShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Picture Shimmer
          _shimmerBox(56.w, 56.w, shape: BoxShape.circle),
          SizedBox(width: 12.w),
          
          // Chat Info Shimmer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username Shimmer
                _shimmerBox(120.w, 16.h),
                SizedBox(height: 8.h),
                
                // Last Message Shimmer
                _shimmerBox(200.w, 14.h),
              ],
            ),
          ),
          
          // Time Shimmer
          _shimmerBox(60.w, 14.h),
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

/// Shimmer for multiple chat items
class ChatListShimmer extends StatelessWidget {
  const ChatListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6, // Show 6 shimmer items
      separatorBuilder: (context, index) => SizedBox(height: 20.h),
      itemBuilder: (context, index) {
        return const ChatShimmer();
      },
    );
  }
}
