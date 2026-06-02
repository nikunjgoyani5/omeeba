import 'package:get/get.dart';
import 'package:omeeba_new/core/repository/contact_repository.dart';
import 'package:omeeba_new/presentation/main/contact_us/controller/contact_us_controller.dart';

class ContactUsBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ContactRepository(), permanent: true);
    Get.put(ContactUsController());
  }
}
