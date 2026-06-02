import 'package:get/get.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/repository/post_repository.dart';
import 'package:omeeba_new/core/services/socket_service.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/presentation/main/create_post/models/users_model.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../../core/services/onesignal_notification_service.dart';
import '../../create_post/views/create_post_screen.dart';
import '../../myprofile/controller/my_profile_controller.dart';
import 'package:omeeba_new/presentation/main/create_post/controller/create_post_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/controller/zeals_controller.dart';
import 'package:omeeba_new/presentation/main/home/controller/home_controller.dart';
import '../../notification/controller/notification_controller.dart';

class DashboardController extends GetxController {

  final RxInt currentIndex = 0.obs;
  final RxInt lastIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();

    // Connect the socket once as soon as the dashboard is loaded.
    // Prefs are guaranteed written before navigation reaches here (auth_controller awaits them).
    // This is the single ownership point — chat screens must NOT call ensureConnected themselves.
    final userId = PrefService.getString(PrefKeys.userId);
    if (userId.isNotEmpty) {
      SocketService.instance.ensureConnected(userId);
    }

    getEligibleUserList();
    Get.put(CreatePostController());

    // Load notifications early so the bottom "Notify" badge is accurate
    // even before the user opens the Notifications tab.
    if (Get.isRegistered<NotificationController>()) {
      // ignore: unawaited_futures
      Get.find<NotificationController>().loadNotifications();
    }
  }
  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
    OneSignalNotificationService.handlePendingNotificationIfAny();
    DeepLinkService.handlePendingShareLinkIfAny();
  }

  void changeIndex(int index) {
    // Instagram-style behaviour: if user taps the Home tab while already
    // on Home, scroll the feed to top and trigger a refresh instead of
    // doing a no-op.
    if (index == 0 && currentIndex.value == 0) {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().handleHomeTabReselected();
      }
      return;
    }

    if(index!=currentIndex.value){
      if (index == 1) {
        currentIndex.value = 1;
        if (Get.isRegistered<NotificationController>()) {
          Get.find<NotificationController>().loadNotifications();
        }
        return;
      }
      if (index == 2) {
        if (Get.isRegistered<ZealsController>()) {
          Get.find<ZealsController>().requestPauseVideos();
        }
        Get.to(() => CreatePostScreen());
        return;
      }

      if (index != 3 && Get.isRegistered<ZealsController>()) {
        Get.find<ZealsController>().requestPauseVideos();
      }

      if (index == 3 && Get.isRegistered<ZealsController>()) {
        currentIndex.value = 3;
        Get.find<ZealsController>().refreshZeals();
      }

      if (index == 4) {
        currentIndex.value = 4;
        final profileController = Get.find<MyProfileController>();
        profileController.loadProfile();
        profileController.loadMyPosts(force: true);
      }
    }


    lastIndex.value = currentIndex.value;
    currentIndex.value = index;
  }

  void handleBack() {
    if (currentIndex.value != 0) {
      currentIndex.value =
          lastIndex.value != currentIndex.value ? lastIndex.value : 0;
    }
  }

  PostRepository postRepository = PostRepository();
  List<UserData> usersList = [];

  Future<void> getEligibleUserList() async {
    await postRepository.getEligibleUserList(
      onSuccess: (ApiResponse response) {
        UserSearchModel userSearchModel = UserSearchModel.fromJson(response.toJson());
        usersList = userSearchModel.data ?? [];
      },
      onError: (AppException error) {},
    );
  }
}
