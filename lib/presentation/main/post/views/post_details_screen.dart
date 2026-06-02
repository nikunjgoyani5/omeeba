import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gap/gap.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';
import 'package:omeeba_new/core/models/mention_user_model.dart';
import 'package:omeeba_new/core/widgets/common_button.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import '../controller/post_details_controller.dart';

class PostDetailsScreen extends GetView<PostDataController> {
  const PostDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteFFFFFF,
      appBar: _buildAppBar(),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image section - hidden when typing
                    Obx(
                      () => AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: controller.isImageVisible.value ? _buildImageSection() : const SizedBox.shrink(),
                      ),
                    ),
                    _buildCaptionSection(),
                    Gap(16.h),
                    _buildActionButtons(),
                    Gap(16.h),
                    _buildSeparator(),
                  ],
                ),
              ),
            ),
            // Mention user list - shown when keyboard is open or mention button is tapped
            Obx(() {
              if (!controller.showMentionList.value) {
                return const SizedBox.shrink();
              }
              final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: keyboardHeight > 0 ? (300.h).clamp(200.h, 400.h) : 300.h,
                child: _buildMentionUserList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.whiteFFFFFF,
      elevation: 0,
      leading: Padding(
        padding: EdgeInsets.only(left: 16.w),
        child: IconButton(
          icon: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Get.back(),
        ),
      ),
      leadingWidth: 40.w,
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 16.w),
          child: CommonButton(
            text: 'Post',
            // onPressed: controller.post,
            width: 80.w,
            height: 36.h,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            borderRadius: 8.r,
            textStyle: TextStyles.medium(14.sp, fontColor: AppColors.whiteFFFFFF),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Hero(
      tag: 'post_image',
      child: Container(
        width: double.infinity,
        height: 350.h,
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16.r), color: AppColors.grayEDF1F4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Assets.images.bannerPlaceholder.image(fit: BoxFit.cover, width: double.infinity, height: double.infinity),
            ),
            Positioned(
              top: 12.h,
              right: 12.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.black000000.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text('1/9+', style: TextStyles.medium(12.sp, fontColor: AppColors.whiteFFFFFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main caption text (bold, large)
          TextField(
            controller: controller.captionController,
            focusNode: controller.captionFocusNode,
            maxLength: controller.maxCharacters,
            maxLines: null,
            minLines: 2,
            style: TextStyles.bold(18.sp, fontColor: AppColors.black000000),
            decoration: InputDecoration(
              hintText: 'Write a caption...',
              hintStyle: TextStyles.bold(18.sp, fontColor: AppColors.gray707070),
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                controller.isImageVisible.value = false;
              }
            },
          ),
          Gap(4.h),
          // Mentioned users display
          Obx(() {
            if (controller.mentionedUsers.isEmpty) {
              return const SizedBox.shrink();
            }
            return Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: controller.mentionedUsers
                  .asMap()
                  .entries
                  .map((entry) {
                final int index = entry.key;
                final String mention = entry.value;

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$index - $mention", // now you can use index
                        style: TextStyles.medium(
                          14.sp,
                          fontColor: AppColors.primaryColor,
                        ),
                      ),
                      Gap(6.w),
                      GestureDetector(
                        onTap: () => controller.removeMention(mention, index),
                        child: Icon(
                          Icons.close,
                          size: 16.sp,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );

          }),
          Gap(8.h),
          // Character count in bottom right
          Align(
            alignment: Alignment.centerRight,
            child: Obx(
              () => Text(
                '${controller.characterCount.value}/${controller.maxCharacters}',
                style: TextStyles.regular(12.sp, fontColor: AppColors.gray707070),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          // @ Mention button
          _buildActionButton(
            icon: Icons.alternate_email,
            label: '@ Mention',
            onTap: () => controller.toggleMentionList(),
          ),
          Gap(12.w),
          // Music button
          Obx(() {
            if (controller.selectedSong.value.isEmpty) {
              return _buildActionButton(
                icon: Icons.music_note,
                label: 'Add Music',
                onTap: () {
                  // Handle add music action
                },
              );
            } else {
              return _buildMusicButton();
            }
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(8.r)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18.sp, color: AppColors.gray707070),
            Gap(6.w),
            Text(label, style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070)),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicButton() {
    return Obx(
      () => InkWell(
        onTap: () {
          // Handle music button tap
        },
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(8.r)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note, size: 18.sp, color: AppColors.gray707070),
              Gap(6.w),
              Text(controller.selectedSong.value, style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070)),
              Gap(8.w),
              InkWell(
                onTap: () => controller.removeSong(),
                child: Icon(Icons.close, size: 16.sp, color: AppColors.gray707070),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMentionUserList() {
    return Hero(
      tag: 'mention_user_list',
      transitionOnUserGestures: true,
      child: Material(
        color: AppColors.whiteFFFFFF,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.whiteFFFFFF,
            boxShadow: [
              BoxShadow(
                color: AppColors.black000000.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with OK button
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.greyDFDFDF, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mention', style: TextStyles.semiBold(16.sp, fontColor: AppColors.black000000)),
                    TextButton(
                      onPressed: () {
                        controller.showMentionList.value = false;
                        controller.captionFocusNode.unfocus();
                      },
                      child: Text('OK', style: TextStyles.medium(16.sp, fontColor: AppColors.primaryColor)),
                    ),
                  ],
                ),
              ),
              // User list (search API + pagination)
              Flexible(
                child: Obx(() {
                  final isLoading = controller.isLoadingMentionSearch.value;
                  final filteredUsers = controller.getFilteredUsers();
                  final loadMore = controller.isLoadingMoreMentionUsers.value;
                  if (isLoading && filteredUsers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.h),
                        child: SizedBox(
                          width: 24.w,
                          height: 24.h,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  if (filteredUsers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.h),
                        child: Text(
                          controller.mentionSearchQuery.value.isEmpty
                              ? 'Type after @ to search users'
                              : 'No users found',
                          style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: controller.mentionListScrollController,
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: filteredUsers.length + (loadMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= filteredUsers.length) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Center(
                            child: SizedBox(
                              width: 24.w,
                              height: 24.h,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final user = filteredUsers[index];
                      return _buildUserListItem(user);
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserListItem(MentionUser user) {
    return InkWell(
      onTap: () => controller.addMention(user),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            // Profile picture
            CommonProfileImage(
              imageUrl: user.profileImageUrl,
              width: 48.w,
              height: 48.w,
            ),
            Gap(12.w),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: TextStyles.bold(16.sp, fontColor: AppColors.black000000)),
                  Gap(4.h),
                  Text('@${user.username}', style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Divider(height: 1, thickness: 1, color: AppColors.greyDFDFDF);
  }
}
