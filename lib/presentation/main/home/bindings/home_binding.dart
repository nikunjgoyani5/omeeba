import 'package:get/get.dart';
import 'package:omeeba_new/core/data/home/home_feed_local.dart';
import 'package:omeeba_new/core/repository/home_repository.dart';

import '../controller/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<HomeFeedLocal>(HomeFeedLocal(), permanent: true);
    Get.put<HomeRepository>(HomeRepository(), permanent: true);
    Get.put(HomeController(), permanent: true);
  }
}

