import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gap/gap.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import 'package:omeeba_new/core/models/mention_user_model.dart';
import 'package:omeeba_new/presentation/main/create_post/controller/create_post_controller.dart';
import 'package:omeeba_new/presentation/main/myprofile/controller/my_profile_controller.dart';

class PostWriteScreen extends StatefulWidget {
  const PostWriteScreen({super.key});

  @override
  State<PostWriteScreen> createState() => _PostDataScreenState();
}

class _PostDataScreenState extends State<PostWriteScreen> {
  final CreatePostController controller = Get.put(CreatePostController());
  bool _wasKeyboardOpen = false;

  @override
  Widget build(BuildContext context) {
    // Listen to keyboard visibility using MediaQuery
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    // Update controller state when keyboard state changes
    if (_wasKeyboardOpen != isKeyboardOpen) {
      _wasKeyboardOpen = isKeyboardOpen;
      // Update controller state immediately
      controller.isKeyboardVisible.value = isKeyboardOpen;
      controller.isImageVisible.value = !isKeyboardOpen;
      if (!isKeyboardOpen) {
        controller.showMentionList.value = false;
      }
    }

    return Portal(
      child: Scaffold(
        backgroundColor: AppColors.whiteFFFFFF,
        appBar: _buildAppBar(),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 1, color: AppColors.grayEAEAEA),
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
              // Mention user list - shown below action buttons when mention button is tapped
              Obx(() {
                if (!controller.showMentionList.value) {
                  return const SizedBox.shrink();
                }
                return _buildMentionUserList();
              }),
              Gap(16.h),
              _buildSeparator(),

              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          // Row(
                          //   children: [
                          //     Text('jhjhdsf'),
                          //     Spacer(),
                          //     Switch(value: false, onChanged: (value) {}),
                          //   ],
                          // ),
                          // Gap(30),
                          // Row(
                          //   children: [
                          //     Text('jhjhdsf'),
                          //     Spacer(),
                          //     Switch(value: false, onChanged: (value) {}),
                          //   ],
                          // ),
                          // Gap(30),
                          // Row(
                          //   children: [
                          //     Text('jhjhdsf'),
                          //     Spacer(),
                          //     Switch(value: false, onChanged: (value) {}),
                          //   ],
                          // ),
                          // Gap(30),
                          // Row(
                          //   children: [
                          //     Text('jhjhdsf'),
                          //     Spacer(),
                          //     Switch(value: false, onChanged: (value) {}),
                          //   ],
                          // ),
                          // Gap(30),
                          // Row(
                          //   children: [
                          //     Text('jhjhdsf'),
                          //     Spacer(),
                          //     Switch(value: false, onChanged: (value) {}),
                          //   ],
                          // ),
                          // Gap(30),
                          // Row(
                          //   children: [
                          //     Text('jhjhdsf'),
                          //     Spacer(),
                          //     Switch(value: false, onChanged: (value) {}),
                          //   ],
                          // ),
                        ],
                      ),
                    ),

                    Container(
                      color: controller.isImageVisible.value
                          ? Colors.transparent
                          : Colors.black.withValues(alpha: 0.65),
                      height: Get.height,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.whiteFFFFFF,
      surfaceTintColor: AppColors.transparentColor,
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
      title: Text('Start Write', style: TextStyles.semiBold(18.sp)),
      leadingWidth: 40.w,
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 16.w),
          child: Builder(
            builder: (context) {
              final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
              final isKeyboardOpen = keyboardHeight > 0;
              return Obx(() {
                final _ = controller.characterCount.value; // triggers rebuild when caption changes
                final isCaptionEmpty = controller.captionController.text.trim().isEmpty;
                final isPostDisabled = !isKeyboardOpen && isCaptionEmpty;
                final isLoading = controller.isLoadingWritePost.value;
                return InkWell(
                  splashColor: AppColors.transparentColor,
                  highlightColor: AppColors.transparentColor,
                  onTap: isPostDisabled || isLoading
                      ? null
                      : () {
                          if (isKeyboardOpen) {
                            controller.captionFocusNode.unfocus();
                            FocusScope.of(context).unfocus();
                          } else {
                            controller.submitWritePost();
                          }
                        },
                  child: isKeyboardOpen
                      ? Text('OK', style: TextStyles.semiBold(16.sp, fontColor: AppColors.primaryColor))
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(51.r),
                            color: isPostDisabled || isLoading
                                ? AppColors.primaryColor.withValues(alpha: 0.5)
                                : AppColors.primaryColor,
                          ),
                          width: 65.w,
                          height: 29.h,
                          alignment: Alignment.center,
                          child: isLoading
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.h,
                                  child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.whiteFFFFFF),
                                )
                              : Text('Post', style: TextStyles.medium(16.sp, fontColor: AppColors.whiteFFFFFF)),
                        ),
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    final profileImageUrl =
        Get.find<MyProfileController>().profile.value?.profileImage ?? PrefService.getString(PrefKeys.userProfile);
    final username = Get.find<MyProfileController>().profile.value?.username ?? PrefService.getString(PrefKeys.userName);
    bool isVerifiedBeach = Get.find<MyProfileController>().profile.value?.isVerifiedBadge ?? PrefService.getBool(PrefKeys.isVerifiedBeach);
    final displayName = username.isNotEmpty ? '@$username' : 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Gap(20),
            CommonProfileImage(
              imageUrl: profileImageUrl,
              width: 60.w,
              height: 60.w,
              memCacheWidth: 120,
              memCacheHeight: null,
            ),
            Gap(8.h),
            Row(
              children: [
                Text(displayName, style: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039)),
                Gap(5.h),
                if (isVerifiedBeach == true) ...[
                  Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                ],
              ],
            ),
            Gap(20),
          ],
        ),
      ],
    );
  }

  Widget _buildCaptionSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMentionTextField(),
          Gap(4.h),

          // Mention text (orange) - show all mentions
          /*          // Obx(() {
          //   if (controller.mentionedUsers.isEmpty) {
          //     return const SizedBox.shrink();
          //   }
          //   return Wrap(
          //     spacing: 8.w,
          //     runSpacing: 8.h,
          //     children: controller.mentionedUsers.map((mention) {
          //       return Container(
          //         padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          //         decoration: BoxDecoration(
          //           color: AppColors.primaryColor.withValues(alpha: 0.1),
          //           borderRadius: BorderRadius.circular(8.r),
          //         ),
          //         child: Row(
          //           mainAxisSize: MainAxisSize.min,
          //           children: [
          //             Text(mention, style: TextStyles.semiBold(18.sp, fontColor: AppColors.primaryColor)),
          //             Gap(6.w),
          //             GestureDetector(
          //               onTap: () => controller.removeMention(mention),
          //               child: Icon(Icons.close, size: 16.sp, color: AppColors.primaryColor),
          //             ),
          //           ],
          //         ),
          //       );
          //     }).toList(),
          //   );
          // }),
          // Gap(8.h),*/
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
            label: 'Mention',
            onTap: () => controller.toggleMentionList(),
          ),
          Gap(12.w),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(4.r)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: AppColors.black2F3039),
            Gap(2.w),
            Text(label, style: TextStyles.medium(12.sp, fontColor: AppColors.black2F3039)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Divider(height: 1, thickness: 1, color: AppColors.greyDFDFDF);
  }

  Widget _buildMentionUserList() {
    return Hero(
      tag: 'mention_user_list',
      transitionOnUserGestures: true,
      child: Material(
        color: AppColors.whiteFFFFFF,
        child: Container(
          margin: EdgeInsets.only(top: 16.h),
          constraints: BoxConstraints(maxHeight: 300.h),
          decoration: BoxDecoration(
            color: AppColors.whiteFFFFFF,
            border: Border(top: BorderSide(color: AppColors.greyDFDFDF, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    padding: EdgeInsets.only(top: 20.h, bottom: 16.h),
                    physics: const ClampingScrollPhysics(),
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

  Widget _buildMentionTextField() {
    return TextField(
      controller: controller.captionController,
      focusNode: controller.captionFocusNode,
      maxLength: 1000,
      maxLines: 5,
      minLines: 2,
      style: TextStyles.medium(18.sp, fontColor: AppColors.black000000),
      decoration: InputDecoration(
        hintText: "What's the vibe !?",
        hintStyle: TextStyles.medium(18.sp, fontColor: AppColors.greyC4CACE),
        border: InputBorder.none,
        counterText: '',
        counterStyle: TextStyles.medium(13.sp, fontColor: AppColors.gray8C9499),
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (value) {
        controller.updateCharacterCount();
      },
      cursorColor: AppColors.black000000,
    );
  }

  Widget _buildUserListItem(MentionUser user) {
    return InkWell(
      onTap: () {
        controller.addMention(user);
        controller.updateCharacterCount();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            // Profile picture
            CommonProfileImage(imageUrl: user.profileImageUrl, width: 48.w, height: 48.w),
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
}
