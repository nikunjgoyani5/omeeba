import 'package:get/get.dart';
import 'package:omeeba_new/presentation/main/home/bindings/home_binding.dart';
import 'package:omeeba_new/presentation/main/myprofile/bindings/my_profile_bindings.dart';
import 'package:omeeba_new/presentation/main/notification/bindings/notification_binding.dart';
import 'package:omeeba_new/presentation/main/zeals/bindings/zeals_bindings.dart';

import '../../report/bindings/report_binding.dart';
import '../controller/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    HomeBinding().dependencies();
    ZealsBinding().dependencies();
    ReportBinding().dependencies();
    MyProfileBindings().dependencies();
    NotificationBinding().dependencies();
    Get.put(DashboardController());
  }
}
