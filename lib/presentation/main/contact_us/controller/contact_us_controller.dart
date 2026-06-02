import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/repository/contact_repository.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/utils/validators.dart';

class ContactUsController extends GetxController {
  ContactUsController({ContactRepository? repository})
      : _repository = repository ?? Get.find<ContactRepository>();

  final ContactRepository _repository;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String nameError = '';
  String emailError = '';
  String subjectError = '';
  String messageError = '';

  /// True while the contact API request is in flight; ignore further taps until success or error.
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _applyDefaultUserFields();
  }

  /// Prefill name and email from stored profile (login / profile sync).
  void _applyDefaultUserFields() {
    final displayName = PrefService.getString(PrefKeys.name).trim();
    final username = PrefService.getString(PrefKeys.userName).trim();
    final email = PrefService.getString(PrefKeys.userEmail).trim();

    if (displayName.isNotEmpty) {
      nameController.text = displayName;
    } else if (username.isNotEmpty) {
      nameController.text = username;
    }

    if (email.isNotEmpty) {
      emailController.text = email;
    }
    update();
  }

  void validateName() {
    nameError = ValidationUtils.validateName(nameController.text) ?? '';
    update();
  }

  void validateEmail() {
    emailError = ValidationUtils.validateEmail(emailController.text) ?? '';
    update();
  }

  void validateMessage() {
    messageError = ValidationUtils.validateDescription(messageController.text) ?? '';
    update();
  }

  void validateSubject() {
    subjectError = ValidationUtils.validateSubject(subjectController.text) ?? '';
    update();
  }

  bool validateForm() {
    validateName();
    validateEmail();
    validateMessage();
    validateSubject();
    return nameError.isEmpty && emailError.isEmpty && messageError.isEmpty && subjectError.isEmpty;
  }

  Future<void> onSendMessage() async {
    if (!validateForm()) return;
    if (isLoading.value) return;

    isLoading.value = true;
    try {
      await _repository.submitContact(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        subject: subjectController.text.trim(),
        message: messageController.text.trim(),
        onSuccess: (response) {
          AppFunctions().showToast(
            response.message ?? 'Message sent successfully',
            bgColor: AppColors.green,
            textColor: AppColors.white,
          );
          _clearMessageFields();
          _applyDefaultUserFields();
          Get.back();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        onError: (e) {
          AppFunctions().showToast(
            e.message.isNotEmpty ? e.message : 'Something went wrong',
            bgColor: AppColors.redFF5353,
            textColor: AppColors.white,
          );
          _clearMessageFields();
        },
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _clearMessageFields() {
    nameController.clear();
    emailController.clear();
    subjectController.clear();
    messageController.clear();
    subjectError = '';
    messageError = '';
    nameError = '';
    emailError = '';
    update();
  }

  void clearForm() {
    nameController.clear();
    emailController.clear();
    messageController.clear();
    subjectController.clear();
    subjectError = '';
    nameError = '';
    emailError = '';
    messageError = '';
    _applyDefaultUserFields();
    update();
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    messageController.dispose();
    subjectController.dispose();
    super.onClose();
  }
}
