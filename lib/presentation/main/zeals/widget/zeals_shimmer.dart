import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';

/// Full-screen reel-style shimmer. Layout is always visible (grey placeholders on black);
/// shimmer wave is applied only to the placeholder shapes so the reel UI is clear.
class ZealsShimmer extends StatelessWidget {
  const ZealsShimmer({super.key});

  /// Grey for placeholder shapes – clearly visible on black.
  static const Color _placeholderColor = Color(0xFF454545);
  /// Lighter grey for the wave highlight.
  static const Color _waveHighlight = Color(0xFF787878);

  @override
  Widget build(BuildContext context) {

    return SizedBox.expand(
      child: Container(
        color: AppColors.black000000,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1) Black background + bottom gradient (always visible)
            Positioned.fill(
              child: Container(color: AppColors.black000000),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 200.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // 2) Reel layout placeholders WITH shimmer (layout must be visible)
            Positioned.fill(
              child: Shimmer.fromColors(
                baseColor: _placeholderColor,
                highlightColor: _waveHighlight,
                period: const Duration(milliseconds: 1300),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                  // Bottom-left: profile, username, caption (2 lines)
                  Positioned(
                    left: 12.w,
                    bottom: 20.h,
                    right: 80.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            _circle(35.w),
                            SizedBox(width: 12.w),
                            _roundedLine(width: 120.w, height: 16.h),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        _roundedLine(width: double.infinity, height: 14.h),
                        SizedBox(height: 6.h),
                        _roundedLine(width: 200.w, height: 14.h),
                      ],
                    ),
                  ),
                  // Right side: like, comment, share, more
                  Positioned(
                    right: 12.w,
                    bottom: 10.h,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _rightActionItem(),
                        SizedBox(height: 20.h),
                        _rightActionItem(),
                        SizedBox(height: 20.h),
                        _rightActionItem(),
                        SizedBox(height: 10.h),
                        _moreIconPlaceholder(),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _placeholderColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _roundedLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _placeholderColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
    );
  }

  Widget _rightActionItem() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28.sp,
          height: 28.sp,
          decoration: BoxDecoration(
            color: _placeholderColor,
            borderRadius: BorderRadius.circular(6.r),
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          width: 24.w,
          height: 10.h,
          decoration: BoxDecoration(
            color: _placeholderColor,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ],
    );
  }

  Widget _moreIconPlaceholder() {
    return Container(
      width: 28.sp,
      height: 28.sp,
      decoration: BoxDecoration(
        color: _placeholderColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
    );
  }
}
