import 'package:omeeba_new/core/widgets/common_loader.dart';
import 'package:omeeba_new/presentation/auth/controller/auth_controller.dart';

import '../../../../core/utils/exports.dart';

class ResetPasswordScreen extends GetView<AuthController> {
  final bool formSetting;

  const ResetPasswordScreen({super.key, required this.formSetting});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: false,
      appBar: CommonAppbar(title: ''),
      body: GetBuilder<AuthController>(
        builder: (controller) {
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap(40.h),
                      Text('Reset password', style: TextStyles.bold(28.sp)),
                      Gap(5.h),
                      Text('Enter a new password', style: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499)),
                      Gap(37.h),
                      CommonTextField(
                        onChanged: (val) {
                          controller.validatePass();
                        },
                        errorText: controller.passwordError,

                        obscureText: controller.isSecure,
                        hintText: 'New Password',
                        labelText: 'New Password',
                        controller: controller.passController,
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
                      ),
                      Gap(15.h),
                      CommonTextField(
                        onChanged: (val) {
                          controller.validateCPass();
                        },
                        errorText: controller.cPassError,
                        obscureText: controller.isConfirmPasswordSecure,
                        hintText: 'Confirm password',
                        labelText: 'Confirm password',
                        controller: controller.confirmPasswordController,
                        suffixIcon: InkWell(
                          radius: 60,
                          onTap: () {
                            controller.isConfirmPasswordSecure = !controller.isConfirmPasswordSecure;
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
                      Gap(28.h),
                      Obx(() {
                        return CommonButtonWidget(
                          height: 48.h,
                          color:
                              controller.passController.text.isNotEmpty &&
                                  controller.confirmPasswordController.text.isNotEmpty &&
                                  controller.passwordError.isEmpty &&
                                  controller.cPassError.isEmpty
                              ? AppColors.primaryColor
                              : AppColors.lightPrimaryColor,

                          child: controller.isLoading.value
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [CommonLoader(size: 25, color: AppColors.white)],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Reset Password',
                                      style: TextStyles.semiBold(17.sp, fontColor: AppColors.white),
                                    ),
                                  ],
                                ),
                          onPressed: () async {
                            if (controller.passController.text.isNotEmpty &&
                                controller.confirmPasswordController.text.isNotEmpty &&
                                controller.passwordError.isEmpty &&
                                controller.cPassError.isEmpty) {
                              if (controller.onTapResetPass()) {
                                await controller.resetPassApi(context, formSetting);
                              }
                            } else if (controller.passController.text.isEmpty &&
                                controller.confirmPasswordController.text.isEmpty) {
                              // AppFunctions().showToast('Please enter password', bgColor: AppColors.red);
                              controller.validatePass();
                              controller.validateCPass();

                              return;
                            }
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
