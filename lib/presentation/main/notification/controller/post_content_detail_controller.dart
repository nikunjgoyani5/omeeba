import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/home_repository.dart';
import 'package:omeeba_new/core/repository/notification_repository.dart';
import 'package:omeeba_new/core/repository/post_repository.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';
import 'package:omeeba_new/presentation/main/zeals/views/zeal_detail_screen.dart';
import 'package:omeeba_new/presentation/main/zeals/widget/comments_bottom_sheet.dart';

import '../../../../core/models/api_response.dart';
import '../../home/controller/home_controller.dart';

/// Maps contentType (Post, Zeal, Write, Poll) to API contentType.
String contentTypeToApi(String notificationType) {
  switch (notificationType.toLowerCase()) {
    case 'zeal' || 'zeal post':
      return 'Zeal Post';
    case 'write' || 'write post':
      return 'Write Post';
    case 'poll':
      return 'Poll';
    case 'post':
    default:
      return 'Post';
  }
}

class PostContentDetailController extends GetxController {
  final NotificationRepository _repo = Get.find<NotificationRepository>();
  final PostRepository _postRepository = PostRepository();

  final Rx<PostData?> post = Rx<PostData?>(null);
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  String get contentId => _contentId;

  String get contentType => _contentType;

  String? get commentId => _commentId;

  late String _contentId;
  late String _contentType;
  String? _commentId;

  void setArgs({required String contentId, required String contentType, String? commentId}) {
    _contentId = contentId;
    _contentType = contentType;
    _commentId = commentId;
  }

  String get apiContentType => contentTypeToApi(_contentType);

  /// True when post was passed from list (e.g. my profile / home) — no API call.
  bool get hasInitialPost => _initialPost != null;

  /// When set (from list + Post type), used for Hero animation on the post image.
  String? get heroTagPrefix => _heroTagPrefix;

  PostData? _initialPost;
  String? _heroTagPrefix;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;
    if (args is Map) {
      final postArg = args['post'];
      if (postArg is PostData) {
        _initialPost = postArg;
        _contentId = postArg.id ?? '';
        _contentType = _contentTypeFromPost(postArg.contentType);
        _commentId = args['commentId']?.toString();
        _heroTagPrefix = args['heroTagPrefix']?.toString();
        post.value = postArg;
        isLoading.value = false;
        return;
      }
      _contentId = args['contentId']?.toString() ?? '';
      _contentType = args['contentType']?.toString() ?? 'Post';
      _commentId = args['commentId']?.toString();
    }
  }

  String _contentTypeFromPost(String? contentType) {
    if (contentType == null || contentType.isEmpty) return 'Post';
    final t = contentType.toLowerCase();
    if (t.contains('zeal')) return 'Zeal';
    if (t.contains('write')) return 'Write';
    if (t == 'poll') return 'Poll';
    return 'Post';
  }

  @override
  void onReady() {
    super.onReady();
    if (hasInitialPost) {
      final p = _initialPost!;
      final apiType = contentTypeToApi(_contentType);
      if (apiType == 'Zeal Post') {
        Get.off(() => ZealDetailScreen(), arguments: p);
        if (_commentId != null && _commentId!.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            CommentsBottomSheet.show(
              postId: p.id ?? _contentId,
              commentsCount: p.commentCount ?? 0,
              contentType: 'Zeal Post',
              highlightCommentId: _commentId,
              onCommentAdded: (newCount) {
                p.commentCount = newCount;
              },
            );
          });
        }
      }
      return;
    }
    fetchContent();
  }

  Future<void> fetchContent() async {
    if (_contentId.isEmpty) {
      errorMessage.value = 'Invalid content';
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    errorMessage.value = '';

    await _repo.fetchContentByTypeAndId(
      contentId: contentId,
      apiContentType: apiContentType,
      onSuccess: (data) {
        if (apiContentType == 'Zeal Post') {
          Get.off(() => ZealDetailScreen(), arguments: data);
          if (_commentId != null && _commentId!.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 500), () {
              CommentsBottomSheet.show(
                postId: data.id ?? _contentId,
                commentsCount: data.commentCount ?? 0,
                contentType: 'Zeal Post',
                highlightCommentId: _commentId,
                onCommentAdded: (newCount) {
                  data.commentCount = newCount;
                  update();
                },
              );
            });
          }
        } else {
          post.value = data;

        }
        isLoading.value = false;
      },
      onError: (AppException e) {
        errorMessage.value = e.message;
        isLoading.value = false;
      },
    );
  }

  @override
  void dispose() {
    post.close();
    isLoading.close();
    errorMessage.close();
    super.dispose();
  }

  /// Optimistic bookmark toggle: update UI instantly, then call save-post API. Revert on error.
  Future<void> saveUnSavePost(BuildContext context, PostData post) async {
    final previousSaved = post.isSaved ?? false;
    post.isSaved = !previousSaved;
    this.post.refresh();

    await _postRepository.savePost(
      data: {'contentType': apiContentType, 'contentId': post.id ?? _contentId},
      onSuccess: (ApiResponse response) {
      final controller = Get.find<HomeController>();

      controller.feedData.value = controller.feedData.value?..posts =
      controller.feedData.value!.posts!.map((e) {
        if (e.id == post.id) {
          e.isSaved = response.data["isSaved"];
        }
        return e;
      }).toList();
      controller.feedData.refresh();
    },
      onError: (AppException error) {
        post.isSaved = previousSaved;
        this.post.refresh();
        AppFunctions().showToast(error.message, bgColor: AppColors.red);
      },
    );
  }

  /// Call after voting on a poll to refresh the post.
  Future<void> submitPollVote(String optionId) async {
    final p = post.value;
    if (p?.id == null || optionId.isEmpty) return;
    final homeRepo = HomeRepository();
    homeRepo.submitPollVote(
      pollId: p!.id!,
      optionId: optionId,
      onSuccess: (updatedPost) {
        if (updatedPost != null) post.value = updatedPost;
      },
      onError: (_) {},
    );
  }
}
