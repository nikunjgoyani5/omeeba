import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';
import 'package:omeeba_new/core/widgets/common_post_detail_widget.dart';
import 'package:omeeba_new/core/widgets/common_write_post_item.dart';
import 'package:omeeba_new/core/widgets/poll_card.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import 'package:omeeba_new/presentation/main/home/widgets/share_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/notification/controller/post_content_detail_controller.dart';
import 'package:omeeba_new/presentation/main/notification/widgets/poll_detail_shimmer.dart';
import 'package:omeeba_new/presentation/main/notification/widgets/post_detail_shimmer.dart';
import 'package:omeeba_new/presentation/main/notification/widgets/write_post_detail_shimmer.dart';
import 'package:omeeba_new/presentation/main/notification/widgets/zeal_detail_shimmer.dart';
import 'package:omeeba_new/presentation/main/report/controller/report_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/widget/zeals_shimmer.dart';
import 'package:omeeba_new/presentation/main/report/view/report_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/zeals/widget/comments_bottom_sheet.dart';

import '../../../../core/helper/like_helper.dart';

/// Screen for displaying post details (Post, Zeal, Write, Poll).
/// Can be opened with [arguments]: either [post] (from list) or [contentId] + [contentType] (from notification).
class PostContentDetailScreen extends StatelessWidget {
   PostContentDetailScreen({super.key});

