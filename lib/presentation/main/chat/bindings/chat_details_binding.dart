import 'package:get/get.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import 'package:omeeba_new/presentation/main/chat/controller/chat_details_controller.dart';

import '../../notification/controller/post_content_detail_controller.dart';

class ChatDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatDetailsController());
  }
}

class PostContentDetailBinding extends Bindings {
  @override
  void dependencies() {
    // Deep links / cold start can open this route before [DashboardBinding] runs.
    if (!Get.isRegistered<NotificationRepository>()) {
      Get.put(NotificationRepository(), permanent: true);
    }
    Get.lazyPut(() => PostContentDetailController());
  }
}