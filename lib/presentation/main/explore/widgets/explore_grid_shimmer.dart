import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

/// Shimmer placeholder for explore tab grid (3-column masonry).
class ExploreGridShimmer extends StatelessWidget {
  const ExploreGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(4.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 12,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4.w,
          crossAxisSpacing: 4.w,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          return _shimmerBox();
        },
      ),
    );
  }

  Widget _shimmerBox() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grayEDF1F4,
        borderRadius: BorderRadius.circular(1.r),
      ),
    );
  }
}
