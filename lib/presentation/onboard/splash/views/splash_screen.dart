import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';
import 'package:omeeba_new/gen/assets.gen.dart';

import '../../../../core/services/app_info_service.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(),
          // Centered Logo
          Center(child: Assets.icons.imgAppLogo.image(scale: 2.5)),
          // Version Text at Bottom
          Padding(
            padding: EdgeInsets.only(bottom: 20.h),
            child: Column(
              spacing: 10.h,
              children: [
                Assets.icons.icAppName.svg(),

                Text("Version ${AppInfoService.instance.version}", style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
