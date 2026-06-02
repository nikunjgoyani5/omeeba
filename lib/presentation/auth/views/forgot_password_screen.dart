import 'package:omeeba_new/core/widgets/common_loader.dart';
import 'package:omeeba_new/presentation/auth/controller/auth_controller.dart';

import '../../../core/utils/app_prefrence.dart';
import '../../../core/utils/exports.dart';

class ForgotPasswordScreen extends GetView<AuthController> {
  final bool formSetting;

  const ForgotPasswordScreen({super.key, required this.formSetting});

  @override
  Widget build(BuildContext context) {
    if (formSetting) {
      controller.emailController.text = PrefService.getString(PrefKeys.userEmail);
    }
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (!didPop) {
          controller.clearData(context);
          Get.back();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        resizeToAvoidBottomInset: false,
        appBar: CommonAppbar(
          title: '',
          onLeadPress: () {
            controller.clearData(context);
            Get.back();
          },
        ),
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
                        Gap(30.h),
                        Text('Forgot password', style: TextStyles.bold(28.sp)),
                        Gap(4.h),
                        Text(
                          'Enter your email to get an OTP for password reset.',
                          style: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499),
                        ),
                        Gap(35.h),
                        CommonTextField(
                          onChanged: (val) {
                            controller.validateEmail();
                          },
                          keyboardType: TextInputType.emailAddress,
                          hintText: 'Email',
                          labelText: 'Email',
                          controller: controller.emailController,
                          // validator: ValidationUtils.validateEmail,
                          errorText: controller.emailError,
                        ),
                        Gap(28.h),
                        Obx(() {
                          return CommonButtonWidget(
                            height: 48.h,
                            color: controller.emailController.text.isNotEmpty && controller.emailError.isEmpty
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
                                      Text('Submit', style: TextStyles.semiBold(16.sp, fontColor: AppColors.white)),
                                    ],
                                  ),
                            onPressed: () async {
                              if (controller.emailController.text.isNotEmpty && controller.emailError.isEmpty) {
                                AppFunctions().closeKeyboard(context);
                                if (controller.onTapForgotPass()) {
                                  await controller.forgotPassApi(context, formSetting);
                                }
                              } else if (controller.emailController.text.isEmpty) {
                                // AppFunctions().showToast('Please enter email', bgColor: AppColors.red);
                                controller.validateEmail();

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
      ),
    );
  }
}
