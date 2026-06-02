import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/models/comment_get_model.dart' hide Pagination;
import 'package:omeeba_new/core/models/mention_user_model.dart';
import 'package:omeeba_new/core/repository/post_repository.dart';
import 'package:omeeba_new/core/repository/profile_repository.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/core/widgets/mention_text_controller.dart';
import 'package:omeeba_new/presentation/main/report/view/report_bottom_sheet.dart';
import 'package:shimmer/shimmer.dart';
import '../../report/controller/report_controller.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final int commentsCount;
  final String contentType;

  /// When set, the sheet scrolls to this comment after the first page loads.
  final String? highlightCommentId;

  /// Called when a new comment (or reply) is added; [newCount] is the updated total.
  final void Function(int newCount)? onCommentAdded;
  final void Function(int newCount)? onCommentRemove;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.commentsCount,
    required this.contentType,
    this.highlightCommentId,
    this.onCommentAdded,
    this.onCommentRemove,
  });

  static void show({
    required String postId,
    required int commentsCount,
    required String contentType,
    String? highlightCommentId,
    void Function(int newCount)? onCommentAdded,
    void Function(int newCount)? onCommentRemove,
  }) {
    Get.bottomSheet(
      CommentsBottomSheet(
        postId: postId,
        commentsCount: commentsCount,
        contentType: contentType,
        highlightCommentId: highlightCommentId,
        onCommentAdded: onCommentAdded,
        onCommentRemove: onCommentRemove,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> with TickerProviderStateMixin {
  late final MentionTextController _commentController;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  /// Tracks total comment count for onCommentAdded callback (initial + new comments/replies).
  int _currentCommentCount = 0;

  // Reply state (Instagram-style: mention user in field)
  CommentData? replyingToComment;
  int? replyingToIndex;

  /// When non-null, user is replying to this reply (reply-to-reply).
  ReplyData? replyingToReply;

  // @ Mention state (user list + different color for @tags)
  bool _showMentionList = false;
  String _mentionSearchQuery = '';
  int _mentionStartPosition = -1;
  final List<MentionUser> _mentionSearchResults = [];
  final List<MentionUser> _selectedMentionUsers = [];
  bool _isLoadingMentionSearch = false;
  static const int _mentionSearchLimit = 10;
  static const int _mentionSearchDebounceMs = 500;
  Timer? _mentionSearchDebounce;
  String _lastScheduledQuery = '';
  String _lastSearchedQuery = '';
  final ProfileRepository _profileRepository = ProfileRepository();

  // Long press state (comment)
  String? _selectedCommentId;
  Widget? selectedComment;

  // Long press state (reply) — UI only, delete API abhi nahi hai
  int? _selectedReplyCommentIndex;
  int? _selectedReplyIndex;
  Widget? selectedReplyWidget;

  final Map<String, GlobalKey> _commentKeys = {};
  final Map<String, GlobalKey> _replyKeys = {};
  final GlobalKey _bottomSheetKey = GlobalKey();

  GlobalKey _getReplyKey(String commentId, int replyIndex) {
    final k = '${commentId}_$replyIndex';
    _replyKeys[k] ??= GlobalKey();
    return _replyKeys[k]!;
  }

  late AnimationController _highlightAnimationController;
  late AnimationController _menuAnimationController;
  late Animation<double> _highlightAnimation;
  late Animation<double> _highlightScaleAnimation;
  late Animation<double> _highlightOpacityAnimation;
  late Animation<double> _menuScaleAnimation;
  late Animation<double> _menuOpacityAnimation;
  late Animation<double> _blurAnimation;

  List<MentionUser> get _knownUsersForStyling {
    final ids = <String>{};
    final result = <MentionUser>[];
    for (final u in _selectedMentionUsers) {
      if (ids.add(u.id)) result.add(u);
    }
    for (final u in _mentionSearchResults) {
      if (ids.add(u.id)) result.add(u);
    }
    return result;
  }

  @override
  void dispose() {
    _mentionSearchDebounce?.cancel();
    _commentController.removeListener(_onCommentTextChanged);
    _commentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _highlightAnimationController.dispose();
    _menuAnimationController.dispose();
    super.dispose();
  }

  void _onCommentTextChanged() {
    final text = _commentController.text;
    if (text.isEmpty) {
      setState(() {
        _showMentionList = false;
        replyingToComment = null;
      });
      return;
    }
    final cursorPosition = _commentController.selection.baseOffset.clamp(0, text.length);

    int lastAtIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        lastAtIndex = i;
        break;
      } else if (text[i] == ' ' || text[i] == '\n') {
        break;
      }
    }

    if (lastAtIndex != -1) {
      final searchQuery = text.substring(lastAtIndex + 1, cursorPosition).trim();
      setState(() {
        _mentionStartPosition = lastAtIndex;
        _mentionSearchQuery = searchQuery;
        _showMentionList = true;
      });
      _scheduleMentionSearch();
    } else {
      _mentionSearchDebounce?.cancel();
      _lastScheduledQuery = '';
      _lastSearchedQuery = '';
      setState(() {
        _showMentionList = false;
        _mentionSearchQuery = '';
        _mentionStartPosition = -1;
      });
    }
  }

  void _scheduleMentionSearch() {
    final q = _mentionSearchQuery.trim();
    if (q == _lastScheduledQuery) return;
    if (q == _lastSearchedQuery) return;
    _lastScheduledQuery = q;

    _mentionSearchDebounce?.cancel();
    _mentionSearchDebounce = Timer(const Duration(milliseconds: _mentionSearchDebounceMs), () {
      final currentQ = _mentionSearchQuery.trim();
      _lastScheduledQuery = '';
      if (currentQ.isEmpty) {
        _lastSearchedQuery = '';
        setState(() {
          _mentionSearchResults.clear();
          _showMentionList = false;
        });
        _commentController.refreshStyling();
        return;
      }
      if (_isLoadingMentionSearch) return;
      _lastSearchedQuery = currentQ;
      _searchMentionUsers(query: currentQ);
    });
  }

  void _searchMentionUsers({required String query}) {
    if (query.isEmpty) {
      setState(() => _mentionSearchResults.clear());
      return;
    }
    setState(() => _isLoadingMentionSearch = true);
    _profileRepository.searchUsers(
      query: query,
      page: 1,
      limit: _mentionSearchLimit,
      onSuccess: (users, hasNext) {
        if (mounted) {
          setState(() {
            _mentionSearchResults.clear();
            _mentionSearchResults.addAll(users);
            _isLoadingMentionSearch = false;
          });
          _commentController.refreshStyling();
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isLoadingMentionSearch = false);
      },
    );
  }

  void _addMention(MentionUser user) {
    if (!_selectedMentionUsers.any((u) => u.id == user.id)) {
      _selectedMentionUsers.add(user);
    }
    if (!_mentionSearchResults.any((u) => u.id == user.id)) {
      _mentionSearchResults.insert(0, user);
    }
    _commentController.refreshStyling();

    final mention = '@${user.username} ';
    if (_mentionStartPosition >= 0) {
      final currentText = _commentController.text;
      final cursorPosition = _commentController.selection.baseOffset;
      final textBefore = currentText.substring(0, _mentionStartPosition);
      final textAfter = currentText.substring(cursorPosition);
      final newText = '$textBefore@${user.username} $textAfter';
      final newCursorPosition = _mentionStartPosition + mention.length;

      _commentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _commentController.text == newText) {
          _commentController.selection = TextSelection.collapsed(offset: newCursorPosition);
        }
      });
    } else {
      final currentText = _commentController.text;
      final newText = currentText.isEmpty ? mention : '$currentText $mention';
      _commentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }

    setState(() {
      _showMentionList = false;
      _mentionSearchQuery = '';
      _mentionStartPosition = -1;
    });
  }

  void _onCommentLongPress(String commentId) {
    setState(() {
      _selectedReplyCommentIndex = null;
      _selectedReplyIndex = null;
      selectedReplyWidget = null;
      _selectedCommentId = commentId;
    });
    _highlightAnimationController.forward();
    _menuAnimationController.forward();
  }

  void _dismissSelection() {
    _highlightAnimationController.reverse();
    _menuAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _selectedCommentId = null;
          selectedComment = null;
        });
      }
    });
  }

  void _onReplyLongPress(int commentIndex, int replyIndex) {
    final comment = commentList[commentIndex];
    final reply = comment.replies?[replyIndex];
    if (reply == null) return;
    //    if (reply == null || reply.user?.id != PrefService.getString(PrefKeys.userId)) return;

    _getReplyKey(comment.id ?? '', replyIndex);

    selectedReplyWidget = _buildReplyRowClone(comment, reply, replyIndex);
    setState(() {
      _selectedCommentId = null;
      selectedComment = null;
      _selectedReplyCommentIndex = commentIndex;
      _selectedReplyIndex = replyIndex;
    });
    _highlightAnimationController.forward();
    _menuAnimationController.forward();
  }

  void _dismissReplySelection() {
    _highlightAnimationController.reverse();
    _menuAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _selectedReplyCommentIndex = null;
          _selectedReplyIndex = null;
          selectedReplyWidget = null;
        });
      }
    });
  }

  /// Builds reply text with @mentions in primary color; tap opens user profile.
  Widget _buildReplyTextWithMentions(ReplyData reply, double fontSize) {
    final text = reply.reply ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    final baseStyle = TextStyles.regular(fontSize, fontColor: AppColors.black2F3039);
    final mentionStyle = TextStyles.regular(fontSize, fontColor: AppColors.primaryColor);
    final mentionedUsers = reply.mentionedUsers ?? [];
    final List<InlineSpan> spans = [];
    final mentionRegex = RegExp(r'@(\w+)');
    int lastIndex = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: baseStyle));
      }

      final username = match.group(1) ?? '';
      User? matchedUser;
      for (final u in mentionedUsers) {
        if (u.username == username) {
          matchedUser = u;
          break;
        }
      }

      if (matchedUser != null && matchedUser.id != null && matchedUser.id!.isNotEmpty) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: mentionStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => Get.toNamed(AppRoutes.otherUserProfile, arguments: matchedUser!.id),
          ),
        );
      } else {
        spans.add(TextSpan(text: match.group(0), style: baseStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  /// Clone of a single reply row for overlay highlight (same look as in list).
  Widget _buildReplyRowClone(CommentData comment, ReplyData reply, int replyIndex) {
    return Container(
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12.r)),
      padding: EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.grayEDF1F4),
            child: ClipOval(
              child: CommonNetworkImage(
                imageUrl: reply.user?.profileImage ?? "",
                fit: BoxFit.cover,
                placeholder: Icon(Icons.person, color: AppColors.grey898989, size: 18),
                errorWidget: Icon(Icons.person, color: AppColors.grey898989, size: 18),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.user?.username ?? "",
                      style: TextStyles.semiBold(13.sp, fontColor: AppColors.black2F3039),
                    ),
                    SizedBox(width: 6.w),
                    Text(reply.timeAgo ?? "", style: TextStyles.regular(12.sp, fontColor: AppColors.gray8C9499)),
                  ],
                ),
                SizedBox(height: 4.h),
                _buildReplyTextWithMentions(reply, 14.sp),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      "${reply.likeCount ?? 0} likes",
                      style: TextStyles.regular(11.sp, fontColor: AppColors.gray8C9499),
                    ),
                    SizedBox(width: 12.w),
                    Text("Reply", style: TextStyles.regular(11.sp, fontColor: AppColors.gray8C9499)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLike(CommentData comment) {
    setState(() {
      comment.isLiked = !(comment.isLiked ?? false);
      // if (comment.isLiked?? false) {
      //  ( comment.likeCount??0) ++;
      // } else {
      //   comment.likesCount--;
      // }
    });
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  int pageNumber = 1;
  RxBool loader = false.obs;
  RxBool isLastLoading = false.obs;
  List<CommentData> commentList = [];
  CommentGetModel commentGetModel = CommentGetModel();
  Pagination pagination = Pagination();

  loadMoreNewsData() {
    isLastLoading.value = true;
    pageNumber++;
    fetchComments();
  }

  PostRepository postRepository = PostRepository();

  Future<void> fetchComments() async {
    try {
      loader.value = isLastLoading.value == true ? false : true;
      await postRepository.getComments(
        queryParam: {"page": pageNumber.toString(), "contentId": widget.postId, "contentType": widget.contentType},

        onSuccess: (ApiResponse response) {
          try {
            pagination = response.pagination ?? Pagination();
            commentGetModel = CommentGetModel.fromJson(response.toJson());
            commentList = commentList + (commentGetModel.data ?? []);
            loader.value = false;
            isLastLoading.value = false;
            setState(() {});
            // Scroll to the highlighted comment on first load
            if (pageNumber == 1) _scrollToHighlightedComment();
          } catch (e) {
            commentList = commentList;
            loader.value = false;
            isLastLoading.value = false;
            setState(() {});
          }
        },
        onError: (AppException error) {
          commentList = commentList;
          loader.value = false;
          isLastLoading.value = false;
          setState(() {});
        },
      );
    } catch (error) {
      commentList = commentList;
      loader.value = false;
      isLastLoading.value = false;
      debugPrint('News Error ${error.toString()}');
    }
  }

  RxBool isPosting = false.obs;

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  /// Scroll to the comment whose id matches [widget.highlightCommentId].
  /// Uses the GlobalKey stored in [_commentKeys] after the list rebuilds.
  void _scrollToHighlightedComment() {
    final id = widget.highlightCommentId;
    if (id == null || id.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _commentKeys[id];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.2,
        );
      }
    });
  }

  Future<void> postComment(String commentText) async {
    try {
      commentList[0].isPosting = true;
      setState(() {});
      _scrollToTop();

      await postRepository.createComment(
        data: {"comment": commentText, "contentId": widget.postId, "contentType": widget.contentType},

        onSuccess: (ApiResponse response) {
          try {
            CommentData commentData = CommentData.fromJson(response.data['comment']);
            _commentController.clear();
            commentList[0].isPosting = false;
            commentList[0] = commentData;
            _currentCommentCount++;
            setState(() {});
            widget.onCommentAdded?.call(_currentCommentCount);
          } catch (e) {
            commentList[0].isPosting = false;
            commentList.removeAt(0);
            setState(() {});
          }
        },
        onError: (AppException error) {
          commentList[0].isPosting = false;
          AppFunctions.showCustomToast(context, message: error.message, isSuccess: false);
          commentList.removeAt(0);

          setState(() {});
        },
      );
    } catch (error) {
      commentList[0].isPosting = false;
      commentList.removeAt(0);
      setState(() {});
    } finally {
      FocusScope.of(context).unfocus();
    }
  }

  // Future<void> postComment() async {
  //   try {
  //     await postRepository.createComment(
  //       data: {"comment": _commentController.text, "contentId": widget.postId, "contentType": widget.contentType},
  //
  //       onSuccess: (ApiResponse response) {
  //         try {
  //           _commentController.clear();
  //           setState(() {});
  //         } catch (e) {
  //           commentList.removeAt(commentList.length - 1);
  //           setState(() {});
  //         }
  //       },
  //       onError: (AppException error) {
  //         commentList.removeAt(commentList.length - 1);
  //         setState(() {});
  //       },
  //     );
  //   } catch (error) {
  //     commentList.removeAt(commentList.length - 1);
  //     setState(() {});
  //     debugPrint('News Error ${error.toString()}');
  //   }
  // }

  Future<void> likeUnlikeComment(String commentId, int index) async {
    try {
      await postRepository.likeUnlikeComment(
        id: commentId,

        onSuccess: (ApiResponse response) {
          try {} catch (e) {
            if (commentList[index].isLiked ?? false) {
              commentList[index].isLiked = false;
              commentList[index].likeCount = (commentList[index].likeCount ?? 0) - 1;
            } else {
              commentList[index].isLiked = true;
              commentList[index].likeCount = (commentList[index].likeCount ?? 0) + 1;
            }
            setState(() {});
          }
        },
        onError: (AppException error) {
          if (commentList[index].isLiked ?? false) {
            commentList[index].isLiked = false;
            commentList[index].likeCount = (commentList[index].likeCount ?? 0) - 1;
          } else {
            commentList[index].isLiked = true;
            commentList[index].likeCount = (commentList[index].likeCount ?? 0) + 1;
          }
          setState(() {});
        },
      );
    } catch (error) {
      if (commentList[index].isLiked ?? false) {
        commentList[index].isLiked = false;
        commentList[index].likeCount = (commentList[index].likeCount ?? 0) - 1;
      } else {
        commentList[index].isLiked = true;
        commentList[index].likeCount = (commentList[index].likeCount ?? 0) + 1;
      }
      setState(() {});
      debugPrint('like unlike error ${error.toString()}');
    }
  }

  Future<void> deleteComment(String commentId, int index, CommentData commentData) async {
    try {
      await postRepository.deleteComment(
        id: commentId,

        onSuccess: (ApiResponse response) {
          final removedDelta = 1 + (commentData.replyCount ?? 0);
          final updated = _currentCommentCount - removedDelta;
          _currentCommentCount = updated < 0 ? 0 : updated;
          widget.onCommentAdded?.call(_currentCommentCount);
        },
        onError: (AppException error) {
          commentList.insert(index, commentData);
          setState(() {});
        },
      );
    } catch (error) {
      commentList.insert(index, commentData);
      setState(() {});
      debugPrint('delete error ${error.toString()}');
    }
  }

  void _onReplyToComment(CommentData comment, int index) {
    final user = comment.user;
    if (user != null && user.username != null && user.username!.isNotEmpty) {
      final mentionUser = MentionUser(
        id: user.id ?? '',
        fullName: user.name ?? '',
        username: user.username ?? '',
        profileImageUrl: user.profileImage ?? '',
      );
      if (!_selectedMentionUsers.any((u) => u.id == mentionUser.id)) {
        _selectedMentionUsers.add(mentionUser);
      }
      _commentController.refreshStyling();
    }
    setState(() {
      replyingToComment = comment;
      replyingToIndex = index;
      replyingToReply = null;
      _commentController.text = '@${comment.user?.username ?? ''} ';
      _commentController.selection = TextSelection.collapsed(offset: _commentController.text.length);
    });
    // ensure keyboard focus after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onReplyToReply(CommentData comment, int commentIndex, ReplyData reply) {
    final user = reply.user;
    if (user != null && user.username != null && user.username!.isNotEmpty) {
      final mentionUser = MentionUser(
        id: user.id ?? '',
        fullName: user.name ?? '',
        username: user.username ?? '',
        profileImageUrl: user.profileImage ?? '',
      );
      if (!_selectedMentionUsers.any((u) => u.id == mentionUser.id)) {
        _selectedMentionUsers.add(mentionUser);
      }
      _commentController.refreshStyling();
    }
    setState(() {
      replyingToComment = comment;
      replyingToIndex = commentIndex;
      replyingToReply = reply;
      _commentController.text = '@${reply.user?.username ?? ''} ';
      _commentController.selection = TextSelection.collapsed(offset: _commentController.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  void _cancelReply() {
    setState(() {
      replyingToComment = null;
      replyingToIndex = null;
      replyingToReply = null;
      _commentController.clear();
    });
  }

  Future<void> postReply() async {
    if (replyingToComment == null || replyingToIndex == null) return;
    final replyText = _commentController.text.trim();
    if (replyText.isEmpty) return;

    final comment = replyingToComment!;
    comment.replies ??= [];
    final pendingReply = ReplyData(
      id: 'posting',
      reply: replyText,
      user: User(
        profileImage: PrefService.getString(PrefKeys.userProfile),
        username: PrefService.getString(PrefKeys.userName),
      ),
      timeAgo: 'now',
      likeCount: 0,
      isLiked: false,
    );
    comment.replies!.insert(0, pendingReply);
    comment.replyCount = (comment.replyCount ?? 0) + 1;
    comment.isViewReply = true;

    _commentController.clear();
    setState(() {
      replyingToComment = null;
      replyingToIndex = null;
    });
    setState(() {});

    try {
      await postRepository.createCommentReply(
        id: comment.id ?? '',
        body: {'reply': replyText},
        onSuccess: (ApiResponse response) {
          try {
            ReplyData replyData = ReplyData.fromJson(response.data['reply']);
            final idx = comment.replies?.indexWhere((r) => r.id == 'posting') ?? -1;
            if (idx >= 0 && comment.replies != null) {
              comment.replies![idx] = replyData;
            }
            _currentCommentCount++;
            widget.onCommentAdded?.call(_currentCommentCount);
            setState(() {});
          } catch (e) {
            comment.replies?.removeWhere((r) => r.id == 'posting');
            comment.replyCount = (comment.replyCount ?? 1) - 1;
            setState(() {});
          }
        },
        onError: (AppException error) {
          comment.replies?.removeWhere((r) => r.id == 'posting');
          comment.replyCount = (comment.replyCount ?? 1) - 1;
          setState(() {});
        },
      );
    } catch (error) {
      comment.replies?.removeWhere((r) => r.id == 'posting');
      comment.replyCount = (comment.replyCount ?? 1) - 1;
      setState(() {});
      debugPrint('comment reply error :: ${error.toString()}');
    }
  }

  /// Reply to a reply (same flow as postReply: optimistic UI, then API).
  Future<void> postReplyToReply() async {
    if (replyingToComment == null || replyingToIndex == null || replyingToReply == null) return;
    final replyText = _commentController.text.trim();
    if (replyText.isEmpty) return;

    final parentReplyId = replyingToReply!.id;
    if (parentReplyId == null || parentReplyId.isEmpty || parentReplyId == 'posting') return;

    final comment = replyingToComment!;
    comment.replies ??= [];
    final pendingReply = ReplyData(
      id: 'posting',
      reply: replyText,
      user: User(
        profileImage: PrefService.getString(PrefKeys.userProfile),
        username: PrefService.getString(PrefKeys.userName),
      ),
      timeAgo: 'now',
      likeCount: 0,
      isLiked: false,
    );
    comment.replies!.insert(0, pendingReply);
    comment.replyCount = (comment.replyCount ?? 0) + 1;
    comment.isViewReply = true;

    _commentController.clear();
    setState(() {
      replyingToComment = null;
      replyingToIndex = null;
      replyingToReply = null;
    });

    try {
      await postRepository.createCommentReplyToReply(
        id: parentReplyId,
        body: {'reply': replyText},
        onSuccess: (ApiResponse response) {
          try {
            ReplyData replyData = ReplyData.fromJson(response.data['reply']);
            final idx = comment.replies?.indexWhere((r) => r.id == 'posting') ?? -1;
            if (idx >= 0 && comment.replies != null) {
              comment.replies![idx] = replyData;
            }
            _currentCommentCount++;
            widget.onCommentAdded?.call(_currentCommentCount);
            setState(() {});
          } catch (e) {
            comment.replies?.removeWhere((r) => r.id == 'posting');
            comment.replyCount = (comment.replyCount ?? 1) - 1;
            setState(() {});
          }
        },
        onError: (AppException error) {
          comment.replies?.removeWhere((r) => r.id == 'posting');
          comment.replyCount = (comment.replyCount ?? 1) - 1;
          setState(() {});
        },
      );
    } catch (error) {
      comment.replies?.removeWhere((r) => r.id == 'posting');
      comment.replyCount = (comment.replyCount ?? 1) - 1;
      setState(() {});
      debugPrint('comment reply-to-reply error :: ${error.toString()}');
    }
  }

  @override
  void initState() {
    super.initState();
    _currentCommentCount = widget.commentsCount;
    _commentController = MentionTextController(getAvailableUsers: () => _knownUsersForStyling, text: '');
    _commentController.addListener(_onCommentTextChanged);

    // Initialize comment keys
    fetchComments();
    // for (var comment in commentList) {
    //   _commentKeys[comment.id ?? ''] = GlobalKey();
    // }

    // Initialize animation controllers
    _highlightAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _menuAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

    _highlightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _highlightAnimationController, curve: Curves.easeOut));

    _highlightScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _highlightAnimationController, curve: Curves.easeOutCubic));

    _highlightOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _highlightAnimationController, curve: Curves.easeOut));

    _menuScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _menuAnimationController, curve: Curves.easeOutCubic));

    _menuOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _menuAnimationController, curve: Curves.easeOut));

    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _menuAnimationController, curve: Curves.easeOut));
  }

  Widget _buildCommentContextMenu() {
    if (_selectedCommentId == null) return const SizedBox();

    return Stack(children: [_buildHighlightedComment(), _buildDeleteMenu()]);
  }

  Widget _buildReplyContextMenu() {
    if (_selectedReplyCommentIndex == null || _selectedReplyIndex == null || selectedReplyWidget == null) {
      return const SizedBox();
    }

    return Stack(children: [_buildHighlightedReply(), _buildReplyDeleteMenu()]);
  }

  Widget _buildHighlightedReply() {
    if (_selectedReplyCommentIndex == null || _selectedReplyIndex == null || selectedReplyWidget == null) {
      return const SizedBox();
    }

    final comment = commentList[_selectedReplyCommentIndex!];
    final replyKeyStr = '${comment.id}_$_selectedReplyIndex';
    final key = _replyKeys[replyKeyStr];
    if (key?.currentContext == null) return const SizedBox();

    final RenderBox? renderBox = key!.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox();

    final bottomSheetBox = _bottomSheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (bottomSheetBox == null) return const SizedBox();

    final replyPosition = renderBox.localToGlobal(Offset.zero);
    final bottomSheetPosition = bottomSheetBox.localToGlobal(Offset.zero);
    final relativeLeft = replyPosition.dx - bottomSheetPosition.dx;
    final relativeTop = replyPosition.dy - bottomSheetPosition.dy;
    final size = renderBox.size;

    return AnimatedBuilder(
      animation: Listenable.merge([_highlightScaleAnimation, _highlightOpacityAnimation, _highlightAnimation]),
      builder: (context, child) {
        return Positioned(
          left: relativeLeft - 12.w,
          top: relativeTop - 12.w,
          child: IgnorePointer(
            child: Transform.scale(
              scale: _highlightScaleAnimation.value,
              alignment: Alignment.center,
              child: Opacity(
                opacity: _highlightOpacityAnimation.value,
                child: Container(
                  width: size.width + 24.w,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.transparentColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: selectedReplyWidget!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyDeleteMenu() {
    if (_selectedReplyCommentIndex == null || _selectedReplyIndex == null) return const SizedBox();

    final comment = commentList[_selectedReplyCommentIndex!];
    final replyKeyStr = '${comment.id}_$_selectedReplyIndex';
    final key = _replyKeys[replyKeyStr];
    if (key?.currentContext == null) return const SizedBox();

    final RenderBox? renderBox = key!.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox();

    final bottomSheetBox = _bottomSheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (bottomSheetBox == null) return const SizedBox();

    final replyPosition = renderBox.localToGlobal(Offset.zero);
    final bottomSheetPosition = bottomSheetBox.localToGlobal(Offset.zero);
    final relativeTop = replyPosition.dy - bottomSheetPosition.dy;

    final menuWidth = 200.w;
    final menuHeight = 60.h;
    final topPosition = relativeTop - menuHeight - 12.h;

    return AnimatedBuilder(
      animation: Listenable.merge([_menuScaleAnimation, _menuOpacityAnimation, _highlightAnimation]),
      builder: (context, child) {
        return Positioned(
          left: 16.w,
          top: topPosition,
          child: GestureDetector(
            onTap: () {
              final c = commentList[_selectedReplyCommentIndex!];
              final idx = _selectedReplyIndex!;
              final replyToDelete = c.replies?[idx];
              final replyId = replyToDelete?.id ?? '';
              if (replyId.isEmpty) return;

              c.replies?.removeAt(idx);
              c.replyCount = (c.replyCount ?? 1) - 1;
              _replyKeys.remove('${c.id}_$idx');
              _dismissReplySelection();
              setState(() {});

              postRepository.deleteCommentReply(
                id: replyId,
                onSuccess: (ApiResponse response) {
                  _currentCommentCount = _currentCommentCount - 1;
                  widget.onCommentAdded?.call(_currentCommentCount);
                },
                onError: (AppException error) {
                  if (mounted && replyToDelete != null) {
                    c.replies ??= [];
                    c.replies!.insert(idx, replyToDelete);
                    c.replyCount = (c.replyCount ?? 0) + 1;
                    setState(() {});
                  }
                },
              );
            },
            child: Transform.scale(
              scale: _menuScaleAnimation.value,
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: _menuOpacityAnimation.value,
                child: Material(
                  color: Colors.transparent,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: menuWidth,
                      height: menuHeight,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      margin: EdgeInsets.only(bottom: 16.w),
                      decoration: BoxDecoration(color: AppColors.greyF1EFF1, borderRadius: BorderRadius.circular(12.r)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Delete', style: TextStyles.semiBold(16.sp, fontColor: AppColors.redFF5353)),
                          const Spacer(),
                          Assets.icons.icDelete.svg(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightedComment() {
    if (_selectedCommentId == null || selectedComment == null) return const SizedBox();

    final commentKey = _commentKeys[_selectedCommentId];
    if (commentKey?.currentContext == null) return const SizedBox();

    final RenderBox? renderBox = commentKey!.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox();

    // Get bottom sheet position
    final bottomSheetBox = _bottomSheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (bottomSheetBox == null) return const SizedBox();

    // Get position relative to screen
    final commentPosition = renderBox.localToGlobal(Offset.zero);
    final bottomSheetPosition = bottomSheetBox.localToGlobal(Offset.zero);

    // Calculate position relative to bottom sheet
    final relativeLeft = commentPosition.dx - bottomSheetPosition.dx;
    final relativeTop = commentPosition.dy - bottomSheetPosition.dy;
    final size = renderBox.size;

    return AnimatedBuilder(
      animation: Listenable.merge([_highlightScaleAnimation, _highlightOpacityAnimation, _highlightAnimation]),
      builder: (context, child) {
        return Positioned(
          left: relativeLeft - 12.w,
          top: relativeTop - 12.w,
          child: IgnorePointer(
            child: Transform.scale(
              scale: _highlightScaleAnimation.value,
              alignment: Alignment.center,
              child: Opacity(
                opacity: _highlightOpacityAnimation.value,
                child: Container(
                  width: size.width + 24.w,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.transparentColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: selectedComment!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeleteMenu() {
    final commentKey = _commentKeys[_selectedCommentId];
    if (commentKey?.currentContext == null) return const SizedBox();

    final RenderBox? renderBox = commentKey!.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox();

    final bottomSheetBox = _bottomSheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (bottomSheetBox == null) return const SizedBox();

    final commentPosition = renderBox.localToGlobal(Offset.zero);
    final bottomSheetPosition = bottomSheetBox.localToGlobal(Offset.zero);

    final relativeLeft = commentPosition.dx - bottomSheetPosition.dx;
    final relativeTop = commentPosition.dy - bottomSheetPosition.dy;

    final size = renderBox.size;
    final bottomSheetWidth = bottomSheetBox.size.width;

    final menuWidth = 200.w;
    final menuHeight = 70.h;

    final leftPosition = (relativeLeft + size.width / 2) - (menuWidth / 2);
    final adjustedLeft = leftPosition.clamp(16.w, bottomSheetWidth - menuWidth - 16.w);

    final topPosition = relativeTop - menuHeight - 12.h;
    CommentData comment = commentList.firstWhere((c) => c.id == _selectedCommentId);

    int index = commentList.indexWhere((c) => c.id == _selectedCommentId);
    return AnimatedBuilder(
      animation: Listenable.merge([_menuScaleAnimation, _menuOpacityAnimation, _highlightAnimation]),
      builder: (context, child) {
        return Positioned(
          left: adjustedLeft,
          top: topPosition,
          child: Transform.scale(
            scale: _menuScaleAnimation.value,
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: _menuOpacityAnimation.value,
              child: Material(
                color: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: menuWidth,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(color: AppColors.greyF1EFF1, borderRadius: BorderRadius.circular(12.r)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// DELETE OPTION
                      comment.user?.id != PrefService.getString(PrefKeys.userId)
                          ? const SizedBox()
                          : GestureDetector(
                              onTap: () {
                                setState(() {
                                  commentList.removeWhere((comment) => comment.id == _selectedCommentId);
                                  _commentKeys.remove(_selectedCommentId);
                                });

                                _dismissSelection();
                                deleteComment(_selectedCommentId ?? '', index, comment);
                              },
                              child: Row(
                                children: [
                                  Text('Delete', style: TextStyles.semiBold(16.sp, fontColor: AppColors.redFF5353)),
                                  const Spacer(),
                                  Assets.icons.icDelete.svg(),
                                ],
                              ),
                            ),

                      SizedBox(height: 12.h),

                      /// REPORT OPTION
                      comment.user?.id == PrefService.getString(PrefKeys.userId)
                          ? const SizedBox()
                          : GestureDetector(
                              onTap: () {
                                _dismissSelection();
                                Get.find<ReportController>().reset();
                                Get.find<ReportController>().getReportsCategories(context);
                                ReportBottomSheet.show(
                                  postId: _selectedCommentId ?? "",
                                  postType: "POST",
                                  isCommentReport: true,
                                );
                              },
                              child: Row(
                                children: [
                                  Text('Report', style: TextStyles.semiBold(16.sp, fontColor: AppColors.black2F3039)),
                                  const Spacer(),
                                  Assets.icons.icReport.svg(),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMentionUserList() {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      constraints: BoxConstraints(maxHeight: 200.h),
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.greyDFDFDF),
      ),
      child: _isLoadingMentionSearch && _mentionSearchResults.isEmpty
          ? Padding(
              padding: EdgeInsets.all(20.h),
              child: Center(
                child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          : _mentionSearchResults.isEmpty
          ? Padding(
              padding: EdgeInsets.all(20.h),
              child: Center(
                child: Text(
                  _mentionSearchQuery.isEmpty ? 'Type after @ to search users' : 'No users found',
                  style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _mentionSearchResults.length,
              itemBuilder: (context, index) {
                final user = _mentionSearchResults[index];
                return _buildMentionUserListItem(user);
              },
            ),
    );
  }

  Widget _buildMentionUserListItem(MentionUser user) {
    return InkWell(
      onTap: () => _addMention(user),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            ClipOval(
              child: Image.network(
                user.profileImageUrl,
                width: 40.w,
                height: 40.w,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 40.w,
                    height: 40.w,
                    color: AppColors.greyEDEDED,
                    child: Icon(Icons.person, color: AppColors.gray8C9499, size: 20.sp),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 40.w,
                  height: 40.w,
                  color: AppColors.greyEDEDED,
                  child: Icon(Icons.person, color: AppColors.gray8C9499, size: 20.sp),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: TextStyles.bold(14.sp, fontColor: AppColors.black2F3039)),
                  SizedBox(height: 2.h),
                  Text('@${user.username}', style: TextStyles.regular(13.sp, fontColor: AppColors.gray707070)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Row(
              children: [
                CircleAvatar(radius: 18),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 12.h, width: 120.w, color: Colors.white),
                      SizedBox(height: 8.h),
                      Container(height: 12.h, width: double.infinity, color: Colors.white),
                      SizedBox(height: 6.h),
                      Container(height: 12.h, width: 150.w, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= EMPTY STATE =================

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
            SizedBox(height: 12.h),
            Text("No comments yet", style: TextStyles.semiBold(16.sp, fontColor: AppColors.gray8C9499)),
            SizedBox(height: 6.h),
            Text("Be the first to comment", style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate dynamic height: 75% of screen, but adjust for keyboard
    final maxHeight = screenHeight * 0.75;
    final availableHeight = screenHeight - keyboardHeight;
    // When keyboard is open, use available height minus some padding, otherwise use 75% of screen
    final containerHeight = keyboardHeight > 0 ? (availableHeight - 50.h).clamp(300.h, maxHeight) : maxHeight;

    return Stack(
      children: [
        Container(
          key: _bottomSheetKey,
          height: containerHeight,
          decoration: BoxDecoration(
            color: AppColors.whiteFFFFFF,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                color: AppColors.black000000.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.only(top: 8.h, bottom: 15.h),
                child: Column(
                  children: [
                    Gap(8.h),
                    Container(
                      height: 5.w,
                      width: 55.h,
                      decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
                    ),
                    Gap(15.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Comments', style: TextStyles.semiBold(22.sp, fontColor: AppColors.black2F3039)),
                        SizedBox(width: 8.w),
                      ],
                    ),
                  ],
                ),
              ),
              // Comments List
              Expanded(
                child: loader.value
                    ? _buildShimmer()
                    : commentList.isNotEmpty
                    ? Obx(() {
                        return Stack(
                          children: [
                            NotificationListener(
                              onNotification: (notification) {
                                if (notification is ScrollEndNotification && notification.metrics.extentAfter == 0) {
                                  if ((pagination.page ?? 1) < (pagination.pages ?? 1)) {
                                    loadMoreNewsData();
                                  }
                                }
                                return false;
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                itemCount: commentList.length,
                                itemBuilder: (context, index) {
                                  final comment = commentList[index];
                                  if (!_commentKeys.containsKey(comment.id)) {
                                    _commentKeys[comment.id ?? ''] = GlobalKey();
                                  }
                                  return _CommentItem(
                                    commentList: commentList,
                                    index: index,
                                    key: _commentKeys[comment.id],
                                    comment: comment,
                                    onReplyTap: () => _onReplyToComment(comment, index),
                                    onReplyToReplyTap: (reply) => _onReplyToReply(comment, index, reply),
                                    getReplyKey: (replyIndex) => _getReplyKey(comment.id ?? '', replyIndex),
                                    onReplyLongPress: (replyIndex) => _onReplyLongPress(index, replyIndex),
                                    onLike: () {
                                      if (commentList[index].isLiked ?? false) {
                                        commentList[index].isLiked = false;
                                        commentList[index].likeCount = (commentList[index].likeCount ?? 0) - 1;
                                      } else {
                                        commentList[index].isLiked = true;
                                        commentList[index].likeCount = (commentList[index].likeCount ?? 0) + 1;
                                      }

                                      setState(() {});
                                      likeUnlikeComment(comment.id ?? '', index);
                                    },
                                    formatCount: _formatCount,
                                    isSelected: _selectedCommentId == comment.id,
                                    highlightAnimation: _highlightAnimation,
                                    onLongPress: () {
                                      selectedComment = Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.white,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: EdgeInsets.all(12.w),
                                        margin: EdgeInsets.only(bottom: 20.h),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Profile picture
                                            CommonProfileImage(
                                              imageUrl: comment.user?.profileImage,
                                              width: 35.w,
                                              height: 35.w,
                                            ),
                                            SizedBox(width: 10.w),
                                            // Comment content
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Username and time
                                                  Row(
                                                    children: [
                                                      Text(
                                                        comment.user?.username ?? '',
                                                        style: TextStyles.semiBold(
                                                          14.sp,
                                                          fontColor: AppColors.black2F3039,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8.w),
                                                      Text(
                                                        comment.timeAgo ?? '',
                                                        style: TextStyles.medium(
                                                          14.sp,
                                                          fontColor: AppColors.gray8C9499,
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  // Comment text
                                                  Text(
                                                    comment.comment ?? '',
                                                    style: TextStyles.regular(13.sp, fontColor: AppColors.black2F3039),
                                                  ),

                                                  // Like count, Reply, and View replies
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '${comment.likeCount ?? 0} likes',
                                                        style: TextStyles.regular(
                                                          12.sp,
                                                          fontColor: AppColors.gray8C9499,
                                                        ),
                                                      ),
                                                      SizedBox(width: 12.w),
                                                      // Reply button
                                                      GestureDetector(
                                                        onTap: () {
                                                          // Handle reply
                                                        },
                                                        child: Text(
                                                          'Reply',
                                                          style: TextStyles.regular(
                                                            12.sp,
                                                            fontColor: AppColors.gray8C9499,
                                                          ),
                                                        ),
                                                      ),

                                                      // View replies
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      _onCommentLongPress(comment.id ?? '');
                                    },
                                  );
                                },
                              ),
                            ),
                            isLastLoading.value
                                ? const Align(alignment: Alignment.bottomCenter, child: LinearProgressIndicator())
                                : const SizedBox.shrink(),
                          ],
                        );
                      })
                    : _buildEmptyState(),
              ),

              // Replying to bar (Instagram-style)
              if (replyingToComment != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  color: AppColors.grayEDF1F4,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Replying to @${replyingToReply?.user?.username ?? replyingToComment!.user?.username ?? ''}',
                          style: TextStyles.regular(13.sp, fontColor: AppColors.gray8C9499),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: Padding(
                          padding: EdgeInsets.all(4.w),
                          child: Icon(Icons.close, size: 20.sp, color: AppColors.gray8C9499),
                        ),
                      ),
                    ],
                  ),
                ),

              // Add Comment Input
              Container(
                padding: EdgeInsets.only(left: 16.w, right: 3.w, top: 12.h, bottom: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.grayEDF1F4,
                  border: Border(top: BorderSide(color: AppColors.grayEDF1F4, width: 1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // @ Mention user list (when user types @)
                    if (_showMentionList) _buildMentionUserList(),
                    Row(
                      children: [
                        // Text input (@ tags show in primary color)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.grayEDF1F4,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: TextField(
                              controller: _commentController,
                              focusNode: _focusNode,
                              style: TextStyles.regular(14.sp, fontColor: AppColors.black2F3039),
                              minLines: 1,
                              maxLines: 6,
                              decoration: InputDecoration(
                                fillColor: AppColors.white,
                                filled: true,
                                hintText: 'Add a comment',
                                hintStyle: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24.r),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24.r),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24.r),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) {},
                            ),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        // Send button
                        IconButton(
                          onPressed: () async {
                            if (_commentController.text.isEmpty) {
                              return;
                            }

                            String commentText = _commentController.text;

                            if (replyingToReply != null) {
                              await postReplyToReply();
                              return;
                            }
                            if (replyingToComment != null) {
                              await postReply();
                              return;
                            }
                            commentList.insert(
                              0,
                              CommentData(
                                comment: _commentController.text,
                                likeCount: 0,
                                replyCount: 0,
                                timeAgo: 'now',
                                user: User(
                                  profileImage: PrefService.getString(PrefKeys.userProfile),
                                  username: PrefService.getString(PrefKeys.userName),
                                ),
                              ),
                            );
                            _commentController.clear();
                            await postComment(commentText);
                          },
                          icon: Assets.icons.icSend.svg(),
                          highlightColor: AppColors.lightPrimaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Blurred background overlay (comment or reply long-press delete)
        (_selectedCommentId != null || _selectedReplyCommentIndex != null)
            ? Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (_selectedCommentId != null) _dismissSelection();
                    if (_selectedReplyCommentIndex != null) _dismissReplySelection();
                  },
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                        child: Stack(
                          children: [
                            if (_selectedCommentId != null) _buildCommentContextMenu(),
                            if (_selectedReplyCommentIndex != null) _buildReplyContextMenu(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(),
      ],
    );
  }
}

class _CommentItem extends StatefulWidget {
  final CommentData comment;
  final VoidCallback onLike;
  final VoidCallback? onReplyTap;
  final void Function(ReplyData reply)? onReplyToReplyTap;
  final GlobalKey Function(int replyIndex) getReplyKey;
  final void Function(int replyIndex)? onReplyLongPress;
  final String Function(int) formatCount;
  final bool isSelected;
  final Animation<double> highlightAnimation;
  final VoidCallback onLongPress;
  final int index;
  final List<CommentData> commentList;

  const _CommentItem({
    super.key,
    required this.comment,
    required this.onLike,
    this.onReplyTap,
    this.onReplyToReplyTap,
    required this.getReplyKey,
    this.onReplyLongPress,
    required this.formatCount,
    required this.isSelected,
    required this.highlightAnimation,
    required this.onLongPress,
    required this.index,
    required this.commentList,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  PostRepository postRepository = PostRepository();

  /// Builds comment/reply text with @mentions from API in primary color; tap opens user profile.
  Widget _buildCommentOrReplyText(String text, List<User>? mentionedUsers, double fontSize) {
    if (text.isEmpty) return const SizedBox.shrink();
    final baseStyle = TextStyles.regular(fontSize, fontColor: AppColors.black2F3039);
    final mentionStyle = TextStyles.regular(fontSize, fontColor: AppColors.primaryColor);
    final list = mentionedUsers ?? [];
    final List<InlineSpan> spans = [];
    final mentionRegex = RegExp(r'@(\w+)');
    int lastIndex = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: baseStyle));
      }
      final username = match.group(1) ?? '';
      User? matchedUser;
      for (final u in list) {
        if (u.username == username) {
          matchedUser = u;
          break;
        }
      }
      if (matchedUser != null && matchedUser.id != null && matchedUser.id!.isNotEmpty) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: mentionStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => Get.toNamed(AppRoutes.otherUserProfile, arguments: matchedUser!.id),
          ),
        );
      } else {
        spans.add(TextSpan(text: match.group(0), style: baseStyle));
      }
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }
    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  Future<void> likeUnlikeCommentReply(String commentId, int index, int replyIndex) async {
    try {
      await postRepository.likeUnlikeCommentReply(
        id: commentId,

        onSuccess: (ApiResponse response) {
          try {} catch (e) {
            if (widget.commentList[widget.index].replies?[replyIndex].isLiked ?? false) {
              widget.commentList[widget.index].replies?[replyIndex].isLiked = false;
              widget.commentList[widget.index].replies?[replyIndex].likeCount =
                  (widget.commentList[widget.index].replies?[replyIndex].likeCount ?? 0) - 1;
            } else {
              widget.commentList[widget.index].replies?[replyIndex].isLiked = true;
              widget.commentList[widget.index].replies?[replyIndex].likeCount =
                  (widget.commentList[widget.index].replies?[replyIndex].likeCount ?? 0) + 1;
            }
            setState(() {});
          }
        },
        onError: (AppException error) {
          if (widget.commentList[widget.index].replies?[replyIndex].isLiked ?? false) {
            widget.commentList[widget.index].replies?[replyIndex].isLiked = false;
            widget.commentList[widget.index].replies?[replyIndex].likeCount =
                (widget.commentList[widget.index].replies?[replyIndex].likeCount ?? 0) - 1;
          } else {
            widget.commentList[widget.index].replies?[replyIndex].isLiked = true;
            widget.commentList[widget.index].replies?[replyIndex].likeCount =
                (widget.commentList[widget.index].replies?[replyIndex].likeCount ?? 0) + 1;
          }
          setState(() {});
        },
      );
    } catch (error) {
      if (widget.commentList[widget.index].replies?[replyIndex].isLiked ?? false) {
        widget.commentList[widget.index].replies?[replyIndex].isLiked = false;
        widget.commentList[widget.index].replies?[replyIndex].likeCount =
            (widget.commentList[widget.index].replies?[replyIndex].likeCount ?? 0) - 1;
      } else {
        widget.commentList[widget.index].replies?[replyIndex].isLiked = true;
        widget.commentList[widget.index].replies?[replyIndex].likeCount =
            (widget.commentList[widget.index].replies?[replyIndex].likeCount ?? 0) + 1;
      }
      setState(() {});
      debugPrint('like unlike error ${error.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Padding(
        padding: EdgeInsets.only(bottom: 20.h),
        child: Column(
          children: [
            // Top-level comment row (long-press here previews the parent comment)
            GestureDetector(
              onLongPress: widget.onLongPress,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile picture
                  GestureDetector(
                    onTap: () {
                      Get.toNamed(AppRoutes.otherUserProfile, arguments: widget.comment.user?.id);
                    },
                    child: CommonProfileImage(imageUrl: widget.comment.user?.profileImage, width: 40.w, height: 40.w),
                  ),
                  SizedBox(width: 12.w),
                  // Comment content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username and time
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Get.toNamed(AppRoutes.otherUserProfile, arguments: widget.comment.user?.id);
                              },
                              child: Text(
                                widget.comment.user?.username ?? '',
                                style: TextStyles.semiBold(14.sp, fontColor: AppColors.black2F3039),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              widget.comment.timeAgo ?? "",
                              style: TextStyles.medium(14.sp, fontColor: AppColors.gray8C9499),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        // Comment text (API mentionedUsers: @mentions in primary color, tap → profile)
                        _buildCommentOrReplyText(widget.comment.comment ?? '', widget.comment.mentionedUsers, 16.sp),
                        SizedBox(height: 4.h),
                        // Like count, Reply, and View replies
                        (widget.comment.isPosting ?? false)
                            ? Text('Posting.....', style: TextStyles.regular(12.sp, fontColor: AppColors.gray8C9499))
                            : Row(
                                children: [
                                  Text(
                                    '${widget.formatCount(widget.comment.likeCount ?? 0)} likes',
                                    style: TextStyles.regular(12.sp, fontColor: AppColors.gray8C9499),
                                  ),
                                  SizedBox(width: 12.w),
                                  // Reply button
                                  GestureDetector(
                                    onTap: widget.onReplyTap,
                                    child: Text(
                                      'Reply',
                                      style: TextStyles.regular(12.sp, fontColor: AppColors.gray8C9499),
                                    ),
                                  ),
                                  // View replies
                                ],
                              ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Like button
                  GestureDetector(
                    onTap: widget.onLike,
                    child: (widget.comment.isLiked ?? false)
                        ? Assets.icons.icLike.svg(width: 20.w, height: 20.h)
                        : Assets.icons.icLikeBorder.svg(
                            width: 20.w,
                            height: 20.h,
                            colorFilter: ColorFilter.mode(AppColors.black000000, BlendMode.srcIn),
                          ),
                  ),
                ],
              ),
            ),
            if ((widget.comment.replyCount ?? 0) > 0) ...[
              Row(
                children: [
                  Gap(52.w),
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(height: 6.h),

                        /// View Replies Toggle
                        GestureDetector(
                          onTap: () {
                            widget.comment.isViewReply = !(widget.comment.isViewReply ?? false);
                            (context as Element).markNeedsBuild();
                          },
                          child: Row(
                            children: [
                              Text(
                                /*comment.isViewReply == true ? "Hide replies" : */
                                "View replies (${widget.comment.replyCount})",
                                style: TextStyles.semiBold(13.sp, fontColor: AppColors.black2F3039),
                              ),

                              widget.comment.isViewReply == true
                                  ? Icon(Icons.keyboard_arrow_up, color: AppColors.black2F3039)
                                  : Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.black2F3039),
                            ],
                          ),
                        ),

                        /// Replies List
                        if (widget.comment.isViewReply == true)
                          ListView.separated(
                            separatorBuilder: (context, index) => Gap(7),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: widget.comment.replies?.length ?? 0,
                            padding: EdgeInsets.only(top: 8.h),
                            itemBuilder: (context, replyIndex) {
                              ReplyData reply = widget.comment.replies![replyIndex];

                              return GestureDetector(
                                // Long-press on a reply should trigger the
                                // dedicated reply long-press handler so that
                                // the correct reply preview is shown.
                                onLongPress: () => widget.onReplyLongPress?.call(replyIndex),
                                child: KeyedSubtree(
                                  key: widget.getReplyKey(replyIndex),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      /// Reply Profile
                                      GestureDetector(
                                        onTap: () {
                                          Get.toNamed(AppRoutes.otherUserProfile, arguments: reply.user?.id);
                                        },
                                        child: CommonProfileImage(
                                          imageUrl: reply.user?.profileImage,
                                          width: 28.w,
                                          height: 28.w,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),

                                      /// Reply Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    Get.toNamed(AppRoutes.otherUserProfile, arguments: reply.user?.id);
                                                  },
                                                  child: Text(
                                                    reply.user?.username ?? "",
                                                    style: TextStyles.semiBold(13.sp, fontColor: AppColors.black2F3039),
                                                  ),
                                                ),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  reply.timeAgo ?? "",
                                                  style: TextStyles.regular(12.sp, fontColor: AppColors.gray8C9499),
                                                ),
                                              ],
                                            ),

                                            SizedBox(height: 4.h),

                                            (reply.id == 'posting')
                                                ? Text(
                                                    'Posting...',
                                                    style: TextStyles.regular(14.sp, fontColor: AppColors.gray8C9499),
                                                  )
                                                : _buildCommentOrReplyText(
                                                    reply.reply ?? "",
                                                    reply.mentionedUsers,
                                                    14.sp,
                                                  ),

                                            SizedBox(height: 4.h),

                                            if (reply.id != 'posting')
                                              Row(
                                                children: [
                                                  Text(
                                                    "${widget.formatCount(reply.likeCount ?? 0)} likes",
                                                    style: TextStyles.regular(11.sp, fontColor: AppColors.gray8C9499),
                                                  ),
                                                  SizedBox(width: 12.w),
                                                  GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () => widget.onReplyToReplyTap?.call(reply),
                                                    child: Padding(
                                                      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
                                                      child: Text(
                                                        'Reply',
                                                        style: TextStyles.regular(
                                                          11.sp,
                                                          fontColor: AppColors.gray8C9499,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),

                                      /// Reply Like Icon
                                      GestureDetector(
                                        onTap: () {
                                          if (widget.commentList[widget.index].replies?[replyIndex].isLiked ?? false) {
                                            widget.commentList[widget.index].replies?[replyIndex].isLiked = false;
                                            widget.commentList[widget.index].replies?[replyIndex].likeCount =
                                                (widget.commentList[widget.index].replies?[replyIndex].likeCount ?? 0) -
                                                1;
                                          } else {
                                            widget.commentList[widget.index].replies?[replyIndex].isLiked = true;
                                            widget.commentList[widget.index].replies?[replyIndex].likeCount =
                                                (widget.commentList[widget.index].replies?[replyIndex].likeCount ?? 0) +
                                                1;
                                          }
                                          setState(() {});
                                          likeUnlikeCommentReply(
                                            widget.commentList[widget.index].replies?[replyIndex].id ?? '',
                                            widget.index,
                                            replyIndex,
                                          );
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 6.w),
                                          child: (reply.isLiked ?? false)
                                              ? Assets.icons.icLike.svg(width: 20.w, height: 20.h)
                                              : Assets.icons.icLikeBorder.svg(
                                                  width: 20.w,
                                                  height: 20.h,
                                                  colorFilter: ColorFilter.mode(AppColors.black000000, BlendMode.srcIn),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
