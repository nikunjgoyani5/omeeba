import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/text_styles.dart';

class PostItem extends StatelessWidget {
  final int index;

  const PostItem({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      color: AppColors.whiteFFFFFF,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: AppColors.grayC4C4C4,
                  child: Icon(Icons.person, color: AppColors.gray8C9499, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                // Username & Timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@Username ${index + 1}',
                        style: TextStyles.semiBold(14.sp, fontColor: AppColors.black2F3039),
                      ),
                      Text('${index + 1}h', style: TextStyles.regular(12.sp, fontColor: AppColors.gray8C9499)),
                    ],
                  ),
                ),
                // Options Icon
                IconButton(
                  icon: Icon(Icons.more_vert, color: AppColors.gray8C9499, size: 20.sp),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          // Post Content Text
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              'This is a sample post content. It can contain multiple lines of text and will wrap accordingly. More...',
              style: TextStyles.regular(14.sp, fontColor: AppColors.black2F3039),
            ),
          ),
          SizedBox(height: 12.h),
          // Post Image
          Container(
            width: double.infinity,
            height: 300.h,
            color: AppColors.grayEDF1F4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Network Image with placeholder
                Image.network(
                  'https://picsum.photos/seed/post$index/400/300',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: AppColors.grayEDF1F4,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.grayEDF1F4,
                      child: Center(
                        child: Icon(Icons.image_not_supported, size: 60.sp, color: AppColors.grayC4C4C4),
                      ),
                    );
                  },
                ),
                // Image Count Indicator
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.black000000.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text('1/9+', style: TextStyles.regular(12.sp, fontColor: AppColors.whiteFFFFFF)),
                  ),
                ),
              ],
            ),
          ),
          // Image Carousel Dots
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (dotIndex) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: 6.w,
                  height: 6.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotIndex == 0 ? AppColors.primaryColor : AppColors.grayC4C4C4,
                  ),
                ),
              ),
            ),
          ),
          // Interaction Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                // Like
                Row(
                  children: [
                    Icon(Icons.favorite_outline, color: AppColors.gray8C9499, size: 20.sp),
                    SizedBox(width: 4.w),
                    Text('50', style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499)),
                  ],
                ),
                SizedBox(width: 20.w),
                // Comment
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: AppColors.gray8C9499, size: 20.sp),
                    SizedBox(width: 4.w),
                    Text('12', style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499)),
                  ],
                ),
                SizedBox(width: 20.w),
                // Share
                Icon(Icons.share_outlined, color: AppColors.gray8C9499, size: 20.sp),
                const Spacer(),
                // Bookmark
                Icon(Icons.bookmark_border, color: AppColors.gray8C9499, size: 20.sp),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
