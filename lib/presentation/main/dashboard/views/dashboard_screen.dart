import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:omeeba_new/presentation/main/notification/views/notification_screen.dart';
import '../../../../core/utils/exports.dart';
import '../../home/views/home_screen.dart';
import '../../myprofile/views/my_profile_view.dart';
import '../../zeals/views/zeals_view.dart';
import '../controller/dashboard_controller.dart';
import '../../notification/controller/notification_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.find<DashboardController>();

    return Scaffold(
      backgroundColor: AppColors.grayEDF1F4,
      body: PopScope(
        canPop: false, // we control navigation manually
        onPopInvokedWithResult: (didPop, _) async {
          final controller = Get.find<DashboardController>();

          // If user is NOT on home tab
          if (controller.currentIndex.value != 0) {
            controller.handleBack(); // usually sets index = 0
            return;
          }

          // User is on home tab → show exit dialog
          final shouldExit = await _showExitDialog();
          if (shouldExit) {
            SystemNavigator.pop(); // exit app
          }
        },
        child: Obx(
          () => IndexedStack(
            index: controller.currentIndex.value,
            children: const [
              HomeScreen(),
              NotificationScreen(),
              Center(
                child: Text('Post', style: TextStyle(fontSize: 24, color: AppColors.black2F3039)),
              ),
              ZealsView(),
              MyProfileView(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(controller),
    );
  }

  Widget _buildBottomNavigationBar(DashboardController controller) {
    return Obx(() {
      final isZealsView = controller.currentIndex.value == 3;

      final bool hasUnreadNotifications;
      if (Get.isRegistered<NotificationController>()) {
        final notificationController = Get.find<NotificationController>();
        hasUnreadNotifications = notificationController.notifications.any(
          (n) => (n.status ?? '').toLowerCase() == 'unread',
        );
      } else {
        hasUnreadNotifications = false;
      }
      return Container(
        height: 70.h,
        decoration: BoxDecoration(color: isZealsView ? AppColors.black000000 : AppColors.whiteFFFFFF),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Assets.icons.icHome,
              activeIcon: Assets.icons.icHomeSelected,
              label: 'Home',
              index: 0,
              controller: controller,
              isDarkTheme: isZealsView,
            ),
            _buildNavItem(
              icon: Assets.icons.icNotification,
              activeIcon: Assets.icons.icNotificationSelected,
              label: 'Notify',
              index: 1,
              controller: controller,
              isDarkTheme: isZealsView,
              showUnreadBadge: hasUnreadNotifications,
            ),
            _buildNavItem(
              icon: Assets.icons.icPost,
              activeIcon: Assets.icons.icPost,
              label: 'Post',
              index: 2,
              controller: controller,
              isDarkTheme: isZealsView,
            ),
            _buildNavItem(
              icon: Assets.icons.icZeel,
              activeIcon: Assets.icons.icZeelSelected,
              label: 'Zeel',
              index: 3,
              controller: controller,
              isDarkTheme: isZealsView,
            ),
            _buildNavItem(
              icon: Assets.icons.icProfile,
              activeIcon: Assets.icons.icProfileSelected,
              label: 'Profile',
              index: 4,
              controller: controller,
              isDarkTheme: isZealsView,
            ),
          ],
        ),
      );
    });
  }

  Future<bool> _showExitDialog() async {
    return await Get.dialog<bool>(
          Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text('Exit App', style: TextStyles.medium(21.sp)),
                  ),
                  Gap(6.h),
                  Align(
                    alignment: Alignment.center,
                    child: Text('Are you sure you want to exit the app?', style: TextStyles.regular(16.sp)),
                  ),
                  Gap(18.h),
                  Row(
                    children: [
                      // Cancel button - remains normal gray CommonButton
                      Expanded(
                        child: CommonButtonWidget(
                          height: 44.h,
                          color: AppColors.gray8C9499,
                          borderRadius: 40,
                          onPressed: () => Get.back(result: false),
                          child: Center(
                            child: Text('Cancel', style: TextStyles.medium(16.sp, fontColor: AppColors.white)),
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
                                AppColors.greyE5E4DC, // #DA7000
                                AppColors.greyE5E4DC, // #984005
                              ],
                              stops: const [-0.0864, 0.798],
                              transform: GradientRotation((320.33 - 90) * math.pi / 180),
                            ),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Get.back(result: true),
                              borderRadius: BorderRadius.circular(40),
                              child: Center(
                                child: Text('Exit', style: TextStyles.medium(16.sp, fontColor: AppColors.black000000)),
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
        ) ??
        false;
  }

  Widget _buildNavItem({
    required SvgGenImage icon,
    required SvgGenImage activeIcon,
    required String label,
    required int index,
    required DashboardController controller,
    required bool isDarkTheme,
    bool showUnreadBadge = false,
  }) {
    final bool isActive = controller.currentIndex.value == index;

    // Determine colors based on theme
    final iconColor = isDarkTheme
        ? (isActive ? AppColors.white : AppColors.gray8C9499)
        : null; // null means use default icon color
    final textColor = isDarkTheme
        ? (isActive ? AppColors.white : AppColors.white)
        : (isActive ? AppColors.black2F3039 : AppColors.black2F3039);

    return PressScaleButton(
      onTap: () => controller.changeIndex(index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                (isActive ? activeIcon : icon).svg(
                  width: 20.sp,
                  height: 20.sp,
                  colorFilter: iconColor != null
                      ? ColorFilter.mode(iconColor, BlendMode.srcIn)
                      : null,
                ),
                if (showUnreadBadge)
                  Positioned(
                    top: -1.h,
                    right: -3.w,
                    child: Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          // Matches the “home message” style: red dot with light border.
                          color: isDarkTheme
                              ? AppColors.whiteFFFFFF
                              : AppColors.grayEDF1F4,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(label, style: TextStyles.semiBold(11.sp, fontColor: textColor)),
          ],
        ),
      ),
    );
  }
}
