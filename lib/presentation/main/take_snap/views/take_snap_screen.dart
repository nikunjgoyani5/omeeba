import 'dart:io';

import 'package:camera/camera.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_loader.dart';
import 'package:omeeba_new/presentation/main/take_snap/controller/take_snap_controller.dart';

class TakeSnapScreen extends StatelessWidget {
  const TakeSnapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TakeSnapController controller = Get.put(TakeSnapController());

    return Scaffold(
      backgroundColor: AppColors.black000000,
      body: Obx(() {
        if (!controller.isInitialized.value) {
          return const Center(
            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
          );
        }

        return Stack(
          children: [
            // Camera preview or taken photo
            controller.showPhoto.value ? _buildPhotoView(controller) : _buildCameraView(controller),

            // Top bar with close button and title
            _buildTopBar(controller),

            // Bottom controls
            controller.showPhoto.value ? _buildPhotoControls(controller, context) : _buildCameraControls(controller),

            // Loading overlay for camera switching
            if (controller.isSwitchingCamera.value)
              Container(
                color: AppColors.black000000,
                child: const Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildCameraView(TakeSnapController controller) {
    return SizedBox.expand( // Ensures it takes the full screen
      child: FittedBox(
        fit: BoxFit.cover, // Crops the edges to fill the screen perfectly
        child: SizedBox(
          // Use the controller's preview size to maintain aspect ratio
          width: controller.cameraController.value.previewSize?.height ?? 1.0,
          height: controller.cameraController.value.previewSize?.width ?? 1.0,
          child: CameraPreview(controller.cameraController),
        ),
      ),
    );
  }

  Widget _buildPhotoView(TakeSnapController controller) {
    return SizedBox.expand(
      child: Image.file(File(controller.imagePath.value), fit: BoxFit.cover),
    );
  }

  Widget _buildTopBar(TakeSnapController controller) {
    return Positioned(
      top: 50.h,
      left: 10.w,
      right: 20.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          GestureDetector(
            onTap: controller.onCloseScreen,
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
              child: Icon(Icons.close, color: AppColors.white, size: 24.sp),
            ),
          ),

          // Title
          Text('Send a byte!', style: TextStyles.medium(18.sp, fontColor: AppColors.whiteFFFFFF)),
          Container(width: 40.w, height: 40.w, decoration: BoxDecoration()),
        ],
      ),
    );
  }

  Widget _buildCameraControls(TakeSnapController controller) {
    return Positioned(
      bottom: 40.h,
      left: 20.w,
      right: 20.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Empty space for symmetry
          SizedBox(width: 30.w),
          // Capture button
          GestureDetector(
            onTap: controller.takePicture,
            child: Container(
              width: 65.w,
              height: 65.w,
              decoration: BoxDecoration(color: AppColors.transparentColor, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Assets.icons.icCameraClick.svg()
            ),
          ),
          GestureDetector(
            onTap: controller.switchCamera,
            child: SizedBox(width: 30.w, height: 30.w, child: Assets.icons.icCameraFlip.svg(height: 30)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoControls(TakeSnapController controller, BuildContext context) {
    return Positioned(
      bottom: 40.h,
      right: 20.w,
      child: Obx(() {
        return GestureDetector(
          onTap: () async {
            await controller.uploadMediaAPI(context);
          },
          child: Container(
            width: 90.w,
            height: 38.h,
            decoration: BoxDecoration(color: AppColors.primaryColor, borderRadius: BorderRadius.circular(25.r)),
            child: Center(
              child: controller.uploadingSnap.value
                  ? CommonLoader(color: AppColors.white, size: 18)
                  : Text('Send', style: TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF)),
            ),
          ),
        );
      }),
    );
  }
}
