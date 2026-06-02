import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

class CommonButton extends StatelessWidget {
  final String? text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? color;
  final Widget? child;

  const CommonButton({
    super.key,
    this.text,
    this.onPressed,
    this.width,
    this.height,
    this.textStyle,
    this.padding,
    this.borderRadius,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? 12.sp;
    return Container(
      width: width,
      height: height ?? 50.0,
      decoration: BoxDecoration(
        gradient: color == AppColors.lightPrimaryColor
            ? LinearGradient(
                colors: [Color(0xffF1D2B3), Color(0xffE0C6B4)],
                stops: const [-0.0864, 0.798],
                transform: GradientRotation((320.33 - 90) * math.pi / 180),
              )
            : LinearGradient(
                colors: const [
                  AppColors.primaryColor, // #DA7000
                  AppColors.primaryDark, // #984005
                ],
                stops: const [-0.0864, 0.798], // -8.64% and 79.8%
                transform: GradientRotation(
                  (320.33 - 90) * math.pi / 180, // Convert 320.33deg to radians (≈ 4.016 radians)
                ),
              ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child:
              child ??
              Container(
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                alignment: Alignment.center,
                child: Text(
                  text ?? "OK",
                  style:
                      textStyle ??
                      TextStyles.medium(16.0, fontColor: AppColors.whiteFFFFFF).copyWith(letterSpacing: 0.5),
                ),
              ),
        ),
      ),
    );
  }
}

class CommonButtonWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? borderColor;
  final EdgeInsets? padding; // 👈 dynamic & nullable

  const CommonButtonWidget({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
    this.textColor,
    this.width,
    this.height,
    this.borderRadius = 10,
    this.borderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius;
    return Container(
      width: width,
      height: height ?? 50.0,
      decoration: BoxDecoration(
        gradient: color == AppColors.lightPrimaryColor
            ? LinearGradient(
                colors: [Color(0xffF1D2B3), Color(0xffE0C6B4)],
                stops: const [-0.0864, 0.798],
                transform: GradientRotation((320.33 - 90) * math.pi / 180),
              )
            : LinearGradient(
                colors: const [AppColors.primaryColor, AppColors.primaryDark],
                stops: const [-0.0864, 0.798],
                transform: GradientRotation((320.33 - 90) * math.pi / 180),
              ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