  static String _titleForContentType(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'zeal' || 'zeal post':
        return 'Zeal';
      case 'write' || 'write post':
        return 'Write';
      case 'poll' || 'poll':
        return 'Poll';
      case 'post':
      default:
        return 'Post';
    }
  }

  static Widget _shimmerForContentType(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'zeal':
        return const ZealDetailShimmer();
      case 'write':
        return const WritePostDetailShimmer();
      case 'poll':
        return const PollDetailShimmer();
      case 'post':
      default:
        return const PostDetailShimmer();
    }
  }
   final controller = Get.find<PostContentDetailController>();


  @override
  Widget build(BuildContext context) {
    final isZeal = controller.contentType.toLowerCase() == 'zeal';

    return Obx(() {
      final isLoading = controller.isLoading.value;
      final post = controller.post.value;
      final hasError = controller.errorMessage.value.isNotEmpty;
      // Zeal: show black + shimmer from first frame until we navigate to ZealDetailScreen (we never set post for zeal on success)
      final isZealLoading = isZeal && (isLoading || (post == null && !hasError));

      // Zeal: black screen + ZealsShimmer from first frame (no white UI flash)
      if (isZealLoading) {
        return Scaffold(
          backgroundColor: AppColors.black000000,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ZealsShimmer(),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Get.back(),
                    icon: Assets.icons.icArrowBack.image(height: 24.h, width: 24.w, color: AppColors.whiteFFFFFF),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Non-zeal or zeal loaded: use white scaffold with app bar
      return Scaffold(
        backgroundColor: AppColors.whiteFFFFFF,
        appBar: AppBar(
          backgroundColor: AppColors.whiteFFFFFF,
          elevation: 0,
          title: Text(
            _titleForContentType(controller.contentType),
            style: TextStyles.semiBold(18.sp, fontColor: AppColors.black2F3039),
          ),
          leading: IconButton(
            icon: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
            onPressed: () => Get.back(),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
          ),
          leadingWidth: 56.w,
        ),
        body: _buildBody(context, controller),
      );
    });
  }

  Widget _buildBody(BuildContext context, PostContentDetailController controller) {
    if (controller.isLoading.value) {
      return _shimmerForContentType(controller.contentType);
    }
    if (controller.errorMessage.value.isNotEmpty) {
      return _ErrorView(message: controller.errorMessage.value, onRetry: controller.fetchContent);
    }
    final post = controller.post.value;
    if (post == null) {
      return const SizedBox.shrink();
    }
    final commentId = controller.commentId;
    final shouldOpenCommentSheet = commentId != null && commentId.isNotEmpty;

    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: _buildContentByType(context, controller, post),
    );

    if (shouldOpenCommentSheet) {
      return _OpenCommentSheetWhenReady(
        postId: post.id ?? controller.contentId,
        commentsCount: post.commentCount ?? 0,
        contentType: post.contentType ?? controller.contentType,
        highlightCommentId: commentId,
        child: content,
      );
    }
    return content;
  }

  Widget _buildContentByType(BuildContext context, PostContentDetailController controller, PostData post) {
    final contentType = post.contentType ?? controller.contentType;
    final apiType = contentTypeToApi(contentType.contains(' ') ? contentType : controller.contentType);

    // Write Post
    if (apiType == 'Write Post' || contentType == 'Write Post') {
      return CommonWritePostItem(
        postData: post,
        isLiked: post.isLiked ?? false,
        isBookmarked: post.isSaved ?? false,
        userId: post.userId,
        onBookmark: () {
          controller.saveUnSavePost(context, post);
        },
        onSave: () {
          controller.saveUnSavePost(context, post);
        },

        onReport: () {
          Get.find<ReportController>().reset();
          Get.find<ReportController>().getReportsCategories(context);
          ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Poll');
        },
        onComment: () => _openComments(controller, post),
        onDelete: () => Get.back(result: post.id),
        onShare: () {
          ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
        },
      );
    }

    // Poll
    if (apiType == 'Poll' || contentType == 'Poll') {
      return PollCard(
        postData: post,
        onReport: () {
          Get.find<ReportController>().reset();
          Get.find<ReportController>().getReportsCategories(context);
          ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Poll');
        },
        onBookmark: () {
          controller.saveUnSavePost(context, post);
        },
        onSave: () {
          controller.saveUnSavePost(context, post);
        },
        onCopyLink: () {
          Clipboard.setData(ClipboardData(text: post.shareableLink ?? "demo"));
        },
        onShare: () {
          ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
        },
        onLike: () {
          LikeHelper.toggleLike(
            contentId: post.id ?? '',
            contentType: post.contentType ?? 'Poll',
            isLiked: post.isLiked ?? false,
            likeCount: post.likeCount ?? 0,
            onLocalUpdate: (liked, count) {
              post.isLiked = liked;
              post.likeCount = count;
            },
          );
        },
        hasVoted: post.displayHasVoted,
        votedOptionId: post.displayVotedOptionId,
        isExpired: post.isPollExpired,
        onOptionTap: (optionId) => controller.submitPollVote(optionId),
        onComment: () => _openComments(controller, post),
        onDelete: () => Get.back(result: post.id),
      );
    }

    // Post (default) and any other type — use Hero for image when opened from list (contentType Post)
    final useHero =
        controller.hasInitialPost &&
        controller.contentType.toLowerCase() == 'post' &&
        (controller.heroTagPrefix?.isNotEmpty ?? false);
    return CommonPostDetailWidget(
      post: post,
      heroTagPrefix: useHero ? controller.heroTagPrefix : null,
      onComment: () => _openComments(controller, post),
      onBookmark: () {
        controller.saveUnSavePost(context, post);
      },
      onSave: () {
        controller.saveUnSavePost(context, post);
      },

      onLike: () {
        LikeHelper.toggleLike(
          contentId: post.id ?? '',
          contentType: post.contentType ?? 'Post',
          isLiked: post.isLiked ?? false,
          likeCount: post.likeCount ?? 0,
          onLocalUpdate: (liked, count) {
            post.isLiked = liked;
            post.likeCount = count;
          },
        );
      },
      onReport: () {
        Get.find<ReportController>().reset();
        Get.find<ReportController>().getReportsCategories(context);
        ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Post');
      },
      onDelete: () {
        Get.back(result: post.id);
      },
      onShare: () {
        ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
      },
    );
  }

  static void _openComments(PostContentDetailController controller, PostData post) {
    final commentId = controller.commentId;
    CommentsBottomSheet.show(
      postId: post.id ?? controller.contentId,
      commentsCount: post.commentCount ?? 0,
      contentType: post.contentType ?? controller.contentType,
      highlightCommentId: commentId,
      onCommentAdded: (newCount) {
        post.commentCount = newCount;
        // Force Obx to rebuild so CommonPostDetailWidget shows updated count instantly
        controller.post.refresh();
      },
    );
  }
}

/// Opens the comment bottom sheet once when built (e.g. when opening from a "Post Comment" notification).
class _OpenCommentSheetWhenReady extends StatefulWidget {
  final String postId;
  final int commentsCount;
  final String contentType;
  final String highlightCommentId;
  final Widget child;

  const _OpenCommentSheetWhenReady({
    required this.postId,
    required this.commentsCount,
    required this.contentType,
    required this.highlightCommentId,
    required this.child,
  });

  @override
  State<_OpenCommentSheetWhenReady> createState() => _OpenCommentSheetWhenReadyState();
}

class _OpenCommentSheetWhenReadyState extends State<_OpenCommentSheetWhenReady> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CommentsBottomSheet.show(
        postId: widget.postId,
        commentsCount: widget.commentsCount,
        contentType: widget.contentType,
        highlightCommentId: widget.highlightCommentId,
      );
    });
  }


  @override
  Widget build(BuildContext context) => widget.child;
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: onRetry,
              child: Text('Retry', style: TextStyles.medium(16.sp, fontColor: AppColors.primaryColor)),
            ),
          ],
        ),
      ),
    );
  }
}
