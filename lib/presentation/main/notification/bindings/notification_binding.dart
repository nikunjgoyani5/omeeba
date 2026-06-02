import 'package:get/get.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import '../controller/notification_controller.dart';

class NotificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(NotificationRepository(), permanent: true);
    Get.put(NotificationController(), permanent: true);
  }
}
