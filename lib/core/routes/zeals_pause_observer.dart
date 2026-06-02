import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/presentation/main/zeals/controller/zeals_controller.dart';

/// Pauses Zeals videos when user navigates to another screen.
class ZealsPauseObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (Get.isRegistered<ZealsController>()) {
      Get.find<ZealsController>().requestPauseVideos();
    }
  }
}
