import 'package:flutter/services.dart';
import 'package:omeeba_new/core/widgets/common_loader.dart';
import 'package:omeeba_new/presentation/auth/controller/auth_controller.dart';
import 'package:pinput/pinput.dart';

import '../../../core/utils/exports.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.fromSignup, required this.formSetting});

  final bool fromSignup;
  final bool formSetting;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  AuthController authController = Get.find();

  @override
  void initState() {
    authController.startTimer();
    super.initState();
  }

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
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap(40.h),
                      Text('OTP verification', style: TextStyles.bold(28.sp)),
                      Gap(5.h),
                      RichText(
                        text: TextSpan(
                          text: 'Please enter the 6-digit codes sent to ',
                          style: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499),
                          children: [TextSpan(text: controller.emailController.text, style: TextStyles.regular(16.sp))],
                        ),
                      ),
                      Gap(37.h),
                      Pinput(
                        preFilledWidget: Text('-', style: TextStyles.semiBold(18.sp, fontColor: AppColors.grey888888)),

                        length: 6,
                        controller: controller.otpController,
                        defaultPinTheme: PinTheme(
                          width: 50.w,
                          height: 50.h,
                          textStyle: TextStyles.semiBold(20.sp),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray8C9499.withValues(alpha: 0.40)),
                          ),
                        ),

                        focusedPinTheme: PinTheme(
                          width: 50.w,
                          height: 50.h,
                          textStyle: TextStyles.semiBold(20.sp),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryColor, width: 1),
                          ),
                        ),
                        submittedPinTheme: PinTheme(
                          width: 50.w,
                          height: 50.h,
                          textStyle: TextStyles.semiBold(20.sp),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray8C9499.withValues(alpha: 0.40)),
                          ),
                        ),
                        onChanged: (value) {
                          controller.update();
                        },
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                        ],
                        onCompleted: (value) async {
                          if (controller.isOtpComplete()) {
                            await controller.verifyOtp(
                              fromSignUp: widget.fromSignup,
                              formSetting: widget.formSetting,
                              context: context,
                            );
                          }
                        },
                      ),
                      Gap(28.h),
                      controller.isTimerExpired
                          ? InkWell(
                              onTap: () async {
                                await controller.resendOtpAPI(context: context);
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Code expired!! ',
                                      style: TextStyles.medium(15.sp, fontColor: AppColors.black141414),
                                    ),
                                    Spacer(),

                                    Obx(() {
                                      return controller.resendLoading.value
                                          ? CommonLoader(color: AppColors.primaryColor, size: 16)
                                          : Text(
                                              'Resend',
                                              style: TextStyles.medium(16.sp, fontColor: AppColors.primaryColor),
                                            );
                                    }),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                color: AppColors.lightPrimaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                // border: Border.all(color: AppColors.primaryColor, width: 0.7),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, size: 20),
                                  Gap(10.w),
                                  Text('Code expires in', style: TextStyles.medium(15.sp)),
                                  Spacer(),
                                  Text(controller.formattedTime, style: TextStyles.medium(16.sp)),
                                ],
                              ),
                            ),
                      Gap(30.h),

                      Obx(() {
                        return CommonButtonWidget(
                          height: 48.h,
                          color: controller.isOtpComplete() ? AppColors.primaryColor : AppColors.lightPrimaryColor,
                          child: controller.isLoading.value
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [CommonLoader(size: 25, color: AppColors.white)],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Verify code', style: TextStyles.semiBold(16.sp, fontColor: AppColors.white)),
                                  ],
                                ),
                          onPressed: () async {
                            if (controller.otpController.text.isNotEmpty) {
                              if (controller.isOtpComplete()) {
                                await controller.verifyOtp(
                                  fromSignUp: widget.fromSignup,
                                  formSetting: widget.formSetting,
                                  context: context,
                                );
                              }
                            } else {
                              AppFunctions.showCustomErrorPopUp(
                                context,
                                message: 'Please enter OTP',
                                title: 'OTP Alert!',
                              );
                              return;
                            }
                          },
                        );
                      }),
                      Gap(20.h),
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
