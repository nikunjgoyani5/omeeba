import 'package:country_picker/country_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:omeeba_new/core/widgets/common_loader.dart';

import 'package:omeeba_new/presentation/auth/controller/auth_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/exports.dart';

class SignupScreen extends GetView<AuthController> {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthController>(
      builder: (controller) {
        return PopScope(
          canPop: false,
          onPopInvoked: (bool didPop) {
            if (!didPop) {
              controller.clearData(context);
              Get.back();
            }
          },
          child: GestureDetector(
            onTap: () {
              AppFunctions().closeKeyboard(context);
            },
            child: Scaffold(
              backgroundColor: AppColors.white,
              // resizeToAvoidBottomInset: false,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap(60.h),
                          Align(
                            alignment: AlignmentGeometry.center,
                            child: Image.asset(Assets.images.logo.path, scale: 3, color: AppColors.black2F3039),
                          ),
                          Gap(48.h),
                          Text('Sign Up', style: TextStyles.bold(28.sp, fontColor: AppColors.black2F3039)),
                          Text(
                            'It’s everything you need to hype yourself',
                            style: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499),
                          ),
                          Gap(30.h),

                          CommonTextField(
                            onChanged: (val) {
                              controller.validateEmail();
                            },
                            hintText: 'Email',
                            labelText: 'Email',
                            controller: controller.emailController,
                            keyboardType: TextInputType.emailAddress,
                            errorText: controller.emailError,
                          ),

                          Gap(13.h),
                          CommonTextField(
                            onChanged: (val) {
                              controller.validatePhone();
                            },
                            hintText: 'Phone Number',
                            labelText: 'Phone Number',
                            controller: controller.phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            errorText: controller.phoneError,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 16.w, right: 8.w),
                              child: InkWell(
                                onTap: () {
                                  showCountryPicker(
                                    context: context,

                                    showPhoneCode: true,
                                    onSelect: (value) {
                                      controller.updateCountry(value);
                                    },
                                    useRootNavigator: true,
                                    showWorldWide: false,
                                    countryListTheme: CountryListThemeData(
                                      margin: EdgeInsets.symmetric(vertical: 50, horizontal: 20.w),
                                      flagSize: 25,

                                      backgroundColor: AppColors.whiteFFFFFF,
                                      textStyle: TextStyles.regular(16.sp),
                                      borderRadius: BorderRadius.circular(20.w),
                                      inputDecoration: InputDecoration(
                                        labelText: 'Search',
                                        hintText: 'Start typing to search',
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(color: AppColors.gray8C9499.withValues(alpha: 0.40)),
                                          borderRadius: BorderRadius.circular(10.r),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: AppColors.gray8C9499.withValues(alpha: 0.40)),
                                          borderRadius: BorderRadius.circular(10.r),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: AppColors.primaryColor),
                                          borderRadius: BorderRadius.circular(10.r),
                                        ),
                                      ),
                                      searchTextStyle: TextStyles.regular(16.sp),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${controller.selectedCountry.flagEmoji} +${controller.selectedCountry.phoneCode}',
                                      style: TextStyles.medium(16.sp),
                                    ),
                                    Gap(4.w),
                                    Icon(Icons.arrow_drop_down, color: AppColors.gray8C9499, size: 20.sp),
                                  ],
                                ),
                              ),
                            ),
                            maxLength: ValidationUtils.getPhoneNumberLength(controller.selectedCountry.countryCode),
                          ),

                          Gap(13.h),

                          CommonTextField(
                            onChanged: (val) {
                              controller.validateName();
                            },
                            hintText: 'Your Name',
                            labelText: 'Your Name',
                            controller: controller.nameController,
                            // validator: ValidationUtils.validateName,
                            errorText: controller.nameError,
                          ),
                          Gap(6.h),
                          Text(
                            'Username cannot be changed after account creation.',
                            style: TextStyles.regular(12.sp, fontColor: AppColors.gray8C9499),
                          ),
                          Gap(13.h),
                          CommonTextField(
                            onChanged: (val) {
                              controller.validateUName();
                            },
                            hintText: 'Choose / type username',
                            labelText: 'Choose / type username',
                            controller: controller.userNameController,
                            errorText: controller.userNameError,
                            // validator: ValidationUtils.validateName,
                          ),
                          Gap(13.h),
                          CommonTextField(
                            onChanged: (val) {
                              controller.validatePass();
                            },
                            obscureText: controller.isSecure,
                            hintText: 'Password',
                            labelText: 'Password',
                            controller: controller.passController,
                            errorText: controller.passwordError,
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

                          Gap(30.h),
                          Obx(() {
                            return CommonButtonWidget(
                              height: 48.h,
                              color:
                                  controller.nameController.text.isNotEmpty &&
                                      controller.userNameController.text.isNotEmpty &&
                                      controller.emailController.text.isNotEmpty &&
                                      controller.phoneController.text.isNotEmpty &&
                                      controller.passController.text.isNotEmpty &&
                                      controller.nameError.isEmpty &&
                                      controller.userNameError.isEmpty &&
                                      controller.emailError.isEmpty &&
                                      controller.phoneError.isEmpty &&
                                      controller.passwordError.isEmpty
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
                                        Text('Next', style: TextStyles.semiBold(17.sp, fontColor: AppColors.white)),
                                      ],
                                    ),
                              onPressed: () async {
                                if (controller.nameController.text.isNotEmpty &&
                                    controller.userNameController.text.isNotEmpty &&
                                    controller.emailController.text.isNotEmpty &&
                                    controller.phoneController.text.isNotEmpty &&
                                    controller.passController.text.isNotEmpty &&
                                    (controller.onTapSignUp() == true)) {
                                  if (controller.isAgree == false) {
                                    // AppFunctions().showToast(
                                    //   'Please accept terms and privacy policy',
                                    //   bgColor: AppColors.red,
                                    // );
                                    AppFunctions.showCustomErrorPopUp(
                                      context,
                                      title: 'Terms & Conditions',
                                      message: 'Please accept terms and privacy policy',
                                    );
                                    return;
                                  } else {
                                    await controller.signUp(context);
                                  }
                                } else if (controller.emailController.text.isEmpty &&
                                    controller.nameController.text.isEmpty &&
                                    controller.userNameController.text.isEmpty &&
                                    controller.phoneController.text.isEmpty &&
                                    controller.passController.text.isEmpty) {
                                  // AppFunctions().showToast(
                                  //   'Please enter name, email , phone and password',
                                  //   bgColor: AppColors.red,
                                  // );
                                  controller.validateEmail();
                                  controller.validateCPass();
                                  controller.validatePass();
                                  controller.validatePhone();
                                  controller.validateName();
                                  controller.validateUName();
                                  return;
                                }
                              },
                            );
                          }),
                          Gap(15.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: TextStyles.regular(14.sp, fontColor: AppColors.grey545454),
                              ),
                              InkWell(
                                onTap: () {
                                  controller.clearData(context);
                                  Get.back();
                                },
                                child: Text(
                                  "Log In!",
                                  style: TextStyles.medium(14.sp, textDecoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),

                        ],
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar:       Container(
                color: AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
