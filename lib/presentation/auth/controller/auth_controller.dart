import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/repository/auth_repository.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/services/onesignal_notification_service.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/utils/validators.dart';
import 'package:omeeba_new/presentation/auth/views/otp_verification_screen.dart';

import '../views/reset_password_screen.dart';

class AuthController extends GetxController {
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController userNameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  bool isSecure = false;
  bool isConfirmPasswordSecure = false;

  bool isAgree = false;
  String selectedLanguage = 'English';
  Country selectedCountry = Country.parse('IN'); // Default to India
  String passwordError = '';
  String cPassError = '';
  String emailError = '';
  String nameError = '';
  String phoneError = '';
  String userNameError = '';

  RxBool isLoading = false.obs;
  RxBool resendLoading = false.obs;

  validatePass() {
    passwordError = ValidationUtils.validatePassword(passController.text.trim()) ?? '';
    update();
  }


  validateCPass() {
    if (confirmPasswordController.text.isEmpty) {
      cPassError = "Password is required";
    } else if (passController.text != confirmPasswordController.text) {
      cPassError = "Password doesn't match";
    } else {
      cPassError = '';
    }
    update();
  }

  validateEmail() {
    emailError = ValidationUtils.validateEmail(emailController.text.trim()) ?? '';
    update();
  }

  validateName() {
    nameError = ValidationUtils.validateName(nameController.text.trim()) ?? '';
    update();
  }

  validateUName() {
    userNameError = ValidationUtils.validateName(userNameController.text.trim()) ?? '';
    update();
  }

  validatePhone() {
    phoneError = ValidationUtils.validatePhone(phoneController.text.trim(), countryCode: selectedCountry.countryCode.trim()) ?? '';
    update();
  }

  void updateCountry(Country country) {
    selectedCountry = country;
    validatePhone(); // Re-validate phone when country changes
    update();
  }

  void updateLanguage(String language) {
    selectedLanguage = language;
    update();
  }

  bool onTapForgotPass() {
    validateEmail();
    if (emailError.isEmpty) {
      return true;
    } else {
      return false;
    }
  }

  void clearData(BuildContext c) {
    AppFunctions().closeKeyboard(c);
    emailController.clear();
    passController.clear();
    nameController.clear();
    userNameController.clear();
    phoneController.clear();
    confirmPasswordController.clear();
    emailError = '';
    passwordError = '';
    nameError = '';
    userNameError = '';
    phoneError = '';
    cPassError = '';
    isConfirmPasswordSecure = false;
    isSecure = false;
    isAgree = false;
    selectedCountry = Country.parse('IN');
    otpController.clear();

    update();
  }

  bool onTapSignUp() {
    validatePass();
    validateEmail();
    validateName();
    validateUName();
    validatePhone();

    if (passwordError.isEmpty &&
        emailError.isEmpty &&
        nameError.isEmpty &&
        userNameError.isEmpty &&
        phoneError.isEmpty) {
      return true;
    } else {
      return false;
    }
  }

