import 'package:get/get.dart';
import 'package:omeeba_new/core/repository/content_repository.dart';
import '../controller/post_details_controller.dart';

class PostDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ContentRepository>(() => ContentRepository());
    Get.put(PostDataController());
  }
}

