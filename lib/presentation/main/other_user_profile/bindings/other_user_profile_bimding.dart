import 'package:get/get.dart';

import '../controller/other_user_profile_controller.dart';

class OtherUserProfileBinding extends Bindings {
  String _extractUserId(dynamic args) {
    if (args is String) return args;
    if (args is Map) return args['userId']?.toString() ?? '';
    return '';
  }

  @override
  void dependencies() {
    final userId = _extractUserId(Get.arguments);
    final tag = 'other_user_profile_$userId';
    if (!Get.isRegistered<OtherUserProfileController>(tag: tag)) {
      Get.put(OtherUserProfileController(), tag: tag);
    }
  }
}
