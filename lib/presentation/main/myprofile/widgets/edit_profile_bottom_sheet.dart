import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/presentation/main/myprofile/controller/my_profile_controller.dart';

class EditProfileBottomSheet extends StatefulWidget {
  final String initialName;
  final String initialUsername;
  final String initialBio;
  final bool isVerifiedBadge;
  final String? initialCoverImageUrl;
  final String? initialProfileImageUrl;

  const EditProfileBottomSheet({
    super.key,
    required this.initialName,
    required this.initialUsername,
    required this.initialBio,
    this.initialCoverImageUrl,
    this.initialProfileImageUrl, required this.isVerifiedBadge,
  });

  static void show({
    required String initialName,
    required String initialUsername,
    required String initialBio,
    required bool isVerifiedBadge,
    String? initialCoverImageUrl,
    String? initialProfileImageUrl,
  }) {
    Get.bottomSheet(
      EditProfileBottomSheet(
        initialName: initialName,
        initialUsername: initialUsername,
        initialBio: initialBio,
        initialCoverImageUrl: initialCoverImageUrl,
        initialProfileImageUrl: initialProfileImageUrl, isVerifiedBadge: isVerifiedBadge,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
    );
  }

  @override
  State<EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends State<EditProfileBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late final MyProfileController _controller;

  /// Whether the user explicitly removed the profile/cover (overrides the initial URL).
  bool _profileImageRemoved = false;
  bool _coverImageRemoved = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _bioController = TextEditingController(text: widget.initialBio);
    _controller = Get.find<MyProfileController>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ─── Change detection ─────────────────────────────────────────────────────

  bool get _hasChanges {
    if (_controller.selectedCoverImage.value != null) return true;
    if (_controller.selectedProfileImage.value != null) return true;
    if (_coverImageRemoved) return true;
    if (_profileImageRemoved) return true;
    if (_nameController.text.trim() != widget.initialName.trim()) return true;
    if (_usernameController.text.trim() != widget.initialUsername.trim()) return true;
    if (_bioController.text.trim() != widget.initialBio.trim()) return true;
    return false;
  }

  // ─── Image state helpers ──────────────────────────────────────────────────

  /// True when a cover should be displayed (file selected OR URL present and not removed).
  bool get _hasCover {
    final file = _controller.selectedCoverImage.value;
    if (file != null) return true;
    if (_coverImageRemoved) return false;
    final url = widget.initialCoverImageUrl;
    return url != null && url.toString().trim().isNotEmpty;
  }

  /// True when a profile image should be displayed (file selected OR URL present and not removed).
  bool get _hasProfileImage {
    final file = _controller.selectedProfileImage.value;
    if (file != null) return true;
    if (_profileImageRemoved) return false;
    final url = widget.initialProfileImageUrl;
    return url != null && url.toString().trim().isNotEmpty;
  }

  Future<void> _pickCoverImage() async {
    await _controller.pickCoverImage();
    // Only lift the "removed" flag when the user actually picks a new file.
    if (_controller.selectedCoverImage.value != null) {
      setState(() => _coverImageRemoved = false);
    }
  }

  void _removeCoverImage() {
    _controller.clearCoverImage();
    setState(() => _coverImageRemoved = true);
  }

  Future<void> _pickProfileImage() async {
    await _controller.pickProfileImage();
    // Only lift the "removed" flag when the user actually picks a new file.
    if (_controller.selectedProfileImage.value != null) {
      setState(() => _profileImageRemoved = false);
    }
  }

  void _removeProfileImage() {
    _controller.clearProfileImage();
    setState(() => _profileImageRemoved = true);
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _handleBack() {
    if (!_hasChanges) {
      _closeSheet();
      return;
    }
    _showDiscardDialog();
  }

  void _closeSheet() {
    _controller.clearCoverImage();
    _controller.clearProfileImage();
    Get.back();
  }

  Future<void> _showDiscardDialog() async {
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Discard changes?', style: TextStyles.bold(18.sp, fontColor: AppColors.black2F3039)),
              Gap(8.h),
              Text(
                'You have unsaved changes. Are you sure you want to leave?',
                style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070),
                textAlign: TextAlign.center,
              ),
              Gap(24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.gray8C9499.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text('Keep editing', style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text('Discard', style: TextStyles.medium(14.sp, fontColor: AppColors.whiteFFFFFF)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (discard == true) _closeSheet();
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  void _onUpdatePressed() {
    _controller.updateProfile(
      context: context,
      name: _nameController.text,
      username: _usernameController.text,
      bio: _bioController.text,
      removeCoverImage: _coverImageRemoved,
      removeProfileImage: _profileImageRemoved,
    );
  }

  // ─── Cover section ────────────────────────────────────────────────────────

  Widget _buildCoverSection(File? coverFile) {
    if (!_hasCover) {
      return GestureDetector(
        onTap: _pickCoverImage,
        child: Container(
          height: 150.h,
          width: double.infinity,
          decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(20.r)),
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.whiteFFFFFF,
                borderRadius: BorderRadius.circular(30.r),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/add_image.svg',
                    width: 20.w,
                    height: 20.w,
                    colorFilter: const ColorFilter.mode(AppColors.gray707070, BlendMode.srcIn),
                  ),
                  SizedBox(width: 8.w),
                  Text('Upload cover photo', style: TextStyles.medium(13.sp, fontColor: AppColors.gray707070)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Has cover: show image — tap image to change, delete button top-right to remove
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 150.h,
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20.r)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverFile != null)
                Image.file(coverFile, fit: BoxFit.cover)
              else
                CommonNetworkImage(imageUrl: widget.initialCoverImageUrl!.toString().trim(), fit: BoxFit.cover),
              Positioned(
                top: 10.h,
                right: 10.w,
                child: GestureDetector(
                  onTap: _removeCoverImage,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 34.w,
                    height: 34.w,
                    padding: EdgeInsets.all(8.w),
                    decoration: const BoxDecoration(color: AppColors.whiteFFFFFF, shape: BoxShape.circle),
                    child: Assets.icons.icDelete.svg(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Profile section ──────────────────────────────────────────────────────

  Widget _buildProfileSection(File? profileFile) {
    if (!_hasProfileImage) {
      return Stack(
        children: [
          GestureDetector(
            onTap: _pickProfileImage,
            child: Container(
              width: 100.w,
              height: 100.w,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.whiteFFFFFF, width: 4.w),
                color: AppColors.grayEDF1F4,
              ),
              child: SvgPicture.asset(
                'assets/icons/user_placeholder.svg',
                colorFilter: const ColorFilter.mode(AppColors.gray8C9499, BlendMode.srcIn),
              ),
            ),
          ),
          Positioned(
            bottom: 2.h,
            right: 2.w,
            child: GestureDetector(
              onTap: _pickProfileImage,
              child: Container(
                width: 28.w,
                height: 28.w,
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: AppColors.whiteFFFFFF,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.grayEDF1F4, width: 1.5),
                ),
                child: SvgPicture.asset(
                  'assets/icons/add_image.svg',
                  colorFilter: const ColorFilter.mode(AppColors.gray707070, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Has profile image: show image — tap to change, delete badge bottom-right
    return Stack(
      children: [
        GestureDetector(
          onTap: _pickProfileImage,
          child: Container(
            width: 100.w,
            height: 100.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.whiteFFFFFF, width: 4.w),
              color: AppColors.whiteFFFFFF,
            ),
            child: ClipOval(
              child: profileFile != null
                  ? Image.file(profileFile, fit: BoxFit.cover, width: 100.w, height: 100.w)
                  : CommonNetworkImage(
                      imageUrl: widget.initialProfileImageUrl!.toString().trim(),
                      fit: BoxFit.cover,
                      width: 100.w,
                      height: 100.w,
                    ),
            ),
          ),
        ),
        Positioned(
          bottom: 2.h,
          right: 2.w,
          child: GestureDetector(
            onTap: _removeProfileImage,
            child: Container(
              width: 30.w,
              height: 30.w,
              padding: EdgeInsets.all(7.w),
              decoration: BoxDecoration(
                color: AppColors.whiteFFFFFF,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.grayEDF1F4, width: 1.5),
              ),
              child: Assets.icons.icDelete.svg(),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85;
    final availableHeight = screenHeight - keyboardHeight;
    final containerHeight = keyboardHeight > 0 ? (availableHeight - 50.h).clamp(400.h, maxHeight) : maxHeight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Obx(() {
        final coverFile = _controller.selectedCoverImage.value;
        final profileFile = _controller.selectedProfileImage.value;
        final isUpdating = _controller.isUpdatingProfile.value;

        return Container(
          height: containerHeight + 18.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 15.h),
                child: Container(
                  height: containerHeight,
                  decoration: BoxDecoration(
                    color: AppColors.whiteFFFFFF,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: EdgeInsets.only(top: 8.h, bottom: 4.h),
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: AppColors.grayEDF1F4,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _handleBack,
                              child: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Edit Profile',
                                  style: TextStyles.bold(18.sp, fontColor: AppColors.black000000),
                                ),
                              ),
                            ),
                            SizedBox(width: 24.w),
                          ],
                        ),
                      ),
                      Gap(15),
                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 15.h, left: 15.w, right: 15.w),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Extends the Stack's hit-test area to 200.h so the
                                    // profile circle (bottom: 0, height 100) and its
                                    // delete badge (y ≈ 168–198) stay inside bounds.
                                    SizedBox(height: 200.h),
                                    _buildCoverSection(coverFile),
                                    Positioned(left: 20, bottom: 0, child: _buildProfileSection(profileFile)),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 10.h, left: 16.w, right: 16.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 250.w,
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              widget.initialName,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: TextStyles.bold(24.sp, fontColor: AppColors.black2F3039),
                                            ),
                                          ),
                                          Gap(3.w),
                                          if (widget.isVerifiedBadge == true) ...[
                                            Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                                            Gap(5.w),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Gap(8.h),
                                    Text(
                                      widget.initialBio,
                                      style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070),
                                    ),
                                    Gap(20.h),
                                    CommonTextField(
                                      labelText: 'Name',
                                      hintText: 'Name',
                                      controller: _nameController,
                                      textStyle: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                                      borderColor: AppColors.gray8C9499.withValues(alpha: 0.4),
                                    ),
                                    Gap(16.h),
                                    CommonTextField(
                                      readOnly: true,
                                      labelText: 'Username',
                                      onChanged: (value) {
                                        String name = _usernameController.text.trim();

                                        if (name.isEmpty) {
                                          _controller.emailError.value = "Name is required";
                                        } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(name)) {
                                          _controller.emailError.value =
                                              "Only letters, numbers and underscore (_) are allowed";
                                        } else {
                                          _controller.emailError.value = '';
                                        }
                                      },
                                      errorText: _controller.emailError.value,

                                      hintText: 'Username',
                                      controller: _usernameController,
                                      textStyle: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                                      borderColor: AppColors.gray8C9499.withValues(alpha: 0.4),
                                    ),
                                    Gap(16.h),
                                    CommonTextField(
                                      labelText: 'Add Bio (max. 100 chars)',
                                      hintText: 'Add Bio (max. 100 chars)',
                                      controller: _bioController,
                                      maxLength: 100,
                                      maxLines: 6,
                                      minLines: 3,
                                      textStyle: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039),
                                      borderColor: AppColors.gray8C9499.withValues(alpha: 0.4),
                                    ),
                                    Gap(32.h),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Update button
                      Padding(
                        padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 16.h, bottom: 16.h),
                        child: CommonButtonWidget(
                          width: double.infinity,
                          height: 50.h,
                          borderRadius: 12.r,
                          onPressed: _onUpdatePressed,
                          child: isUpdating
                              ? SizedBox(
                                  height: 22.h,
                                  width: 22.h,
                                  child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.whiteFFFFFF),
                                )
                              : Text('Update', style: TextStyles.bold(16.sp, fontColor: AppColors.whiteFFFFFF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
