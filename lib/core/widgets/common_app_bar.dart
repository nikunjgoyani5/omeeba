import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../gen/assets.gen.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? titleColor;
  final double? titleFontSize;
  final FontWeight? titleFontWeight;
  final double? leadingWidth;
  final double? titleSpacing;
  final bool? bottomLine;
  final bool centerTitle;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.actions,
    this.backgroundColor,
    this.titleColor,
    this.titleFontSize,
    this.titleFontWeight,
    this.leadingWidth,
    this.titleSpacing,
    this.bottomLine = true,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.whiteFFFFFF,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: showBackButton
          ? Padding(
              padding: EdgeInsets.only(left: 16),
              child: IconButton(
                hoverColor: AppColors.transparentColor,
                splashColor: AppColors.transparentColor,
                highlightColor: AppColors.transparentColor,
                icon: Assets.icons.icArrowBack.image(height: 18.h, width: 18.w),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              ),
            )
          : null,
      leadingWidth: leadingWidth ?? (showBackButton ? 40.w : 0),
      bottom: (bottomLine ?? true)
          ? const PreferredSize(
              preferredSize: Size.fromHeight(1.0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.whiteEAEAEA,
              ),
            )
          : null,
      title: Text(
        title,
        style: TextStyles.semiBold(
          titleFontSize ?? 22.sp,
          fontColor: titleColor ?? AppColors.black2F3039,
        ).copyWith(fontWeight: titleFontWeight),
      ),
      centerTitle: centerTitle,
      titleSpacing: titleSpacing ?? 15.w,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