  void startTimer() {
    remainingSeconds = 600;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        update();
      } else {
        timer.cancel();
        update();
      }
    });
  }

  TextEditingController otpController = TextEditingController();

  Timer? timer;
  int remainingSeconds = 600;
  String email = '';

  bool get isTimerExpired => remainingSeconds == 0;

  String get formattedTime {
    int minutes = remainingSeconds ~/ 60;
    int seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool isOtpComplete() {
    return otpController.text.length == 6;
  }

  bool onTapResetPass() {
    validatePass();
    validateCPass();

    if (passwordError.isEmpty && cPassError.isEmpty) {
      return true;
    } else {
      return false;
    }
  }

  ////API

  AuthRepository authRepository = AuthRepository();

  Future<void> login(BuildContext context) async {
    isLoading.value = true;
    await authRepository.login(
      body: {"email": emailController.text.trim(), "password": passController.text.trim()},
      onSuccess: (ApiResponse response) async {
        try {
          debugPrint('${response.toString()} ');

          isLoading.value = false;
          // Await every pref write so userId is guaranteed persisted before
          // DashboardController reads it to open the socket connection.
          await PrefService.setValue(PrefKeys.accessToken, response.data['token'] ?? "");
          await PrefService.setValue(PrefKeys.isLogin, true);
          await PrefService.setValue(PrefKeys.userId, response.data['user']['id'] ?? '');
          await PrefService.setValue(PrefKeys.userName, response.data['user']['username'] ?? '');
          await PrefService.setValue(PrefKeys.name, response.data['user']['name'] ?? '');
          await PrefService.setValue(PrefKeys.userProfile, response.data['user']['profileImage'] ?? '');
          await PrefService.setValue(PrefKeys.isVerifiedBeach, response.data['user']['isVerifiedBadge'] ?? '');
          await PrefService.setValue(PrefKeys.userEmail, response.data['user']['email'] ?? '');
          await PrefService.setValue(
            PrefKeys.userPhone,
            "${response.data['user']['countryCode']}${response.data['user']['phoneNumber']}",
          );
          OneSignalNotificationService.registerUserToOneSignal(PrefService.getString(PrefKeys.userId));


          clearData(context);
          Get.offAllNamed(AppRoutes.dashboard);
          // AppFunctions.showCustomToast(context, message: response.message ?? 'Login Successful!', isSuccess: true);
        } catch (e) {
          debugPrint('error:::${e.toString()} ');

          isLoading.value = false;
        }
      },
      onError: (AppException error) {
        isLoading.value = false;
        final apiErrorType = _extractErrorType(error);
        final message = error.message;
        AppFunctions.showCustomErrorPopUp(context, message: message, title: 'Login Alert!');
        if (apiErrorType == 'UnverifiedUser') {
          // User email is not verified yet → show OTP verification screen.
          otpController.clear();
          Get.off(() => OtpVerificationScreen(fromSignup: true, formSetting: false));
          return;
        }


      },
    );
    isLoading.value = false;
  }

  /// Attempts to extract backend `errorType` from the exception.
  ///
  /// Your API example returns:
  /// `{ "errorType": "UnverifiedUser", "message": "Please verify your email address first", ... }`
  ///
  /// Depending on how the HTTP layer wraps errors, the exact field may live in:
  /// - `error.originalError` (DioException response data)
  /// - or inside `error.message`
  String? _extractErrorType(AppException error) {
    // 1) Try originalError.response?.data (best case)
    try {
      final original = error.originalError;
      if (original == null) return null;
      final dynamic data = (original as dynamic).response?.data;
      if (data is Map) {
        final v = data['errorType'];
        if (v is String && v.isNotEmpty) return v;
      }
    } catch (_) {}

    // 2) Fallback: infer from message
    final msg = error.message.toLowerCase();
    if (msg.contains('unverifieduser') || msg.contains('verify your email')) return 'UnverifiedUser';
    return null;
  }

  Future<void> signUp(BuildContext context) async {
    isLoading.value = true;
    await authRepository.signUp(
      body: {
        "email": emailController.text.trim(),
        "password": passController.text,
        "phoneNumber": phoneController.text.trim(),
        "countryCode": "+${selectedCountry.phoneCode}",
        "name": nameController.text.trim(),
        "username": userNameController.text.trim(),
      },
      onSuccess: (ApiResponse response) {
        try {
          isLoading.value = false;

          Get.to(() => OtpVerificationScreen(fromSignup: true, formSetting: false));
          // AppFunctions.showCustomToast(context, message: response.message ?? '', isSuccess: true);
        } catch (e) {
          debugPrint('error:::${e.toString()} ');

          isLoading.value = false;
          AppFunctions.showCustomErrorPopUp(
            context,
            message: response.message ?? 'Something went wrong!',
            title: 'Signup Alert!',
          );
        }
      },
      onError: (AppException error) {
        isLoading.value = false;
        String message = error.message;

        AppFunctions.showCustomErrorPopUp(context, message: message, title: 'Signup Alert!');
      },
    );
    isLoading.value = false;
  }

  Future<void> verifyOtp({required bool fromSignUp, required bool formSetting, required BuildContext context}) async {
    isLoading.value = true;
    await authRepository.otpVerification(
      body: {"otp": otpController.text, "email": emailController.text.trim()},
      onSuccess: (ApiResponse response) async {
        try {
          isLoading.value = false;

          if (fromSignUp) {
          await PrefService.setValue(PrefKeys.accessToken, response.data['token'] ?? "");
          await PrefService.setValue(PrefKeys.isLogin, true);
          await PrefService.setValue(PrefKeys.userId, response.data['user']?['id'] ?? '');
          await PrefService.setValue(PrefKeys.userName, response.data['user']['username'] ?? '');
          await PrefService.setValue(PrefKeys.name, response.data['user']['name'] ?? '');
          await PrefService.setValue(
            PrefKeys.userPhone,
            "${response.data['user']['countryCode']}${response.data['user']['phoneNumber']}",
          );
          await PrefService.setValue(PrefKeys.userEmail, response.data['user']?['email'] ?? '');
          await OneSignalNotificationService.registerUserToOneSignal( response.data['user']?['id'] ?? '');
            Get.offAllNamed(AppRoutes.dashboard);
          } else {
            Get.off(() => ResetPasswordScreen(formSetting: formSetting));
          }
          otpController.clear();
          // AppFunctions.showCustomToast(context, message: response.message ?? "Otp verified", isSuccess: true);
        } catch (e) {
          debugPrint('error:::${e.toString()} ');
          otpController.clear();
          isLoading.value = false;
          AppFunctions.showCustomErrorPopUp(
            context,
            message: response.message ?? "Something went wrong!",
            title: 'OTP Alert!',
          );

          // AppFunctions.showCustomToast(context, message: response.message ?? "Something went wrong!", isSuccess: false);
        }
      },
      onError: (AppException error) {
        isLoading.value = false;
        String message = error.message;
        otpController.clear();

        AppFunctions.showCustomErrorPopUp(context, message: message, title: 'OTP Alert!');
      },
    );
    isLoading.value = false;
  }

  Future<void> forgotPassApi(BuildContext context, bool formSetting) async {
    isLoading.value = true;
    await authRepository.forgotPass(
      body: {"email": emailController.text.trim()},
      onSuccess: (ApiResponse response) {
        isLoading.value = false;
        Get.to(() => OtpVerificationScreen(fromSignup: false, formSetting: formSetting));
        // AppFunctions.showCustomToast(context, message: response.message ?? 'Otp Sent', isSuccess: true);
      },
      onError: (AppException error) {
        isLoading.value = false;
        String message = error.message;
        AppFunctions.showCustomErrorPopUp(context, message: message, title: 'Forgot Password Alert!');
      },
    );
    isLoading.value = false;
  }

  Future<void> resendOtpAPI({required BuildContext context}) async {
    resendLoading.value = true;
    await authRepository.resendOtp(
      body: {"email": emailController.text.trim()},
      onSuccess: (ApiResponse response) {
        try {
          resendLoading.value = false;
          startTimer();
          // AppFunctions.showCustomToast(context, message: response.message ?? 'Otp Sent', isSuccess: true);
        } catch (e) {
          debugPrint('error:::${e.toString()} ');

          resendLoading.value = false;
          AppFunctions.showCustomErrorPopUp(
            context,
            message: response.message ?? "Something went wrong!",
            title: 'OTP Alert!',
          );
        }
      },
      onError: (AppException error) {
        resendLoading.value = false;
        String message = error.message;
        AppFunctions.showCustomErrorPopUp(context, message: message, title: 'OTP Alert!');
      },
    );
    resendLoading.value = false;
  }

  Future<void> resetPassApi(BuildContext context, bool formSetting) async {
    isLoading.value = true;
    await authRepository.resetPassword(
      body: {"email": emailController.text.trim(), "newPassword": passController.text.trim()},
      onSuccess: (ApiResponse response) {
        try {
          isLoading.value = false;
          AppFunctions.showCustomToast(context, message: response.message ?? 'Password Reset Successfully', isSuccess: true);
          if (formSetting) {
            Get.back();
            Get.back();
          } else {
            Get.offAllNamed(AppRoutes.login);
          }
        } catch (e) {
          debugPrint('error:::${e.toString()} ');
          isLoading.value = false;
          AppFunctions.showCustomErrorPopUp(
            context,
            message: response.message ?? "Something went wrong!",
            title: 'Reset Password Alert!',
          );
        }
      },
      onError: (AppException error) {
        isLoading.value = false;
        String message = error.message;
        AppFunctions.showCustomErrorPopUp(context, message: message, title: 'Reset Password Alert!');
      },
    );
    isLoading.value = false;
  }
}
