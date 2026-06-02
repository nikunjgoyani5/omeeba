import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';

/// Shimmer / skeleton placeholder when feed is loading and cache is empty.
class HomeFeedShimmer extends StatelessWidget {
  const HomeFeedShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Light/dark neutral greys with enough contrast to be noticeable.
    final baseColor = isDark ? const Color(0xFF2B2F35) : const Color(0xFFD6DCE3);
    final highlightColor = isDark ? const Color(0xFF434A53) : const Color(0xFFF5F7FA);

    final surfaceColor = isDark ? const Color(0xFF0F1113) : AppColors.whiteFFFFFF;
    final dividerColor = isDark ? const Color(0xFF20242A) : AppColors.grayEDF1F4;

    // Small extra padding helps match IG feed spacing.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: RepaintBoundary(
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          direction: ShimmerDirection.ltr,
          period: const Duration(milliseconds: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + username + location + 3-dots
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _SkeletonCircle(size: 40),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SkeletonLine(width: 150, height: 12, radius: 8),
                          SizedBox(height: 7.h),
                          const _SkeletonLine(width: 110, height: 10, radius: 8),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    // 3 dots (approx)
                    const _SkeletonLine(width: 22, height: 6, radius: 10),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SkeletonLine(width: double.infinity, height: 10, radius: 8),
                    SizedBox(height: 8.h),
                    const _SkeletonLine(width: 240, height: 10, radius: 8),
                  ],
                ),
              ),

              // Media: large image/video block (IG-like proportions)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 0),
                child: AspectRatio(
                  aspectRatio: 1.2, // keep square to match typical IG
                  child: const _SkeletonBox(radius: 0),
                ),
              ),

              // Actions: like/comment/share + save
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Row(
                  children: [
                    const _SkeletonCircle(size: 22),
                    SizedBox(width: 14.w),
                    const _SkeletonCircle(size: 22),
                    SizedBox(width: 14.w),
                    const _SkeletonCircle(size: 22),
                    const Spacer(),
                    const _SkeletonCircle(size: 22),
                  ],
                ),
              ),

              // Caption lines

            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable skeleton primitives (kept lightweight for list performance).
class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width = double.infinity, required this.radius, this.height});

  final double width;
  final double radius;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.whiteEAEAEA, // overridden by Shimmer
        borderRadius: BorderRadius.circular(radius.r),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height, required this.radius});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _SkeletonBox(width: width, height: height, radius: radius);
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.r,
      height: size.r,
      decoration: const BoxDecoration(
        color: AppColors.whiteEAEAEA, // overridden by Shimmer
        shape: BoxShape.circle,
      ),
    );
  }
}
