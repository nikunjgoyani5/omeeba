import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';
import 'package:omeeba_new/core/widgets/common_app_bar.dart';
import 'package:omeeba_new/core/widgets/common_button.dart';
import 'package:omeeba_new/core/widgets/common_loader.dart';
import 'package:omeeba_new/core/widgets/common_text_field.dart';
import 'package:omeeba_new/gen/assets.gen.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/text_styles.dart';
import '../controller/settings_controller.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<SettingsController>(
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: CommonAppBar(title: "Change password"),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
            child: Obx(() {
              return CommonButtonWidget(
                color:
                    controller.currentPassword.text.isNotEmpty &&
                        controller.newPassword.text.isNotEmpty &&
                        controller.reTypingPassword.text.isNotEmpty &&
                        controller.passwordError.isEmpty &&
                        controller.cPassError.isEmpty &&
                        controller.currentPassError.isEmpty
                    ? AppColors.primaryColor
                    : AppColors.lightPrimaryColor,
                onPressed: () async {
                  if (controller.newPassword.text.isNotEmpty &&
                      controller.reTypingPassword.text.isNotEmpty &&
                      controller.currentPassword.text.isNotEmpty &&
                      controller.passwordError.isEmpty &&
                      controller.cPassError.isEmpty &&
                      controller.currentPassError.isEmpty) {
                    if (controller.onTapChangePass()) {
                      await controller.changePassApi(context);
                    }
                  } else if (controller.currentPassword.text.isEmpty &&
                      controller.newPassword.text.isEmpty &&
                      controller.reTypingPassword.text.isEmpty) {
                    AppFunctions().showToast(
                      'Please enter password',
                      bgColor: AppColors.red,
                    );
                    return;
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    controller.isLoading.value
                        ? CommonLoader(size: 22, color: AppColors.white)
                        : Text(
                            'Change Password',
                            style: TextStyles.semiBold(
                              17.sp,
                              fontColor: AppColors.white,
                            ),
                          ),
                  ],
                ),
              );
            }),
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
            child: Column(
              children: [
                CommonTextField(
                  suffixIcon: InkWell(
                    radius: 60,
                    onTap: () {
                      controller.isSecureCurrent = !controller.isSecureCurrent;
                      controller.update();
                    },
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: controller.isSecureCurrent == true
                          ? Image.asset(Assets.icons.icCloseEye.path)
                          : Image.asset(Assets.icons.icEye.path),
                    ),
                  ),
                  onChanged: (val) {
                    controller.validateCurrentPass();
                  },
                  errorText: controller.currentPassError,
                  obscureText: controller.isSecureCurrent,
                  borderColor: AppColors.gray8C9499.withValues(alpha: 0.4),
                  controller: controller.currentPassword,
                  hintText: "Current Password",
                  labelText: "Current Password",
                ),
                Gap(12.h),
                CommonTextField(
                  suffixIcon: InkWell(
                    radius: 60,
                    onTap: () {
                      controller.isSecure = !controller.isSecure;
                      controller.update();
                    },
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: controller.isSecure == true
                          ? Image.asset(Assets.icons.icCloseEye.path)
                          : Image.asset(Assets.icons.icEye.path),
                    ),
                  ),
                  onChanged: (val) {
                    controller.validatePass();
                    controller.validateCPass();
                  },
                  errorText: controller.passwordError,
                  obscureText: controller.isSecure,
                  borderColor: AppColors.gray8C9499.withValues(alpha: 0.4),
                  hintText: "New password",
                  controller: controller.newPassword,
                  labelText: "New password",
                ),
                Gap(12.h),
                CommonTextField(
                  onChanged: (val) {
                    controller.validateCPass();
                  },
                  errorText: controller.cPassError,
                  obscureText: controller.isConfirmPasswordSecure,
                  borderColor: AppColors.gray8C9499.withValues(alpha: 0.4),
                  hintText: "Retype new password",
                  controller: controller.reTypingPassword,
                  labelText: "Retype new password",

                  suffixIcon: InkWell(
                    radius: 60,
                    onTap: () {
                      controller.isConfirmPasswordSecure =
                          !controller.isConfirmPasswordSecure;
                      controller.update();
                    },
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: controller.isConfirmPasswordSecure == true
                          ? Image.asset(Assets.icons.icCloseEye.path)
                          : Image.asset(Assets.icons.icEye.path),
                    ),
                  ),
                ),
                Gap(10.h),
                Row(
                  mainAxisAlignment: .end,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => Get.toNamed(AppRoutes.forgotPassword),
                        child: Text(
                          'Forgot password?',
                          style: TextStyles.medium(
                            14.sp,
                            textDecoration: TextDecoration.underline,
                            decorationsColor: AppColors.primaryColor,
                            fontColor: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
