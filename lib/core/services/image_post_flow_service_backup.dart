// BACKUP: Image crop flow (image_cropper). Not used – image selection is now via insta_assets_picker.
//
// To restore cropping:
// 1. Add to pubspec.yaml: image_cropper: ^11.0.0
// 2. Add to AndroidManifest.xml inside <application>:
//    <activity android:name="com.yalantis.ucrop.UCropActivity"
//             android:screenOrientation="portrait"
//             android:theme="@style/Theme.AppCompat.Light.NoActionBar" />
// 3. Create lib/core/services/image_post_flow_service.dart with a class that:
//    - Uses ImageCropper().cropImage(sourcePath, maxWidth: 1080, maxHeight: 1920, ...)
//    - Has AndroidUiSettings/IOSUiSettings with aspectRatioPresets: original, square
//    - Copies cropped result to temp dir and returns File
//    - processImageList(context, sourceFiles) crops each and returns List<File>
// 4. In gallery_bottom_sheet.dart (when used for images): import the service and
//    replace the "Next" image branch with: processImageList -> PostDataScreen(postImages: editedFiles)
// 5. In create_post_screen.dart: change image gallery onTap back to GalleryBottomSheet.show()
