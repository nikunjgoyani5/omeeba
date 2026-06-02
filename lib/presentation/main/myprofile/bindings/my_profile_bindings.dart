import 'package:get/get.dart';
import 'package:omeeba_new/core/repository/profile_repository.dart';

import '../controller/my_profile_controller.dart';

class MyProfileBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(ProfileRepository(), permanent: true);
    Get.put(MyProfileController(), permanent: true);
  }
}
