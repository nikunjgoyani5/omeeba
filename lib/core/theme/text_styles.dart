import 'package:flutter/material.dart';
import '../utils/app_constant.dart';
import 'app_colors.dart';

class TextStyles {
  /* -------------------------------------------------------------------------- */
  /*                            EXTRA-BOLD TEXT STYLE                           */
  /* -------------------------------------------------------------------------- */

  static TextStyle extraBold(
    double fontSize, {
    Color? fontColor = AppColors.black2F3039,
    TextOverflow? textOverflow,
    String? fontFamily,
    FontWeight? fontWeight,
    TextDecoration? textDecoration,
    Color? decorationsColor,
  }) {
    return TextStyle(
      color: fontColor,
      fontSize: fontSize,
      fontFamily: fontFamily ?? saansTrial,
      fontWeight: fontWeight ?? FontWeight.w800,
      overflow: textOverflow,
      decoration: textDecoration,
      decorationColor: decorationsColor,
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                               BOLD TEXT STYLE                              */
  /* -------------------------------------------------------------------------- */

  static TextStyle bold(
    double fontSize, {
    Color? fontColor = AppColors.black2F3039,
    TextOverflow? textOverflow,
    String? fontFamily,
    FontWeight? fontWeight,
    TextDecoration? textDecoration,
    Color? decorationsColor,
  }) {
    return TextStyle(
      color: fontColor,
      fontSize: fontSize,
      fontFamily: fontFamily ?? saansTrial,
      fontWeight: fontWeight ?? FontWeight.bold,
      overflow: textOverflow,
      decoration: textDecoration,
      decorationColor: decorationsColor,
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                            SEMI-BOLD TEXT STYLE                            */
  /* -------------------------------------------------------------------------- */

  static TextStyle semiBold(
    double fontSize, {
    Color? fontColor = AppColors.black2F3039,
    TextOverflow? textOverflow,
    String? fontFamily,
    FontWeight? fontWeight,
    TextDecoration? textDecoration,
    Color? decorationsColor,
  }) {
    return TextStyle(
      color: fontColor,
      fontSize: fontSize,
      fontFamily: fontFamily ?? saansTrial,
      fontWeight: fontWeight ?? FontWeight.w600,
      overflow: textOverflow,
      decoration: textDecoration,
      decorationColor: decorationsColor,
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                              MEDIUM TEXT STYLE                             */
  /* -------------------------------------------------------------------------- */

  static TextStyle medium(
    double fontSize, {
    Color? fontColor = AppColors.black2F3039,
    TextOverflow? textOverflow,
    String? fontFamily,
    FontWeight? fontWeight,
    TextDecoration? textDecoration,
    Color? decorationsColor,
  }) {
    return TextStyle(
      color: fontColor,
      fontSize: fontSize,
      fontFamily: fontFamily ?? saansTrial,
      fontWeight: fontWeight ?? FontWeight.w500,
      overflow: textOverflow,
      decoration: textDecoration,
      decorationColor: decorationsColor,
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                             REGULAR TEXT STYLE                             */
  /* -------------------------------------------------------------------------- */

  static TextStyle regular(
    double fontSize, {
    Color? fontColor = AppColors.black2F3039,
    TextOverflow? textOverflow,
    String? fontFamily,
    FontWeight? fontWeight,
    TextDecoration? textDecoration,
    double? letterSpacing,
    Color? decorationsColor,
  }) {
    return TextStyle(
      color: fontColor,
      fontSize: fontSize,
      fontFamily: fontFamily ?? saansTrial,
      fontWeight: fontWeight ?? FontWeight.w400,
      overflow: textOverflow,
      decoration: textDecoration,
      letterSpacing: letterSpacing,
      decorationColor: decorationsColor,
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                              LIGHT TEXT STYLE                              */
  /* -------------------------------------------------------------------------- */

  static TextStyle light(
    double fontSize, {
    Color? fontColor = AppColors.black2F3039,
    TextOverflow? textOverflow,
    String? fontFamily,
    FontWeight? fontWeight,
    TextDecoration? textDecoration,
    Color? decorationsColor,
  }) {
    return TextStyle(
      color: fontColor,
      fontSize: fontSize,
      fontFamily: fontFamily ?? saansTrial,
      fontWeight: fontWeight ?? FontWeight.w300,
      overflow: textOverflow,
      decoration: textDecoration,
      decorationColor: decorationsColor,
    );
  }
}
