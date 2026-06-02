import 'package:omeeba_new/core/widgets/common_app_bar.dart';
import '../../../../core/utils/app_prefrence.dart';
import '../../../../core/utils/exports.dart';
import '../../../../core/widgets/common_profile_image.dart';
import '../../myprofile/controller/my_profile_controller.dart';

class VerifiedBadgeSuccess extends StatefulWidget {
  const VerifiedBadgeSuccess({super.key});

  @override
  State<VerifiedBadgeSuccess> createState() => _VerifiedBadgeSuccessState();
}

class _VerifiedBadgeSuccessState extends State<VerifiedBadgeSuccess> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      appBar: CommonAppBar(title: "Verified badge"),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: [
              Gap(40.h),
              // Profile Picture
              Center(
                child: Container(
                  width: 120.w,
                  height: 120.h,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.grayEDF1F4, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: CommonProfileImage(
                    imageUrl: PrefService.getString(PrefKeys.userProfile),
                  ),
                ),
              ),

              Gap(24.h),
              // Name with Verified Badge
              SizedBox(
                width: 250.w,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        Get.find<MyProfileController>().profile.value?.name ??
                            PrefService.getString(PrefKeys.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.bold(
                          24.sp,
                          fontColor: AppColors.black2F3039,
                        ),
                      ),
                    ),
                    if (Get.find<MyProfileController>()
                            .profile
                            .value
                            ?.isVerifiedBadge ==
                        true) ...[
                      Assets.icons.icVerifyBadge.svg(width: 30.w, height: 30.h),
                    ],
                  ],
                ),
              ),
              Gap(32.h),
              // First Paragraph
              Text(
                'Your verified badge helps build trust and credibility with your audience. It shows that your profile is authentic, making people feel more confident while engaging with your content.',
                style: TextStyles.regular(
                  15.sp,
                  fontColor: AppColors.gray8C9499,
                ),
                textAlign: TextAlign.center,
              ),
              Gap(16.h),
              // Second Paragraph
              Text(
                'The verified badge on your Omeeba profile means your account has been reviewed and verified based on your activity, influence, and the information or documents you provided.',
                style: TextStyles.regular(
                  15.sp,
                  fontColor: AppColors.gray8C9499,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
