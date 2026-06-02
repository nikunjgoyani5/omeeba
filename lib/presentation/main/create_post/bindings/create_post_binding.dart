import 'package:get/get.dart';
import 'package:omeeba_new/core/repository/content_repository.dart';
import 'package:omeeba_new/core/repository/zeals_repository.dart';
import '../controller/create_post_controller.dart';

class CreatePostBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ContentRepository>(() => ContentRepository());
    Get.lazyPut<ZealsRepository>(() => ZealsRepository());
    Get.lazyPut(() => CreatePostController());
  }
}

