import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

/// Shows a confirmation dialog before delete. Returns [true] if user tapped Delete, [false] if Cancel or dismissed.
Future<bool> showDeleteConfirmationDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      title: Text('Delete?', style: TextStyles.semiBold(18.sp, fontColor: AppColors.black2F3039)),
      content: Text(
        'Are you sure you want to delete this?',
        style: TextStyles.regular(16.sp, fontColor: AppColors.gray707070),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: ButtonStyle(overlayColor: MaterialStatePropertyAll(Colors.transparent)),
          child: Text('Cancel', style: TextStyles.medium(16.sp, fontColor: AppColors.gray707070)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ButtonStyle(overlayColor: MaterialStatePropertyAll(Colors.transparent)),
          child: Text('Delete', style: TextStyles.medium(16.sp, fontColor: AppColors.red)),
        ),
      ],
    ),
  );
  return result == true;
}
