import 'dart:async';

import 'package:get/get.dart';

import 'package:omeeba_new/presentation/main/zeals/models/post_model.dart';



class ReelController extends GetxController {
  Rx<Post> reelData;
  bool isLikeLoading = false;
  bool isSavedLoading = false;


  Timer? _debounce;
  final Function(Post reelData) onUpdateReelData;

  ReelController(this.reelData, this.onUpdateReelData) {
    reelData.listen((p0) {

      onUpdateReelData(p0);
    });
  }

  @override
  void onClose() {
    super.onClose();
    reelData.close();
    _debounce?.cancel();
  }

  updateReelData({Post? reel, bool isIncreaseCoin = false}) {
    if (reel != null) {
      if (isIncreaseCoin) {
        reelData.update((val) => val?.increaseViews());
      } else {
        reelData.value = reel;
      }
    }
  }

  // void onLikeTap() {
  //   if (reelData.value.isLiked == false) {
  //     HapticManager.shared.light();
  //   }
  //   FocusManager.instance.primaryFocus?.unfocus();
  //   int reelId = reelData.value.id?.toInt() ?? -1;
  //
  //   if (reelId == -1) {
  //     return Loggers.error('Invalid Post id : $reelId');
  //   }
  //
  //   reelData.update((val) {
  //     val?.likeToggle(val.isLiked == true ? false : true);
  //   });
  //
  //   if (_debounce?.isActive ?? false) _debounce?.cancel();
  //   _debounce = Timer(const Duration(milliseconds: 700), () async {
  //     try {
  //       await (reelData.value.isLiked == true ? _likePostApi(reelId) : _disLikePostApi(reelId));
  //       // if (reelData.value.postType == PostType.video &&
  //       //     Get.isRegistered<PostScreenController>(tag: '$reelId')) {
  //       //   final controller = Get.find<PostScreenController>(tag: '$reelId');
  //       //   controller.₹₹1(reelData.value);
  //       // }
  //     } catch (e) {
  //       Loggers.error('ERROR IN LIKE  REEL $e');
  //     }
  //   });
  // }
  //
  // Future<void> _likePostApi(int id) async {
  //   StatusModel result = await PostService.instance.likePost(postId: id);
  //   if (result.status == true) {
  //     Post? reel = reelData.value;
  //     if (reel.user?.notifyPostLike == 1 && myUser?.id != reel.userId) {
  //       FirebaseNotificationManager.instance.sendLocalisationNotification(LKey.activityLikedPost,
  //           type: NotificationType.post,
  //           body: NotificationInfo(id: reel.id),
  //           deviceType: reel.user?.device ?? 0,
  //           deviceToken: reel.user?.deviceToken ?? '',
  //           languageCode: reel.user?.appLanguage);
  //     }
  //   }
  // }
  //
  // Future<void> _disLikePostApi(int id) async {
  //   await PostService.instance.disLikePost(postId: id);
  // }
  //
  // Future<void> onCommentTap({PostByIdData? postByIdData, bool isFromNotification = false}) async {
  //   FocusManager.instance.primaryFocus?.unfocus();
  //
  //   await Get.bottomSheet(
  //       CommentSheet(
  //         replyComment: postByIdData?.reply,
  //         comment: postByIdData?.comment,
  //         post: reelData.value,
  //         isFromNotification: isFromNotification,
  //       ),
  //       isScrollControlled: true,
  //       backgroundColor: Colors.transparent);
  // }
  //
  // void onSaved() {
  //   FocusManager.instance.primaryFocus?.unfocus();
  //   int reelId = reelData.value.id?.toInt() ?? -1;
  //   if (reelId == -1) {
  //     return Loggers.error('Invalid Post id : $reelId');
  //   }
  //
  //   if (isSavedLoading) {
  //     return Loggers.error('Is saved loading : $isSavedLoading');
  //   }
  //   isSavedLoading = true;
  //   HapticManager.shared.light();
  //   reelData.update((val) {
  //     val?.saveToggle(val.isSaved == true ? false : true);
  //   });
  //
  //   DebounceAction.shared.call(() async {
  //     if (reelData.value.id == null) {
  //       return Loggers.error('Reel value not found');
  //     }
  //     await ((reelData.value.isSaved ?? false) ? _savePostApi(reelId) : _unSavePostApi(reelId));
  //     isSavedLoading = false;
  //   });
  // }
  //
  // Future<void> _savePostApi(int id) async {
  //   StatusModel result = await PostService.instance.savePost(postId: id);
  //   if (result.status == true) {
  //     if (Get.isRegistered<SavedPostScreenController>()) {
  //       final controller = Get.find<SavedPostScreenController>();
  //       controller.unsavedIds.removeWhere((element) => element == id);
  //     }
  //   }
  // }
  //
  // Future<void> _unSavePostApi(int id) async {
  //   StatusModel result = await PostService.instance.unSavePost(postId: id);
  //   if (result.status == true) {
  //     if (Get.isRegistered<SavedPostScreenController>()) {
  //       final controller = Get.find<SavedPostScreenController>();
  //       controller.unsavedIds.add(id);
  //     }
  //   }
  // }
  //
  // void onShareTap() {
  //   FocusManager.instance.primaryFocus?.unfocus();
  //   ShareManager.shared.showCustomShareSheet(
  //     post: reelData.value,
  //     keys: ShareKeys.reel,
  //     onShareSuccess: () {
  //       reelData.update((val) => val?.increaseShares(1));
  //     },
  //   );
  // }
  //
  // void onGiftTap() {
  //   FocusManager.instance.primaryFocus?.unfocus();
  //   GiftManager.openGiftSheet(
  //     userId: reelData.value.userId ?? -1,
  //     onCompletion: (giftManager) {
  //       GiftManager.showAnimationDialog(giftManager.gift);
  //       GiftManager.sendNotification(reelData.value);
  //     },
  //   );
  // }
  //
  // void onAudioTap(Music? music) async {
  //   FocusManager.instance.primaryFocus?.unfocus();
  //
  //   await Get.bottomSheet(AudioSheet(music: music), isScrollControlled: true);
  // }
  //
  // void onUserTap(User? user) {
  //   if (reelData.value.id == -1) return;
  //   late ReelsScreenController reelsScreenController;
  //   if (Get.isRegistered<ReelsScreenController>(tag: ReelsScreenController.tag)) {
  //     reelsScreenController = Get.find<ReelsScreenController>(tag: ReelsScreenController.tag);
  //     reelsScreenController.isCurrentPageVisible = false;
  //   }
  //   NavigationService.shared.openProfileScreen(user, onUserUpdate: (user) async {
  //     final HomeScreenController homeScreenController;
  //     if (Get.isRegistered<HomeScreenController>()) {
  //       if (user?.isBlock == true) {
  //         homeScreenController = Get.find<HomeScreenController>();
  //         homeScreenController.onRefreshPage();
  //       }
  //     }
  //   }).then((value) {
  //     reelsScreenController.isCurrentPageVisible = true;
  //   });
  // }
  //
  // void notifyCommentSheet(PostByIdData? data) {
  //   if (data != null && (data.comment != null || data.reply != null)) {
  //     DebounceAction.shared.call(() {
  //       onCommentTap(postByIdData: data, isFromNotification: true);
  //     }, milliseconds: 1000);
  //   }
  // }
}
