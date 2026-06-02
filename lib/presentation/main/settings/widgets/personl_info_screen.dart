import 'package:omeeba_new/core/widgets/common_app_bar.dart';
import '../../../../core/utils/app_prefrence.dart';
import '../../../../core/utils/exports.dart';
import '../../myprofile/controller/my_profile_controller.dart';

class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(title: "Your personal info"),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
        child: Column(
          children: [
            CommonTextField(
              borderColor: AppColors.gray8C9499.withValues(alpha: 0.4),
              controller: TextEditingController(text: PrefService.getString(PrefKeys.userEmail)),
              hintText: "Email",
              labelText: "Email",
              readOnly: true,
            ),
            Gap(12.h),
            CommonTextField(
              borderColor: AppColors.gray8C9499.withValues(alpha: 0.4),
              hintText: "Name",
              controller: TextEditingController(text: Get.find<MyProfileController>().profile.value?.name),
              labelText: "Name",
              readOnly: true,
            ),
            Gap(12.h),
            CommonTextField(
              borderColor: AppColors.gray8C9499.withValues(alpha: 0.4),
              hintText: "Contact",
              controller: TextEditingController(text: PrefService.getString(PrefKeys.userPhone).toString()),
              labelText: "Contact",
              readOnly: true,
            ),
            Gap(10.h),
          ],
        ),
      ),
    );
  }
}
