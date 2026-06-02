import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/models/mention_user_model.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';
import 'package:omeeba_new/core/widgets/common_loader.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import 'package:omeeba_new/presentation/main/create_post/controller/create_post_controller.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/download_processing_bottom_sheet.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import '../controller/post_details_controller.dart';

class PostDataScreen extends StatefulWidget {
  const PostDataScreen({
    super.key,
    required this.type,
    this.videoThumbnail,
    this.videoFilePath,
    this.postImages,
  });

  final String type;
  final String? videoThumbnail;
  final String? videoFilePath;
  final List<File>? postImages;

  @override
  State<PostDataScreen> createState() => _PostDataScreenState();
}

class _PostDataScreenState extends State<PostDataScreen> {
  final PostDataController controller = Get.put(PostDataController());
  bool _wasKeyboardOpen = false;
  ScrollController scrollController = ScrollController();
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'Zeal' && Get.isRegistered<CreatePostController>()) {
      final createPostCtrl = Get.find<CreatePostController>();
      final music =
          createPostCtrl.confirmedMusic ?? createPostCtrl.selectedMusic;
      if (music != null && (music.downloadedURL ?? '').isNotEmpty) {
        controller.selectedSong.value =
            createPostCtrl.musicTitle ?? 'Music added';
      }

      _controller = VideoPlayerController.file(File(widget.videoFilePath ?? ""))
        ..initialize().then((_) {
          setState(() => _isInitialized = true);
          _controller.seekTo(Duration.zero);
        });
      _controller.setLooping(true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        double itemWidth = Get.width * 0.45 + 12.w;
        int centerIndex = widget.postImages!.length ~/ 2;

        scrollController.jumpTo(centerIndex * itemWidth);

        // 👈 center
      }
    });
  }

  void _togglePlay() {
    if (!_isInitialized) return;

    if (_controller.value.isPlaying) {
      _controller.pause();
      _isPlaying = false;
    } else {
      _controller.play();
      _isPlaying = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    if (widget.type == 'Zeal' && _isInitialized) {
      // _controller.pause();
      _controller.dispose();
    }

    super.dispose();
  }

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 1.h, color: AppColors.grayEAEAEA),
                // Image section - hidden when typing
                Obx(
                  () => AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: controller.isImageVisible.value
                        ? widget.type == 'post'
                              ? _buildImageSection()
                              : buildZealSection()
                        : const SizedBox.shrink(),
                  ),
                ),
                _buildCaptionSection(),
                Gap(12.h),
                widget.type != 'Zeal'
                    ? _buildActionButtons()
                    : const SizedBox.shrink(),
                // Mention user list - shown below action buttons when mention button is tapped
                widget.type != 'Zeal'
                    ? Obx(() {
                        if (!controller.showMentionList.value) {
                          return const SizedBox.shrink();
                        }
                        return _buildMentionUserList();
                      })
                    : const SizedBox.shrink(),
                Gap(12.h),
                _buildSeparator(),
              ],
            ),
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
          splashColor: AppColors.transparentColor,
          highlightColor: AppColors.transparentColor,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Get.back(),
        ),
      ),
      leadingWidth: 40.w,
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 16.w),
          child: Builder(
            builder: (context) {
              final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
              final isKeyboardOpen = keyboardHeight > 0;
              return Obx(() {
                return InkWell(
                  splashColor: AppColors.transparentColor,
                  highlightColor: AppColors.transparentColor,
                  onTap: isKeyboardOpen
                      ? () {
                          controller.captionFocusNode.unfocus();
                          FocusScope.of(context).unfocus();
                        }
                      : () async {
                          if (widget.type == 'post') {
                            controller.createPostLoader.value
                                ? null
                                : await controller.createPostAPI(
                                    context,
                                    widget.postImages ?? [],
                                  );
                          } else {
                            _onPostZeal(context);
                          }
                        },
                  child: isKeyboardOpen
                      ? Text(
                          'OK',
                          style: TextStyles.semiBold(
                            16.sp,
                            fontColor: AppColors.primaryColor,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(51.r),
                            color: AppColors.primaryColor,
                          ),
                          width: 65.w,
                          height: 29.h,
                          alignment: Alignment.center,
                          child: controller.createPostLoader.value
                              ? CommonLoader(size: 15, color: AppColors.white)
                              : Text(
                                  'Post',
                                  style: TextStyles.medium(
                                    16.sp,
                                    fontColor: AppColors.whiteFFFFFF,
                                  ),
                                ),
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
    return SizedBox(
      // width: Get.width * 0.45,
      height: 260.h,
      child: ReorderableListView.builder(
        scrollController: scrollController,

        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        itemCount: widget.postImages?.length ?? 0,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }

          final item = widget.postImages?.removeAt(oldIndex);
          widget.postImages?.insert(newIndex, item ?? File(''));

          controller.update(); // if using GetX
        },
        itemBuilder: (context, index) {
          final image = widget.postImages?[index];

          return Container(
            key: ValueKey(image),
            // IMPORTANT for reorder
            width: Get.width * 0.45,
            margin: EdgeInsets.only(left: 12.w, right: 12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              color: AppColors.grayEDF1F4,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: Image.file(
                    widget.postImages?[index] ?? File(''),
                    fit: BoxFit.cover,
                  ),
                ),

                /// Counter
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.black000000.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      "${index + 1}/${widget.postImages?.length}",
                      style: TextStyles.medium(
                        13.sp,
                        fontColor: AppColors.whiteFFFFFF,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget _buildImageSection() {
  //   return Align(
  //     alignment: Alignment.center,
  //     child: Container(
  //       width: Get.width * 0.45,
  //       height: 200.h,
  //       margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
  //       decoration: BoxDecoration(borderRadius: BorderRadius.circular(20.r), color: AppColors.grayEDF1F4),
  //       child: Stack(
  //         fit: StackFit.expand,
  //         children: [
  //           // Placeholder image - replace with actual image
  //           ClipRRect(
  //             borderRadius: BorderRadius.circular(20.r),
  //             child: Assets.images.imgOne.image(fit: BoxFit.cover, width: Get.width * 0.5, height: double.infinity),
  //           ),
  //           // Image counter overlay
  //           Positioned(
  //             top: 12.h,
  //             right: 12.w,
  //             child: Container(
  //               padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
  //               decoration: BoxDecoration(
  //                 color: AppColors.black000000.withValues(alpha: 0.4),
  //                 borderRadius: BorderRadius.circular(20.r),
  //               ),
  //               child: Text('1/9+', style: TextStyles.medium(13.sp, fontColor: AppColors.whiteFFFFFF)),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget buildZealSection() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: Get.width * 0.60,
        height: 300.h,
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: AppColors.grayEDF1F4,
          border: Border.all(width: 1.w, color: AppColors.grayEDF1F4),
        ),
        clipBehavior: Clip.hardEdge, // IMPORTANT for rounded corners
        child: !_isInitialized
            ? Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.r),
                    color: Colors.white,
                  ),
                ),
              )
            : GestureDetector(
                onTap: _togglePlay,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover, // fills completely
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),

                    if (!_isPlaying)
                      Container(
                        width: 45.w,
                        height: 45.h,
                        decoration: BoxDecoration(
                          color: AppColors.black000000.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: AppColors.white,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  final GlobalKey<FlutterMentionsState> mentionKey =
      GlobalKey<FlutterMentionsState>();

  void _onPostZeal(BuildContext context) {
    controller.uploadZealVideo(
      videoFilePath: widget.videoFilePath,
      onUploadStarted: (progress) {
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (_) => DownloadProcessingBottomSheet(
            progress: progress,
            title: 'Uploading...',
            subtitle: 'Please wait while your zeal is being uploaded',
            thumbnail: widget.videoThumbnail,
          ),
        );
      },
      onUploadComplete: () {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  Widget buildThumbnail() {
    if (widget.videoThumbnail?.isEmpty ?? false) return const SizedBox();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(widget.videoThumbnail ?? ''),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image),
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
          TextField(
            controller: controller.captionController,
            focusNode: controller.captionFocusNode,
            maxLength: 1000,
            maxLines: 5,
            minLines: 2,
            style: TextStyles.medium(18.sp, fontColor: AppColors.black000000),
            decoration: InputDecoration(
              hintText: "What's the vibe !?",
              hintStyle: TextStyles.medium(
                18.sp,
                fontColor: AppColors.greyC4CACE,
              ),
              border: InputBorder.none,
              counterText: '',
              counterStyle: TextStyles.medium(
                13.sp,
                fontColor: AppColors.gray8C9499,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              controller.updateCharacterCount();
            },
            cursorColor: AppColors.black000000,
          ),
          // TextField(
          //   controller: controller.captionController,
          //   focusNode: controller.captionFocusNode,
          //   maxLength: 280,
          //   maxLines: 5,
          //   minLines: 2,
          //   style: TextStyles.medium(18.sp, fontColor: AppColors.black000000),
          //   decoration: InputDecoration(
          //     hintText: "What's the vibe !?",
          //     hintStyle: TextStyles.medium(18.sp, fontColor: AppColors.greyC4CACE),
          //     border: InputBorder.none,
          //     counterText: '',
          //     counterStyle: TextStyles.medium(13.sp, fontColor: AppColors.gray8C9499),
          //     contentPadding: EdgeInsets.zero,
          //   ),
          // ),
          Gap(4.h),
          // FlutterMentions(
          //   key: mentionKey,
          //   focusNode: controller.captionFocusNode,
          //   maxLength: 280,
          //   maxLines: 5,
          //   minLines: 2,
          //   decoration: InputDecoration(
          //     hintText: "What's the vibe !?",
          //     hintStyle: TextStyles.medium(18.sp, fontColor: AppColors.greyC4CACE),
          //     border: InputBorder.none,
          //     counterText: '',
          //     counterStyle: TextStyles.medium(12.sp, fontColor: AppColors.gray8C9499),
          //     contentPadding: EdgeInsets.zero,
          //   ),
          //   onChanged: (value) {
          //     // Sync with controller and update character count
          //     controller.captionController.text = value;
          //     controller.updateCharacterCount();
          //   },
          //   onMentionAdd: (Map<String, dynamic> mention) {
          //     // Handle when a suggestion is tapped/selected from FlutterMentions dropdown
          //     final mentionText = '@${mention['display']}';
          //     if (!controller.mentionedUsers.contains(mentionText)) {
          //       controller.mentionedUsers.add(mentionText);
          //     }
          //     print('Mention added from dropdown: ${mention['id']} - ${mention['display']}');
          //   },
          //   style: TextStyles.medium(18.sp, fontColor: AppColors.black000000),
          //
          //   mentions: [
          //     Mention(
          //
          //       // suggestionBuilder: (val) {
          //       //   return Padding(
          //       //     padding: const EdgeInsets.only(top: 10.0),
          //       //     child: Text('jh'),
          //       //   );
          //       // },
          //     trigger: '@',
          //       style: TextStyle(
          //         color: AppColors.primaryColor, // Orange color for mentioned users
          //         fontWeight: FontWeight.bold,
          //       ),
          //       data: controller.availableUsers.map((user) {
          //         return {
          //           'id': user.id,
          //           'display': user.username,
          //           'fullName': user.fullName,
          //         };
          //       }).toList(),
          //     ),
          //   ],
          // ),
          // Gap(4.h),

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
                style: TextStyles.regular(
                  12.sp,
                  fontColor: AppColors.gray707070,
                ),
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
          // Gap(12.w),
          // // Music button
          // Obx(() {
          //   if (controller.selectedSong.value.isEmpty) {
          //     return InkWell(
          //       onTap: () {
          //         SearchMusicBottomSheet.show(
          //           onMusicSelect: (audioUrl) async {
          //             await Get.bottomSheet(
          //               SelectedMusicSheet(selectedMusic: SelectedMusic(0, audioUrl, 0), totalVideoSecond: 15),
          //               enableDrag: false,
          //               isScrollControlled: true,
          //             );
          //           },
          //         );
          //       },
          //       child: Container(
          //         padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
          //         decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(4.r)),
          //         child: Row(
          //           mainAxisSize: MainAxisSize.min,
          //           children: [
          //             Assets.icons.icSong.svg(),
          //             Gap(6.w),
          //             Text('Song', style: TextStyles.medium(12.sp, fontColor: AppColors.black2F3039)),
          //           ],
          //         ),
          //       ),
          //     );
          //   } else {
          //     return _buildMusicButton();
          //   }
          // }),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.grayEDF1F4,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: AppColors.black2F3039),
            Gap(6.w),
            Text(
              label,
              style: TextStyles.medium(12.sp, fontColor: AppColors.black2F3039),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicButton() {
    return Obx(
      () => InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.grayEDF1F4,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Assets.icons.icMusicPlay.svg(),
              Gap(6.w),
              Text(
                controller.selectedSong.value,
                style: TextStyles.medium(
                  14.sp,
                  fontColor: AppColors.gray707070,
                ),
              ),
              Gap(8.w),
              InkWell(
                onTap: () => controller.removeSong(),
                child: Icon(
                  Icons.close,
                  size: 16.sp,
                  color: AppColors.gray707070,
                ),
              ),
            ],
          ),
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
            border: Border(
              top: BorderSide(color: AppColors.greyDFDFDF, width: 1),
            ),
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
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
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
                          style: TextStyles.regular(
                            14.sp,
                            fontColor: AppColors.gray707070,
                          ),
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
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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
      onTap: () {
        controller.addMention(user);
        // Insert mention into FlutterMentions using the state
        final mentionState = mentionKey.currentState;
        if (mentionState != null) {
          // Get current text and cursor position from FlutterMentions
          final currentText = mentionState.controller?.text ?? '';
          final cursorPos =
              mentionState.controller?.selection.baseOffset ??
              currentText.length;
          final textBefore = currentText.substring(0, cursorPos);
          final textAfter = currentText.substring(cursorPos);

          // Find @ position
          final atIndex = textBefore.lastIndexOf('@');
          if (atIndex >= 0) {
            final beforeAt = textBefore.substring(0, atIndex);
            final newText = '$beforeAt@${user.username} $textAfter';
            mentionState.controller?.text = newText;
            mentionState.controller?.selection = TextSelection.fromPosition(
              TextPosition(
                offset: beforeAt.length + 1 + user.username.length + 1,
              ),
            );
          } else {
            // Append at end if no @ found
            final newText = currentText.isEmpty
                ? '@${user.username} '
                : '$currentText @${user.username} ';
            mentionState.controller?.text = newText;
            mentionState.controller?.selection = TextSelection.fromPosition(
              TextPosition(offset: newText.length),
            );
          }
        }
      },
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
                  Text(
                    user.fullName,
                    style: TextStyles.bold(
                      16.sp,
                      fontColor: AppColors.black000000,
                    ),
                  ),
                  Gap(4.h),
                  Text(
                    '@${user.username}',
                    style: TextStyles.regular(
                      14.sp,
                      fontColor: AppColors.gray707070,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
