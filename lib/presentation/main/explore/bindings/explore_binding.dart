import 'package:get/get.dart';

import 'package:omeeba_new/core/data/explore/explore_feed_local.dart';
import 'package:omeeba_new/core/repository/explore_repository.dart';

import '../controller/explore_controller.dart';
import '../controller/search_controller.dart';

class ExploreBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ExploreFeedLocal>(ExploreFeedLocal(), permanent: true);
    Get.put(ExploreRepository());
    Get.put(ExploreController());
    Get.put(ExploreSearchController());
  }
}
