
import 'dart:ui' as ui show Gradient;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';


class StyleRes {
  static Gradient themeGradient = const LinearGradient(
 colors:    [ AppColors.primaryDark,  AppColors.primaryColor],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static Gradient textDarkGreyGradient({double opacity = 1}) => LinearGradient(
        colors: [
          Colors.grey.withValues(alpha: opacity),
          Colors.grey.withValues(alpha: opacity)
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  static Gradient disabledGreyGradient({double opacity = 1}) => LinearGradient(
        colors: [
          Colors.grey.withValues(alpha: opacity),
          Colors.grey.withValues(alpha: opacity)
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  static Gradient textLightGreyGradient({double opacity = 1}) => LinearGradient(
        colors: [
          Colors.grey.withValues(alpha: opacity),
          Colors.grey.withValues(alpha: opacity)
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  static Shader wavesGradient = ui.Gradient.linear(
    const Offset(70, 50),
    Offset(Get.width / 2, 0),
    [ Colors.blue,  Colors.grey],
  );
}
