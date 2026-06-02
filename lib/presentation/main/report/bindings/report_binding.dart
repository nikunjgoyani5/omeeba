import 'package:get/get.dart';
import 'package:omeeba_new/presentation/main/report/controller/report_controller.dart';

import '../../../../core/repository/report_repository.dart';

class ReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ReportRepository>(ReportRepository(), permanent: true);
    Get.put(ReportController());
  }
}
