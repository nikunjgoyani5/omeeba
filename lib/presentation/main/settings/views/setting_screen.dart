import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:omeeba_new/core/data/explore/explore_feed_local.dart';
import 'package:omeeba_new/core/data/home/home_feed_local.dart';
import 'package:omeeba_new/core/data/zeals/zeals_feed_local.dart';
import 'package:omeeba_new/core/services/socket_service.dart';
import 'package:omeeba_new/core/services/zeal_video_cache_service.dart';
import 'package:omeeba_new/core/utils/app_constant.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/presentation/main/settings/widgets/personl_info_screen.dart';

import '../../../../core/services/app_info_service.dart';
import '../../../../core/services/onesignal_notification_service.dart';
import '../../../../core/utils/exports.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../myprofile/controller/my_profile_controller.dart';
import '../controller/settings_controller.dart';
import '../widgets/change_password.dart';
import '../widgets/polls_activity_screen.dart';
import '../widgets/post_activity_screen.dart';
import '../widgets/saved_screen.dart';
import '../widgets/verified_badge_bottom_sheet.dart';
import '../widgets/verified_badge_success.dart';
import '../widgets/web_view_screen.dart';
import '../widgets/writes_activity_screen.dart';
import '../widgets/zeals_activity_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  SettingsController controller = Get.put(SettingsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayEDF1F4,
      appBar: const CommonAppBar(title: 'Setting'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24.h),
            // ACCOUNTS & PRIVACY Section
            _buildSectionHeader('ACCOUNTS & PRIVACY'),
            SizedBox(height: 8.h),
            _buildSectionCard([
              _buildSettingItem('Password And Security', () {
                Get.to(() => const ChangePassword());
              }),
              _buildDivider(),
              _buildSettingItem('Personal Data', () {
                Get.to(() => const PersonalInfoScreen());
              }),
              _buildDivider(),
              _buildSettingItem('Verified Badge', () {
                if (Get.find<MyProfileController>()
                        .profile
                        .value
                        ?.isVerifiedBadge ==
                    true) {
                  Get.to(() => const VerifiedBadgeSuccess());
                  return;
                }

                controller.loadVerifiedBadgePlansIfNeeded();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const VerifiedBadgeBottomSheet(),
                ).then((_) => controller.clearVerifiedBadgePurchaseState());
              }),
            ]),
            SizedBox(height: 24.h),
            // ACTIVITY Section
            _buildSectionHeader('ACTIVITY'),
            SizedBox(height: 8.h),

            _buildSectionCard([
              _buildNotificationSwitch(() {}),
              _buildDivider(),

              _buildSettingItem('Post you uploaded', () {
                Get.to(() => PostActivityScreen());
                controller.myProfileController!.loadMyWritesIfNeeded();
              }),
              _buildDivider(),
              _buildSettingItem('Writes you\'ve written', () {
                Get.to(() => WritesActivityScreen());
                controller.myProfileController!.loadMyWritesIfNeeded();
              }),
              _buildDivider(),
              _buildSettingItem('Polls you created', () {
                Get.to(() => PollsActivityScreen());
                controller.myProfileController!.loadMyPollsIfNeeded();
              }),
              _buildDivider(),
              _buildSettingItem('Zeals you shared', () {
                Get.to(() => ZealsActivityScreen());
                controller.myProfileController!.loadMyZealsIfNeeded();
              }),
              _buildDivider(),
              _buildSettingItem('Saved', () {
                Get.to(() => const SavedScreen());
              }),
            ]),
            SizedBox(height: 24.h),
            // MORE INFO & SUPPORT Section
            _buildSectionHeader('MORE INFO & SUPPORT'),
            SizedBox(height: 8.h),
            _buildSectionCard([
              _buildSettingItem('Terms of use & conditions', () {
                Get.to(
                  () => CommonWebViewScreen(
                    url: '$socketUrl/terms.html',
                    name: 'Terms of use & Conditions',
                  ),
                );
              }),
              _buildDivider(),
              _buildSettingItem('Privacy policy', () {
                Get.to(
                  () => CommonWebViewScreen(
                    url: '$socketUrl/privacy.html',
                    name: 'Privacy policy',
                  ),
                );
              }),
              _buildDivider(),
              _buildSettingItem('Contact us', () {
                Get.toNamed(AppRoutes.contactUs);
              }),
            ]),
            SizedBox(height: 24.h),
            // AUTHENTICATION Section
            _buildSectionHeader('AUTHENTICATION'),
            SizedBox(height: 8.h),
            _buildSectionCard([
              _buildSettingItem('Logout', () async {
                showLogoutDialog();
              }, isLogout: true),
            ]),
            SizedBox(height: 16.h),
            // Version
            Center(
              child: Text(
                "Version ${AppInfoService.instance.version}",
                style: TextStyles.regular(
                  16.sp,
                  fontColor: AppColors.g8C9499ray,
                ),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Text(
        title,
        style: TextStyles.medium(14.sp, fontColor: AppColors.g8C9499ray),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem(
    String title,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyles.semiBold(
                15.sp,
                fontColor: isLogout
                    ? AppColors.redFF5353
                    : AppColors.black2F3039,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14.sp,
              color: isLogout ? AppColors.redFF5353 : AppColors.g8C9499ray,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.grayEDF1F4,
      indent: 16.w,
      endIndent: 16.w,
    );
  }

  Widget _buildNotificationSwitch(VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notification',
              style: TextStyles.semiBold(
                16.sp,
                fontColor: AppColors.black2F3039,
              ),
            ),
            Obx(() {
              return SizedBox(
                height: 10,
                child: Transform.scale(
                  scale: 0.7,

                  child: CupertinoSwitch(
                    activeTrackColor: AppColors.primaryColor,
                    value: controller.isNotificationOn.value,
                    onChanged: (value) async {
                      controller.isNotificationOn.value = value;
                      // (!controller.isNotificationOn.value);
                      await controller.toggleNotification(context);
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void showLogoutDialog() {
    Future<bool> hasInternet() async {
      final List<ConnectivityResult> result = await Connectivity()
          .checkConnectivity();

      return !result.contains(ConnectivityResult.none);
    }

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Text('Logout', style: TextStyles.medium(21.sp)),
              ),
              Gap(6.h),
              Align(
                alignment: Alignment.center,
                child: Text(
                  'Are you sure want to log out?',
                  style: TextStyles.regular(16.sp),
                ),
              ),
              Gap(18.h),
              Row(
                children: [
                  // Cancel button - remains normal gray CommonButton
                  Expanded(
                    child: CommonButtonWidget(
                      height: 44.h,
                      color: AppColors.g8C9499ray,
                      borderRadius: 40,
                      onPressed: () {
                        Get.back();
                      },
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: TextStyles.medium(
                            16.sp,
                            fontColor: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Gap(10.w),

                  // Yes / Logout button - now using gradient style
                  Expanded(
                    child: Container(
                      height: 44.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: const [
                            AppColors.greyE5E4DC,
                            AppColors.greyE5E4DC,
                          ],
                          stops: const [-0.0864, 0.798],
                          transform: GradientRotation(
                            (320.33 - 90) * math.pi / 180,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            bool internet = await hasInternet();

                            if (!internet) {
                              AppFunctions().showToast(
                                "Please check your internet connection",
                                bgColor: AppColors.redFF5353,
                                textColor: AppColors.white,
                              );
                              Get.back();
                              return;
                            }
                            // Full logout reset — clears activeUserId so the NEXT
                            // login always connects with the correct new user's ID.
                            SocketService.instance.logoutAndReset();

                            // Disconnect one signal service
                            OneSignalNotificationService.logoutOneSignal();
                            // Clear all Hive caches
                            await Future.wait([
                              HomeFeedLocal().clear(),
                              ZealsFeedLocal().clear(),
                              ExploreFeedLocal().clear(),
                            ]);

                            // Clear zeal video disk cache
                            if (Get.isRegistered<ZealVideoCacheService>()) {
                              await Get.find<ZealVideoCacheService>()
                                  .clearCache();
                            }

                            // Clear OneSignal & SharedPreferences
                            await OneSignalNotificationService.setExternalUserId(
                              null,
                            );
                            await PrefService.clear();

                            // Delete all registered GetX controllers
                            Get.deleteAll(force: true);

                            Get.offAllNamed(AppRoutes.login);
                          },
                          borderRadius: BorderRadius.circular(40),
                          child: Center(
                            child: Text(
                              'Yes',
                              style: TextStyles.medium(
                                16.sp,
                                fontColor: AppColors.black000000,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
