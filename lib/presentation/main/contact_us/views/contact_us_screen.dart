import 'package:omeeba_new/core/widgets/common_app_bar.dart';
import 'package:omeeba_new/presentation/main/contact_us/controller/contact_us_controller.dart';
import '../../../../core/utils/exports.dart';

class ContactUsScreen extends GetView<ContactUsController> {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.whiteFFFFFF,

        appBar: CommonAppBar(title: 'Contact Us'),

        bottomNavigationBar: Obx(() {
          final loading = controller.isLoading.value;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: AbsorbPointer(
              absorbing: loading,
              child: CommonButton(
                text: '',
                onPressed: loading ? null : controller.onSendMessage,
                width: double.infinity,
                height: 50.h,
                borderRadius: 10.r,
                child: SizedBox(
                  height: 22.h,
                  child: Center(
                    child: loading
                        ? SizedBox(
                      height: 18.h,
                      width: 18.h,
                      child: const CircularProgressIndicator(
                        strokeWidth: 4,
                        color: AppColors.whiteFFFFFF,
                      ),
                    )
                        : Text(
                      'Send Message',
                      style:   TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: GetBuilder<ContactUsController>(
                builder: (_) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 8.h),

                      CommonTextField(
                        hintText: 'Your Name',
                        labelText: 'Your Name',
                        controller: controller.nameController,
                        onChanged: (_) => controller.validateName(),
                        errorText: controller.nameError,
                        textStyle: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
                        fillColor: AppColors.whiteFFFFFF,
                        textInputAction: TextInputAction.next,
                      ),

                      SizedBox(height: 12.h),

                      CommonTextField(
                        hintText: 'Email',
                        labelText: 'Email',
                        controller: controller.emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => controller.validateEmail(),
                        errorText: controller.emailError,
                        textStyle: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
                        fillColor: AppColors.whiteFFFFFF,
                        textInputAction: TextInputAction.next,
                      ),

                      SizedBox(height: 12.h),

                      CommonTextField(
                        hintText: 'Subject',
                        labelText: 'Subject',
                        controller: controller.subjectController,
                        onChanged: (_) => controller.validateSubject(),
                        errorText: controller.subjectError,
                        textStyle: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
                        fillColor: AppColors.whiteFFFFFF,
                        textInputAction: TextInputAction.next,
                      ),

                      SizedBox(height: 12.h),

                      CommonTextField(
                        hintText: 'Message...',
                        labelText: 'Message...',
                        controller: controller.messageController,
                        maxLines: 4,
                        minLines: 4,
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (_) => controller.validateMessage(),
                        errorText: controller.messageError,
                        textStyle: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
                        fillColor: AppColors.whiteFFFFFF,
                        textInputAction: TextInputAction.newline,
                      ),

                      SizedBox(height: 20.h),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
