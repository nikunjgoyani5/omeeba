import 'package:get/get.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import '../../../../core/routes/app_routes.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _navigateToNext();
  }

  void _navigateToNext() {
    // Wait for 3 seconds then navigate to dashboard
    Future.delayed(const Duration(seconds: 3), () {
      PrefService.getString(PrefKeys.accessToken).isNotEmpty && PrefService.getBool(PrefKeys.isLogin)== true
?
      Get.offAllNamed(AppRoutes.dashboard): Get.offAllNamed(AppRoutes.login);
    });
  }
}
