// BACKUP: Original gallery bottom sheet used photo_manager + ImagePostFlowService (image_cropper).
// Image selection is now via insta_assets_picker (InstaImagePickerHelper) from create_post_screen.
//
// To restore old flow:
// 1. Copy image_post_flow_service_backup.dart to core/services/image_post_flow_service.dart
// 2. Add image_cropper back to pubspec.yaml and UCropActivity to AndroidManifest
// 3. In gallery_bottom_sheet.dart restore the import and the crop flow in the "Next" handler
// 4. In create_post_screen.dart change the image gallery onTap back to GalleryBottomSheet.show()
