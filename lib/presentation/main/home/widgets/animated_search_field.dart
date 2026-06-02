import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../gen/assets.gen.dart';

class AnimatedSearchField extends StatelessWidget {
  final bool isScrolled;
  final double scrollProgress;

  const AnimatedSearchField({super.key, required this.isScrolled, this.scrollProgress = 0.0});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final searchFieldHeight = 60.h;
    final expandedWidth = screenWidth - 32.w;
    final collapsedWidth = 240.w;
    final currentWidth = expandedWidth - (expandedWidth - collapsedWidth) * scrollProgress;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: currentWidth,
      height: searchFieldHeight,
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        borderRadius: BorderRadius.circular(500.r),
        boxShadow: [
          isScrolled
              ? BoxShadow(
                  color: AppColors.black000000.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 8),
                )
              : BoxShadow(
                  color: AppColors.whiteE7EEF3.withValues(alpha: 0.5),
                  blurRadius: 3,
                  offset: const Offset(0, 8),
                ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: 20.w),
          Assets.icons.imgAppLogo.image(width: 30.w, height: 30.h),
          SizedBox(width: 12.w),
          Text('Search ', style: TextStyles.medium(18.sp, fontColor: AppColors.grayC4C4C4)),
          ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF9A3F05), Color(0xFFFFFFFF)],
              ).createShader(bounds);
            },
            child: Text(
              'Trending',
              style: TextStyles.medium(16.sp).copyWith(
                color: Colors.white, // required
              ),
            ),
          ),
        ],
      ),
    );
  }
}
