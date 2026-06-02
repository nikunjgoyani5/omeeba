import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/repository/chat_repository.dart';
import 'package:omeeba_new/core/services/socket_service.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_room_model.dart';
import 'package:omeeba_new/presentation/main/take_snap/views/send_to_bottom_sheet.dart';
import 'package:permission_handler/permission_handler.dart';

class TakeSnapController extends GetxController {
  late CameraController cameraController;
  List<CameraDescription> cameras = [];
  RxBool isInitialized = false.obs;
  RxBool isTakingPicture = false.obs;
  RxString imagePath = ''.obs;
  RxBool showPhoto = false.obs;
  RxInt currentCameraIndex = 0.obs;
  RxBool isSwitchingCamera = false.obs;

  final SocketService _socketService = SocketService.instance;
  StreamSubscription? _roomsSub;
  bool _sendSheetRequestedRooms = false;

  @override
  void onInit() {
    super.onInit();
    initializeCamera();
    _roomsSub = _socketService.onRoomsListStream.listen(_onRoomsListReceived);
  }

  void _onRoomsListReceived(dynamic data) {
    if (!_sendSheetRequestedRooms) return;
    _sendSheetRequestedRooms = false;

    loading.value = false;
    otherLoading.value = false;

    if (data != null && data['success'] == true) {
      final chatRoomModel = ChatRoomModel.fromJson(Map<String, dynamic>.from(data));
      if (page.value == 1) roomList.clear();
      roomList.addAll(chatRoomModel.data?.rooms ?? []);

      final pagination = chatRoomModel.pagination;
      final currentPage = pagination?.page ?? 1;
      final totalPages = pagination?.totalPages ?? 1;
      hasMoreRooms.value = currentPage < totalPages;
    }
  }

  @override
  void onClose() {
    _roomsSub?.cancel();
    cameraController.dispose();
    super.onClose();
  }

  Future<void> initializeCamera() async {
    try {
      // Request camera permissions
      await _requestCameraPermission();

      // Get available cameras
      cameras = await availableCameras();

      if (cameras.isNotEmpty) {
        // Initialize with rear camera (index 0) by default
        cameraController = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);

        await cameraController.initialize();
        isInitialized.value = true;
        update();
      }
    } catch (e) {
      print('Camera initialization error: $e');
      Get.snackbar('Error', 'Failed to initialize camera');
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      Get.snackbar('Permission Denied', 'Camera permission is required to take photos');
      Get.back();
    }
  }

  Future<void> takePicture() async {
    if (!isInitialized.value || isTakingPicture.value) return;

    try {
      isTakingPicture.value = true;

      final XFile picture = await cameraController.takePicture();
      imagePath.value = picture.path;
      showPhoto.value = true;
    } catch (e) {
      print('Error taking picture: $e');
      Get.snackbar('Error', 'Failed to take picture');
    } finally {
      isTakingPicture.value = false;
    }
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2 || isSwitchingCamera.value) return;

    try {
      isSwitchingCamera.value = true;
      isInitialized.value = false; // Set to false during switch

      await cameraController.dispose();

      // Switch to next camera
      currentCameraIndex.value = (currentCameraIndex.value + 1) % cameras.length;

      cameraController = CameraController(cameras[currentCameraIndex.value], ResolutionPreset.high, enableAudio: false);


      await cameraController.initialize();
      isInitialized.value = true;
      update();
    } catch (e) {
      print('Error switching camera: $e');
      Get.snackbar('Error', 'Failed to switch camera');
      // Try to reinitialize with the original camera
      await _reinitializeCamera();
    } finally {
      isSwitchingCamera.value = false;
    }
  }

  Future<void> _reinitializeCamera() async {
    try {
      isInitialized.value = false;
      await cameraController.dispose();

      cameraController = CameraController(cameras[currentCameraIndex.value], ResolutionPreset.high, enableAudio: false);

      await cameraController.initialize();
      isInitialized.value = true;
      update();
    } catch (e) {
      print('Error reinitializing camera: $e');
    }
  }

  void retakePhoto() {
    imagePath.value = '';
    showPhoto.value = false;
  }

  void onCloseScreen() {
    if (showPhoto.value == true) {
      retakePhoto();
    } else {
      Get.back();
    }
  }

  ChatRepository chatRepository = ChatRepository();
  RxBool loading = false.obs;
  RxBool otherLoading = false.obs;
  RxList<RoomData> roomList = <RoomData>[].obs;
  RxInt page = 1.obs;
  RxBool hasMoreRooms = true.obs;

  /// Same pattern as ChatController: fetch rooms via socket (getRooms). [reset] = first load.
  void fetchChatRoomList({bool reset = false}) {
    if (reset) {
      page.value = 1;
      roomList.clear();
      hasMoreRooms.value = true;
      loading.value = true;
      otherLoading.value = false;
    } else {
      if (otherLoading.value || !hasMoreRooms.value) return;
      otherLoading.value = true;
    }

    _sendSheetRequestedRooms = true;
    _socketService.getRooms(page: page.value, limit: 20, search: '');
  }

  void loadMoreChatRooms() {
    if (otherLoading.value || !hasMoreRooms.value || loading.value) return;
    page.value++;
    fetchChatRoomList(reset: false);
  }

  RxBool uploadingSnap = false.obs;

  Future<void> uploadMediaAPI(BuildContext context) async {
    uploadingSnap.value = true;
    await chatRepository.uploadMedia(
      image: File(imagePath.value),
      onSuccess: (ApiResponse response) {
        try {
          uploadingSnap.value = false;
          Get.bottomSheet(
            SendToBottomSheet(mediaId: response.data['mediaId']),
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
          );
        } catch (e) {
          debugPrint('error:::${e.toString()} ');
          uploadingSnap.value = false;
          AppFunctions().showToast('Something went wrong!!', bgColor: AppColors.red);
        }
      },
      onError: (AppException error) {
        uploadingSnap.value = false;
        String message = error.message;
        AppFunctions().showToast(message, bgColor: AppColors.red);
      },
    );
  }
}
