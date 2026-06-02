import 'package:flutter/gestures.dart';
import 'package:omeeba_new/core/widgets/common_loader.dart';

import 'package:omeeba_new/presentation/auth/controller/auth_controller.dart';
import 'package:omeeba_new/presentation/auth/views/forgot_password_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/exports.dart';

class LoginScreen extends GetView<AuthController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppFunctions().closeKeyboard(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.whiteFFFFFF,
        resizeToAvoidBottomInset: false,

        body: GetBuilder<AuthController>(
          builder: (controller) {
            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Gap(60.h),
                        Align(
                          alignment: AlignmentGeometry.center,
                          child: Image.asset(Assets.images.logo.path, scale: 3, color: AppColors.black2F3039),
                        ),
                        Gap(48.h),
                        Text('Welcome back', style: TextStyles.bold(28.sp, fontColor: AppColors.black2F3039)),
                        Text(
                          'It’s everything you need to hype yourself',
                          style: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499),
                        ),
                        Gap(30.h),
                        // CommonTextField(
                        //   onChanged: (val) {
                        //     controller.update();
                        //   },
                        //   hintText: 'Email',
                        //   controller: controller.emailController,
                        //   keyboardType: TextInputType.emailAddress,
                        //   validator: ValidationUtils.validateEmail,
                        // ),
                        CommonTextField(
                          onChanged: (val) {
                            controller.validateEmail();
                          },
                          errorText: controller.emailError,
                          hintText: 'Email',
                          controller: controller.emailController,
                          keyboardType: TextInputType.emailAddress,
                          labelText: 'Email',
                        ),
                        Gap(15.h),

                        CommonTextField(
                          obscureText: controller.isSecure,
                          onChanged: (value) {
                            controller.validatePass();
                          },

                          errorText: controller.passwordError,
                          hintText: 'Password',
                          controller: controller.passController,
                          labelText: 'Password',
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () {
                              controller.clearData(context);
                              Get.to(() => ForgotPasswordScreen(formSetting: false));
                            },
                            child: Text(
                              'Forgot your password?',
                              style: TextStyles.medium(
                                14.sp,
                                textDecoration: TextDecoration.underline,
                                fontColor: AppColors.black141414,
                              ),
                            ),
                          ),
                        ),
                        Gap(30.h),
                        Obx(() {
                          return CommonButtonWidget(
                            height: 48.h,

                            color:
                                controller.emailController.text.isNotEmpty &&
                                    controller.passController.text.isNotEmpty &&
                                    controller.emailError.isEmpty &&
                                    controller.passwordError.isEmpty
                                ? AppColors.primaryColor
                                : AppColors.lightPrimaryColor,
                            onPressed: () async {
                              if (controller.emailController.text.isNotEmpty &&
                                  controller.passController.text.isNotEmpty &&
                                  controller.emailError.isEmpty &&
                                  controller.passwordError.isEmpty) {
                                AppFunctions().closeKeyboard(context);
                                if (controller.isAgree == false) {
                                  // AppFunctions().showToast(
                                  //   'Please accept terms and privacy policy',
                                  //   bgColor: AppColors.redFF5353,
                                  // );
                                  AppFunctions.showCustomErrorPopUp(
                                    context,
                                    title: 'Terms & Conditions',
                                    message: 'Please accept terms and privacy policy',
                                  );
                                  return;
                                } else {
                                  await controller.login(context);
                                }
                              }
                              else if (controller.emailController.text.isEmpty &&
                                  controller.passController.text.isEmpty) {
                                // AppFunctions().showToast('Please enter email and password', bgColor: AppColors.red);
                                controller.validateEmail();
                                controller.validatePass();
                                return;
                              }
                            },
                            child: controller.isLoading.value
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [CommonLoader(size: 25, color: AppColors.white)],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Log in', style: TextStyles.semiBold(17.sp, fontColor: AppColors.white)),
                                    ],
                                  ),
                          );
                        }),

                        Gap(20.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyles.regular(14.sp, fontColor: AppColors.grey545454),
                            ),
                            InkWell(
                              onTap: () {
                                controller.clearData(context);
                                Get.toNamed(AppRoutes.signUp);
                              },
                              child: Text(
                                "Sign Up!",
                                style: TextStyles.medium(
                                  14.sp,
                                  textDecoration: TextDecoration.underline,
                                  fontColor: AppColors.black141414,
                                ),
                              ),
                            ),
                          ],
                        ),

                        Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CommonCheckBox(
                              onChanged: (value) {
                                controller.isAgree = !controller.isAgree;
                                controller.update();
                              },
                              value: controller.isAgree,
                            ),
                            Gap(6.w),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3.0),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    text: 'By continuing, you agree to Omeeba ',
                                    style: TextStyles.regular(14.sp, fontColor: AppColors.grey545454),
                                    children: [
                                      TextSpan(
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            launchUrl(Uri.parse('https://example.com/terms'));
                                          },
                                        text: 'Terms of Use ',
                                        style: TextStyles.regular(14.sp, fontColor: AppColors.primaryColor),
                                      ),
                                      TextSpan(
                                        text: 'and ',
                                        style: TextStyles.regular(14.sp, fontColor: AppColors.grey545454),
                                      ),
                                      TextSpan(
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            launchUrl(Uri.parse('https://example.com/terms'));
                                          },
                                        text: 'Privacy Policy.',
                                        style: TextStyles.regular(14.sp, fontColor: AppColors.primaryColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Gap(20.h),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
