import 'package:get/get.dart';
import 'package:omeeba_new/core/data/zeals/zeals_feed_local.dart';
import 'package:omeeba_new/core/repository/zeals_repository.dart';
import 'package:omeeba_new/core/services/network_quality_service.dart';
import 'package:omeeba_new/core/services/zeal_video_cache_service.dart';

import '../controller/zeals_controller.dart';

class ZealsBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ZealsFeedLocal>(ZealsFeedLocal(), permanent: true);
    Get.put<ZealsRepository>(ZealsRepository(), permanent: true);
    Get.put<ZealVideoCacheService>(ZealVideoCacheService(), permanent: true);
    Get.put<NetworkQualityService>(NetworkQualityService(), permanent: true);
    Get.put(ZealsController());
  }
}
