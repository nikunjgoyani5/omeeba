import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';


class CommonLoader extends StatelessWidget {
  const CommonLoader({super.key, this.color, this.size});

  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Platform.isAndroid
        ? SizedBox(
        height: size,
        width: size,
        child: CircularProgressIndicator(color: color ?? AppColors.primaryColor))
        : CupertinoActivityIndicator(color: color ?? AppColors.primaryColor);
  }
}
