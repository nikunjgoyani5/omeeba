import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:insta_assets_picker/insta_assets_picker.dart';

import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/video_preview_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/post/views/post_data_screen.dart';

/// Opens Instagram-style image picker (insta_assets_picker) with multiple aspect ratios.
/// On completion, navigates to [PostDataScreen] with selected (and cropped) image files.
class InstaImagePickerHelper {
  /// Max number of images user can select (Instagram-like).
  static const int maxAssets = 10;

  /// Square (1:1) aspect ratio.
  static const double ratioSquare = 1.0;

  /// Portrait 4:5 aspect ratio (Instagram style).
  static const double ratioPortrait = 4 / 5;

  /// Opens the picker for **Post images**.
  /// Multiple crop ratios are available in the crop view for all selected images.
  static Future<void> openPicker(BuildContext context) async {
    if (!context.mounted) return;

    InstaAssetPicker.pickAssets(
      context,
      maxAssets: maxAssets,
      filterOptions: AdvancedCustomFilter(),
      requestType: RequestType.image,
      pickerConfig: InstaAssetPickerConfig(
        title: 'New Post',
        cropDelegate: InstaAssetCropDelegate(
          cropRatios: [ratioSquare, ratioPortrait, 3 / 4, 4 / 3, 5 / 4, 16 / 9],
        ),
        pickerTheme: InstaAssetPicker.themeData(AppColors.primaryColor).copyWith(
          colorScheme: InstaAssetPicker.themeData(
            AppColors.primaryColor,
          ).colorScheme.copyWith(primary: AppColors.primaryColor),
        ),
      ),
      onCompleted: (Stream<InstaAssetsExportDetails> stream) {
        InstaAssetsExportDetails? lastDetails;
        stream.listen(
          (InstaAssetsExportDetails details) {
            lastDetails = details;
          },
          onDone: () async {
            if (lastDetails == null) return;
            final files = <File>[];
            // Prefer cropped files from export when user chose a ratio
            if (lastDetails!.data.isNotEmpty) {
              for (final item in lastDetails!.data) {
                final cropped = item.croppedFile;
                if (cropped != null && cropped.existsSync()) {
                  files.add(cropped);
                }
              }
            }
            if (files.isEmpty && lastDetails!.selectedAssets.isNotEmpty) {
              for (final asset in lastDetails!.selectedAssets) {
                if (asset.type != AssetType.image) continue;
                final file = await asset.file;
                if (file != null) files.add(file);
              }
            }
            if (files.isEmpty) return;
            if (!context.mounted) return;
            Get.to(() => PostDataScreen(type: 'post', postImages: files));
          },
        );
      },
    );
  }

  /// Opens the picker for **Zeal video upload**.
  ///
  /// - Shows only videos (`RequestType.video`).
  /// - Single selection (`maxAssets: 1`).
  /// - On completion opens `VideoPreviewBottomSheet` with the selected video.
  static Future<void> openZealVideoPicker(BuildContext context) async {
    if (!context.mounted) return;

    InstaAssetPicker.pickAssets(
      context,
      maxAssets: 1,
      requestType: RequestType.video,
      pickerConfig: InstaAssetPickerConfig(
        title: 'New Zeal',
        // Force vertical 9:16 layout for Zeal videos (Reels-style).
        cropDelegate: InstaAssetCropDelegate(cropRatios: [9 / 16]),
        pickerTheme: InstaAssetPicker.themeData(AppColors.primaryColor).copyWith(
          colorScheme: InstaAssetPicker.themeData(
            AppColors.primaryColor,
          ).colorScheme.copyWith(primary: AppColors.primaryColor),
        ),
      ),

      onCompleted: (Stream<InstaAssetsExportDetails> stream) {
        InstaAssetsExportDetails? lastDetails;
        stream.listen(
          (InstaAssetsExportDetails details) {
            lastDetails = details;
          },
          onDone: () async {
            if (lastDetails == null) return;
            if (lastDetails!.selectedAssets.isEmpty) return;

            final asset = lastDetails!.selectedAssets.firstWhere(
              (a) => a.type == AssetType.video,
              orElse: () => lastDetails!.selectedAssets.first,
            );

            File? file;
            file ??= await asset.file;
            if (file == null || !file.existsSync()) return;

            if (!context.mounted) return;
            if (!file.existsSync()) return;

            VideoPreviewBottomSheet.show(videoAsset: asset, videoFile: file, isRecordedVideo: false);
          },
        );
      },
    );
  }
}
