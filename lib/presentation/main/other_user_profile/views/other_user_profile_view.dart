import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:shimmer/shimmer.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/models/user_profile_response_model.dart';
import 'package:omeeba_new/core/widgets/common_loader.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/core/widgets/common_post_detail_widget.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/core/widgets/common_write_post_item.dart';
import 'package:omeeba_new/core/widgets/poll_card.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_model.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/explore_grid_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/explore_list_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/poll_list_shimmer.dart';
import 'package:omeeba_new/presentation/main/home/widgets/share_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/other_user_profile/controller/other_user_profile_controller.dart';
import 'package:omeeba_new/presentation/main/other_user_profile/widgets/unfollow_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/zeals/views/zeal_detail_screen.dart';
import 'package:omeeba_new/presentation/main/zeals/widget/comments_bottom_sheet.dart';

import '../../../../core/helper/like_helper.dart';
import '../../myprofile/views/my_profile_view.dart';
import '../../myprofile/widgets/following_list_view.dart';
import '../../myprofile/widgets/my_profile_shimmer.dart';
import '../../report/controller/report_controller.dart';
import '../../report/view/report_bottom_sheet.dart';

class OtherUserProfileView extends StatefulWidget {
  const OtherUserProfileView({super.key, this.controllerTag});

  final String? controllerTag;

  @override
  State<OtherUserProfileView> createState() => _OtherUserProfileViewState();
}

class _OtherUserProfileViewState extends State<OtherUserProfileView> with TickerProviderStateMixin {
  int _selectedContentTab = 0;
  final ScrollController _scrollController = ScrollController();
  late final OtherUserProfileController _controller;

  OverlayEntry? _postPreviewEntry;
  AnimationController? _postPreviewController;
  bool _suppressGridTap = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controllerTag != null
        ? Get.find<OtherUserProfileController>(tag: widget.controllerTag)
        : Get.find<OtherUserProfileController>();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _removePostPreview(immediate: true);
    _postPreviewController?.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo';
    final years = (diff.inDays / 365).floor();
    return '${years}y';
  }

  void _releaseTapSuppressionSoon() {
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _suppressGridTap = false;
    });
  }

  void _removePostPreview({bool immediate = false}) {
    final entry = _postPreviewEntry;
    if (entry == null) return;

    if (immediate) {
      _postPreviewController?.stop();
      entry.remove();
      _postPreviewEntry = null;
      _releaseTapSuppressionSoon();
      return;
    }

    final controller = _postPreviewController;
    if (controller == null) {
      entry.remove();
      _postPreviewEntry = null;
      _releaseTapSuppressionSoon();
      return;
    }

    controller.reverse().whenComplete(() {
      if (_postPreviewEntry == entry) {
        entry.remove();
        _postPreviewEntry = null;
        _releaseTapSuppressionSoon();
      }
    });
  }

  void _handleGridPostTap(PostData post) {
    if (_suppressGridTap || _postPreviewEntry != null) return;
    _navigateToPostDetail(post);
  }

  void _handleGridPostLongPressStart(GlobalKey key, PostData post) {
    _suppressGridTap = true;
    _showPostPreviewFromKey(key, post);
  }

  void _showPostPreviewFromKey(GlobalKey key, PostData post) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox) return;
    final fromOffset = renderObject.localToGlobal(Offset.zero);
    final fromRect = fromOffset & renderObject.size;

    final mediaUrl = _getPostPreviewUrl(post);
    if (mediaUrl == null || mediaUrl.isEmpty) return;

    final authorName = post.userId?.name ?? post.userId?.username ?? 'User';
    final profileImageUrl = post.userId?.profileImage is String ? post.userId!.profileImage as String? : null;
    final timeAgo = _timeAgo(post.createdAt);
    final mediaAspectRatio = (post.imageAspectRatio != null && post.imageAspectRatio! > 0)
        ? post.imageAspectRatio!
        : 1.0;

    _removePostPreview(immediate: true);

    _postPreviewController?.dispose();
    _postPreviewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 120),
    );

    HapticFeedback.lightImpact();

    final entry = OverlayEntry(
      builder: (context) {
        return _OtherUserPostLongPressPreviewOverlay(
          controller: _postPreviewController!,
          fromRect: fromRect,
          imageUrl: mediaUrl,
          authorName: authorName,
          timeAgo: timeAgo,
          profileImageUrl: profileImageUrl,
          mediaAspectRatio: mediaAspectRatio,
          onDismiss: () => _removePostPreview(),
        );
      },
    );
    _postPreviewEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
    _postPreviewController!.forward();
  }

  String? _getPostPreviewUrl(PostData post) {
    final images = post.images;
    if (images != null && images.isNotEmpty) return images.first;
    if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty) return post.thumbnailUrl;
    if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) return post.mediaUrl;
    final videos = post.videos;
    if (videos != null && videos.isNotEmpty) return videos.first;
    return null;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      switch (_selectedContentTab) {
        case 0:
          _controller.loadMorePosts();
          break;
        case 1:
          _controller.loadMoreZeals();
          break;
        case 2:
          _controller.loadMoreWrites();
          break;
        case 3:
          _controller.loadMorePolls();
          break;
        case 4:
          _controller.loadMoreTagged();
          break;
      }
    }
  }

  void _onTabTapped(int index) {
    if (_selectedContentTab == index) return;
    setState(() {
      _selectedContentTab = index;
    });
    _controller.loadTabIfNeeded(index);
  }

  /// True when viewing another user's profile (not the current login user).
  bool _isOtherUser(Profile? profile) {
    if (profile?.id == null || profile!.id!.isEmpty) return false;
    return profile.id != PrefService.getString(PrefKeys.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_controller.isLoading.value) {
        return const MyProfileShimmer();
      }

      return WillPopScope(
        onWillPop: () async {
          if (_postPreviewEntry != null) {
            _removePostPreview();
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: AppColors.whiteFFFFFF,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => _controller.refreshProfileAndCurrentTab(_selectedContentTab),
              color: AppColors.primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _buildProfileHeader()),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      child: _ProfileFilterBar(selectedIndex: _selectedContentTab, onTabTapped: _onTabTapped),
                    ),
                  ),
                  ..._buildCurrentTabSlivers(),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildCurrentTabSlivers() {
    switch (_selectedContentTab) {
      case 0:
        return _buildPostsSlivers();
      case 1:
        return _buildZealsSlivers();
      case 2:
        return _buildWritesSlivers();
      case 3:
        return _buildPollsSlivers();
      case 4:
        return _buildTaggedSlivers();
      default:
        return _buildPostsSlivers();
    }
  }

  List<Widget> _buildPostsSlivers() {
    final isLoading = _controller.postsLoading.value;
    final posts = _controller.postsData.value?.posts ?? [];
    final showShimmer = isLoading && posts.isEmpty;
    if (showShimmer) {
      return [const SliverToBoxAdapter(child: ExploreGridShimmer())];
    }
    if (!isLoading && posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _emptyState(icon: Assets.icons.icPostPlaceholder.svg(), message: 'No posts yet'),
        ),
      ];
    }
    final loadMore = _controller.postsLoadMoreLoading.value;
    return [
      SliverPadding(
        padding: EdgeInsets.all(1.w),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2.w,
            mainAxisSpacing: 2.w,
            childAspectRatio: 0.8,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= posts.length) {
              return Center(
                child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final post = posts[index];
            final isZealPost = (post.contentType ?? '').toLowerCase().contains('zeal');
            final tileKey = GlobalKey();
            return _OtherUserSquareGridItem(
              key: tileKey,
              post: post,
              showFlameIcon: isZealPost,
              onTap: () => _handleGridPostTap(post),
              onLongPress: () => _handleGridPostLongPressStart(tileKey, post),
            );
          }, childCount: posts.length + (loadMore ? 1 : 0)),
        ),
      ),
      // Extra space so list is always scrollable when few items → pull-to-refresh works
  //   SliverToBoxAdapter(child: SizedBox(height: getExtraScrollHeight(context, posts.length, -40))),
    ];
  }

  List<Widget> _buildZealsSlivers() {
    final isLoading = _controller.zealsLoading.value;
    final zeals = _controller.zealsData.value?.posts ?? [];
    final showShimmer = isLoading && zeals.isEmpty;
    if (showShimmer) {
      return [const SliverToBoxAdapter(child: ExploreGridShimmer())];
    }
    if (!isLoading && zeals.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _emptyState(icon: Assets.icons.icPlaceholderZeel.svg(), message: 'No zeals yet'),
        ),
      ];
    }
    final loadMore = _controller.zealsLoadMoreLoading.value;
    return [
      SliverPadding(
        padding: EdgeInsets.all(1.w),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 3.w,
            mainAxisSpacing: 3.w,
            childAspectRatio: 0.7,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= zeals.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Center(
                  child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            zeals[index].isFollowing = _controller.isFollowing.value;
            return _OtherUserZealThumbnail(
              post: zeals[index],
              // onTap: () {
              //   Get.to(() => ZealDetailScreen(), arguments: zeals[index])?.then((result) {
              //     if (result is String) c.removeZealById(result);
              //   });
              // },
              onTap: () => Get.to(() => ZealDetailScreen(), arguments: zeals[index]),
            );
          }, childCount: zeals.length + (loadMore ? 1 : 0)),
        ),
      ),
      // Extra space so list is always scrollable when few items → pull-to-refresh works
 //     SliverToBoxAdapter(child: SizedBox(height: getExtraScrollHeightForZeal(context, zeals.length, -25))),
    ];
  }

  List<Widget> _buildWritesSlivers() {
    final isLoading = _controller.writesLoading.value;
    final writes = _controller.writesData.value?.posts ?? [];
    final showShimmer = isLoading && writes.isEmpty;
    if (showShimmer) {
      return [const SliverToBoxAdapter(child: ExploreListShimmer())];
    }
    if (!isLoading && writes.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _emptyState(icon: Assets.icons.icSaveWrite.svg(), message: 'No writes yet'),
        ),
      ];
    }
    final loadMore = _controller.writesLoadMoreLoading.value;
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= writes.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }
          final post = writes[index];

          return CommonWritePostItem(
            postData: post,
            onReport: () {
              Get.find<ReportController>().reset();
              Get.find<ReportController>().getReportsCategories(context);
              ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Post');
            },
            isNavigation: false,
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

            onSave: () {
              _controller.saveUnSavePost(context, post);
            },
            onComment: () {
              CommentsBottomSheet.show(
                postId: post.id ?? '',
                commentsCount: post.commentCount ?? 0,
                contentType: post.contentType ?? '',
                onCommentAdded: (newCount) {
                  post.commentCount = newCount;
                  setState(() {});
                },
              );
            },
            onBookmark: () {
              _controller.saveUnSavePost(context, post);
            },
            onShare: () {
              ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
            },
            isBookmarked: post.isSaved ?? false,
            onDelete: () => _controller.removeWritePostById(post.id ?? ""),
          );
        }, childCount: writes.length + (loadMore ? 1 : 0)),
      ),
    ];
  }

  List<Widget> _buildPollsSlivers() {
    final isLoading = _controller.pollsLoading.value;
    final polls = _controller.pollsData.value?.posts ?? [];
    final showShimmer = isLoading && polls.isEmpty;
    if (showShimmer) {
      return [const SliverToBoxAdapter(child: PollListShimmer())];
    }
    if (!isLoading && polls.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _emptyState(icon: Assets.icons.icSavePolls.svg(), message: 'No polls yet'),
        ),
      ];
    }
    final loadMore = _controller.pollsLoadMoreLoading.value;
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= polls.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }
          final post = polls[index];
          return PollCard(
            key: ValueKey('explore_poll_${post.id}'),
            postData: post,
            isNavigation: false,
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
            onReport: () {
              Get.find<ReportController>().reset();
              Get.find<ReportController>().getReportsCategories(context);
              ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Poll');
            },
            onComment: () {
              CommentsBottomSheet.show(
                postId: post.id ?? '',
                commentsCount: post.commentCount ?? 0,
                contentType: post.contentType ?? 'Poll',
                onCommentAdded: (newCount) {
                  post.commentCount = newCount;
                  setState(() {});
                },
              );
            },
            onBookmark: () {
              _controller.saveUnSavePost(context, post);
            },

            onShare: () {
              ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
            },
            onCopyLink: () {
              Clipboard.setData(ClipboardData(text: post.shareableLink ?? "demo"));
            },
            onSave: () {
              _controller.saveUnSavePost(context, post);
            },
            onOptionTap: (optionId) => _controller.submitPollVote(post.id!, optionId),
            onDelete: () => _controller.removePollPostById(post.id ?? ""),
          );
        }, childCount: polls.length + (loadMore ? 1 : 0)),
      ),
    ];
  }

  List<Widget> _buildTaggedSlivers() {
    final isLoading = _controller.taggedLoading.value;
    final tagged = _controller.taggedData.value?.posts ?? [];
    final showShimmer = isLoading && tagged.isEmpty;
    if (showShimmer) {
      return [const SliverToBoxAdapter(child: ExploreListShimmer())];
    }
    if (!isLoading && tagged.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _emptyState(icon: Assets.icons.icSavePost.svg(), message: 'No tagged posts yet'),
        ),
      ];
    }
    final loadMore = _controller.taggedLoadMoreLoading.value;
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= tagged.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }
          final post = tagged[index];
          return _buildPostItem(post, index);
        }, childCount: tagged.length + (loadMore ? 1 : 0)),
      ),
    ];
  }

  Widget _buildPostItem(PostData post, int index) {
    final contentType = post.contentType ?? '';

    // ── Write Post ──────────────────────────────────────────────────────────
    if (contentType == 'Write Post') {
      return CommonWritePostItem(
        key: ValueKey('home_write_${post.id}_$index'.toString()),
        postData: post,
        onReport: () {
          Get.find<ReportController>().reset();
          Get.find<ReportController>().getReportsCategories(context);
          ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Post');
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
        onShare: () {
          ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
        },
        onComment: () {
          CommentsBottomSheet.show(
            postId: post.id ?? '',
            commentsCount: post.commentCount ?? 0,
            contentType: post.contentType ?? '',
            onCommentAdded: (newCount) {
              post.commentCount = newCount;
              setState(() {});
            },
            onCommentRemove: (newCount) {
              post.commentCount = newCount;
              setState(() {});
            },
          );
        },
        onSave: () {
          _controller.saveUnSavePost(context, post);
        },
        onBookmark: () {
          _controller.saveUnSavePost(context, post);
        },
        onDelete: () => _controller.removeWritePostById(post.id ?? ""),
      );
    }

    // ── Poll ────────────────────────────────────────────────────────────────
    if (contentType == 'Poll') {
      return PollCard(
        key: ValueKey('explore_poll_${post.id}'),
        postData: post,
        onLike: () {
          LikeHelper.toggleLike(
            contentId: post.id ?? '',
            contentType: post.contentType ?? 'Poll',
            isLiked: post.isLiked ?? false,
            likeCount: post.likeCount ?? 0,
            onLocalUpdate: (liked, count) {
              post.isLiked = liked;
              post.likeCount = count;
              setState(() {});
            },
          );
        },
        onCopyLink: () {
          Clipboard.setData(ClipboardData(text: post.shareableLink ?? "demo"));
        },
        onSave: () {
          _controller.saveUnSavePost(context, post);
        },
        onComment: () {
          CommentsBottomSheet.show(
            postId: post.id ?? '',
            commentsCount: post.commentCount ?? 0,
            contentType: post.contentType ?? '',
            onCommentAdded: (newCount) {
              post.commentCount = newCount;
              setState(() {});
            },
            onCommentRemove: (newCount) {
              post.commentCount = newCount;
              setState(() {});
            },
          );
        },
        hasVoted: post.displayHasVoted,
        votedOptionId: post.displayVotedOptionId,
        isExpired: post.isPollExpired,
        onReport: () {
          Get.find<ReportController>().reset();
          Get.find<ReportController>().getReportsCategories(context);
          ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Poll');
        },
        onOptionTap: (optionId) => _controller.submitPollVote(post.id!, optionId),
        onBookmark: () {
          _controller.saveUnSavePost(context, post);
        },
        onShare: () {
          ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
        },
        onDelete: () => _controller.removePollPostById(post.id ?? ""),
      );
    }

    // ── Default: Post / Zeal ────────────────────────────────────────────────
    return CommonPostDetailWidget(
      key: ValueKey('home_post_${post.id}_$index'),
      post: post,

      heroTagPrefix: 'home_post_$index',
      onBookmark: () {
        _controller.saveUnSavePost(context, post);
      },

      onComment: () {
        CommentsBottomSheet.show(
          postId: post.id ?? '',
          commentsCount: post.commentCount ?? 0,
          contentType: post.contentType ?? '',
          onCommentAdded: (newCount) {
            post.commentCount = newCount;
            setState(() {});
          },
          onCommentRemove: (newCount) {
            post.commentCount = newCount;
            setState(() {});
          },
        );
      },
      onSave: () {
        _controller.saveUnSavePost(context, post);
      },

      onShare: () {
        ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
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
      onDelete: () => _controller.removePostById(post.id ?? ""),
      onReport: () {
        Get.find<ReportController>().reset();
        Get.find<ReportController>().getReportsCategories(context);
        ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Post');
      },
    );
  }

  Widget _emptyState({required Widget icon, required String message}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(color: AppColors.orangeF8F1EB, shape: BoxShape.circle),
          child: icon,
        ),
        Gap(15.h),
        Text(
          message,
          style: TextStyles.semiBold(22.sp, fontColor: AppColors.black2F3039),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  bool _isZealWithVideo(PostData post) {
    return (post.contentType ?? '').toLowerCase().contains('zeal') &&
        post.mediaUrl != null &&
        post.mediaUrl!.toString().trim().isNotEmpty;
  }

  void _navigateToPostDetail(PostData post) {
    if (_isZealWithVideo(post)) {
      post.isFollowing = _controller.isFollowing.value;
      Get.to(() => ZealDetailScreen(), arguments: post);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.whiteFFFFFF,
          appBar: AppBar(
            backgroundColor: AppColors.whiteFFFFFF,
            elevation: 0,
            leading: IconButton(
              icon: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Obx(() {
            _controller.bookmarkRefreshTrigger.value;
            _controller.commentRefreshTrigger.value;
            return SingleChildScrollView(
              child: CommonPostDetailWidget(
                post: post,
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
                onComment: () {
                  CommentsBottomSheet.show(
                    postId: post.id ?? '',
                    commentsCount: post.commentCount ?? 0,
                    contentType: post.contentType ?? '',
                    onCommentAdded: (newCount) {
                      post.commentCount = newCount;
                      _controller.commentRefreshTrigger.value++;
                    },
                  );
                },
                onBookmark: () {
                  _controller.saveUnSavePost(context, post);
                },
                onShare: () {
                  ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
                },
                onSave: () {
                  _controller.saveUnSavePost(context, post);
                },
                onReport: () {
                  Get.find<ReportController>().reset();
                  Get.find<ReportController>().getReportsCategories(context);
                  ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Post');
                },
                onDelete: () => _controller.removePostById(post.id ?? ""),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatItem({required int count, required String label, VoidCallback? onTap}) {
    return InkWell(
      highlightColor: AppColors.transparentColor,
      splashColor: AppColors.transparentColor,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(formatCount(count), style: TextStyles.bold(22.sp, fontColor: AppColors.black2F3039)),

          Text(label, style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070)),
        ],
      ),
    );
  }

  String formatCount(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    }
    return value.toString();
  }

  Widget _buildProfileHeader() {
    final profile = _controller.profile.value;
    final coverImageUrl = profile?.coverImage is String ? profile!.coverImage as String : null;
    final profileImageUrl = profile?.profileImage is String ? profile!.profileImage as String : null;
    final displayName = profile?.name ?? profile?.username ?? '';
    final username = profile?.username ?? '';
    final bio = profile?.bio ?? '';
    final followersCount = profile?.followersCount ?? 0;
    final followingCount = profile?.followingCount ?? 0;
    final isVerified = profile?.isVerifiedBadge ?? false;

    return Stack(
      children: [
        // Cover image — same as my profile: true cover (no stretch) + shimmer while loading
        SizedBox(
          height: 140.h,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                        ? constraints.maxWidth
                        : MediaQuery.sizeOf(context).width;
                    final h = constraints.maxHeight;
                    final hasCover = coverImageUrl != null && coverImageUrl.isNotEmpty;
                    return ClipRect(
                      child: hasCover
                          ? CachedNetworkImage(
                              imageUrl: coverImageUrl,
                              width: w,
                              height: h,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              fadeInDuration: const Duration(milliseconds: 280),
                              fadeOutDuration: const Duration(milliseconds: 120),
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: AppColors.grayEDF1F4,
                                highlightColor: AppColors.greyF3F4F5,
                                child: Container(width: w, height: h, color: AppColors.grayEDF1F4),
                              ),
                              errorWidget: (context, url, error) => Image(
                                image: Assets.images.bannerPlaceholder.provider(),
                                fit: BoxFit.cover,
                                width: w,
                                height: h,
                              ),
                              imageBuilder: (context, imageProvider) {
                                return Image(
                                  image: imageProvider,
                                  width: w,
                                  height: h,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.medium,
                                );
                              },
                            )
                          : Image(
                              image: Assets.images.bannerPlaceholder.provider(),
                              fit: BoxFit.cover,
                              width: w,
                              height: h,
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Back button + username at top-left (over cover) with scrim for visibility on light backgrounds
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: Assets.icons.icArrowBack.image(height: 24.h, width: 24.w, color: AppColors.whiteFFFFFF),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
                  ),
                  Expanded(
                    child: Text(
                      username.isNotEmpty ? username : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.semiBold(22.sp, fontColor: AppColors.whiteFFFFFF).copyWith(
                        shadows: [
                          Shadow(color: Colors.black.withValues(alpha: 0.5), offset: const Offset(0, 1), blurRadius: 2),
                          Shadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 2), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Profile avatar
        Positioned(
          left: 12.w,
          right: 0,
          top: 100.h,
          child: Stack(
            children: [
              GestureDetector(
                onLongPress: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      barrierColor: Colors.transparent,
                      pageBuilder: (_, __, ___) => ProfileHeroPreviewScreen(
                        imageUrl: profile?.profileImage?.toString() ?? "",
                        username: profile?.name ?? "",
                        tag: "profile_${profile?.id}",
                      ),
                    ),
                  );
                },

                child: Hero(
                  tag: "profile_${profile?.id}",
                  child: Container(
                    width: 100.w,
                    height: 100.w,
                    padding: EdgeInsets.all(5.sp),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.grayEDF1F4, width: 2.w),
                    ),
                    child: CommonProfileImage(imageUrl: profileImageUrl, width: 120.w, height: 120.w),
                  ),
                ),
              ),
              // Verification Badge
              isVerified == true
                  ? Positioned(
                      bottom: 5.h,
                      left: 65.w,
                      child: Assets.icons.icVerifyBadge.svg(width: 30.w, height: 30.w),
                    )
                  : Container(),
              Positioned(
                bottom: 0.h,
                right: 60.w,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: .center,
                  children: [
                    _buildStatItem(
                      count: followersCount,
                      label: 'Audience',
                      onTap: () {
                        final id = profile?.id;
                        if (id != null) {
                          Get.to(() => const FollowingListView(), arguments: {'userId': id, 'listType': 'followers'});
                        }
                      },
                    ),
                    Gap(24.w),
                    _buildStatItem(
                      count: followingCount,
                      label: 'Following',
                      onTap: () {
                        final id = profile?.id;
                        if (id != null) {
                          Get.to(() => const FollowingListView(), arguments: {'userId': id, 'listType': 'following'});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Profile details
        Container(
          margin: EdgeInsets.only(top: 200.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyles.bold(26.sp, fontColor: AppColors.black2F3039),
              ),
              // Gap(6.h),
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.start,
              //   children: [
              //     Text('$postCount Post', style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039)),
              //     Padding(
              //       padding: EdgeInsets.symmetric(horizontal: 4.w),
              //       child: Container(
              //         width: 6.w,
              //         height: 6.w,
              //         decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.grayC4C4C4),
              //       ),
              //     ),
              //     InkWell(
              //       onTap: () {
              //         final id = profile?.id;
              //         if (id != null && id.isNotEmpty) {
              //           Get.to(
              //             () => const FollowingListView(),
              //             arguments: {'userId': id, 'listType': 'followers', 'username': username},
              //           );
              //         }
              //       },
              //       child: Text(
              //         '$followersCount Audience',
              //         style: TextStyles.medium(
              //           14.sp,
              //           fontColor: AppColors.black2F3039,
              //           textDecoration: TextDecoration.underline,
              //           decorationsColor: AppColors.black2F3039,
              //         ),
              //       ),
              //     ),
              //     Padding(
              //       padding: EdgeInsets.symmetric(horizontal: 4.w),
              //       child: Container(
              //         width: 6.w,
              //         height: 6.w,
              //         decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.grayC4C4C4),
              //       ),
              //     ),
              //     InkWell(
              //       onTap: () {
              //         final id = profile?.id;
              //         if (id != null && id.isNotEmpty) {
              //           Get.to(
              //             () => const FollowingListView(),
              //             arguments: {'userId': id, 'listType': 'following', 'username': username},
              //           );
              //         }
              //       },
              //       child: Text(
              //         '$followingCount Following',
              //         style: TextStyles.medium(
              //           14.sp,
              //           fontColor: AppColors.black2F3039,
              //           textDecoration: TextDecoration.underline,
              //           decorationsColor: AppColors.black2F3039,
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
              // Gap(8.h),
              if (bio.isNotEmpty)
                ExpandableText(
                  text: profile?.bio ?? '',
                  style: TextStyles.medium(15.sp, fontColor: AppColors.gray707070),
                ),
              if (_isOtherUser(profile)) ...[
                Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: Obx(() {
                        final isFollowing = _controller.isFollowing.value;
                        final loading = _controller.followActionLoading.value;
                        return PressScaleButton(
                          onTap: loading
                              ? null
                              : () {
                                  if (isFollowing) {
                                    UnfollowBottomSheet.show(controller: _controller);
                                  } else {
                                    _controller.followUser(
                                      onSuccess: () {},
                                      onError: (msg) {
                                        AppFunctions().showToast(msg, bgColor: AppColors.red);
                                      },
                                    );
                                  }
                                },
                          child: Container(
                            height: 40.h,
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              gradient: isFollowing
                                  ? null
                                  : LinearGradient(
                                      colors: const [AppColors.primaryColor, AppColors.primaryDark],
                                      stops: const [-0.0864, 0.798],
                                      transform: GradientRotation((320.33 - 90) * math.pi / 180),
                                    ),
                              color: isFollowing ? AppColors.grayEDF1F4 : null,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Center(
                              child: loading
                                  ? CommonLoader(size: 20, color: AppColors.white)
                                  : Text(
                                      isFollowing ? 'Following' : 'Follow',
                                      style: TextStyles.medium(
                                        16.sp,
                                        fontColor: isFollowing ? AppColors.black2F3039 : AppColors.whiteFFFFFF,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      }),
                    ),
                    Gap(10.w),
                    Expanded(
                      child: PressScaleButton(
                        onTap: () {
                          final chatModel = ChatModel(
                            id: '',
                            userId: profile?.id ?? '',
                            userName: profile?.name ?? 'Unknown',
                            userProfileImage: profile?.profileImage?.toString() ?? '',
                            lastMessage: '',
                            timestamp: '',
                            followers: profile?.followersCount ?? 0,
                            isVerifiedBeach: profile?.isVerifiedBadge ?? false,
                          );

                          Get.toNamed(AppRoutes.chatDetails, arguments: {'chat': chatModel, 'isRequest': false});
                        },
                        child: Container(
                          height: 40.h,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: AppColors.grayEDF1F4,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Center(
                            child: Text('Message', style: TextStyles.medium(16.sp, fontColor: AppColors.black2F3039)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              Gap(12.h),
            ],
          ),
        ),
      ],
    );
  }
}

// Separate widget for filter bar to prevent unnecessary rebuilds
class _ProfileFilterBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabTapped;

  const _ProfileFilterBar({required this.selectedIndex, required this.onTabTapped});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        border: Border(bottom: BorderSide(color: AppColors.whiteEAEAEA, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _ProfileFilterIcon(
              icon: Assets.icons.icSavePost,
              index: 0,
              isSelected: selectedIndex == 0,
              onTap: () => onTabTapped(0),
            ),
          ),
          Expanded(
            child: _ProfileFilterIcon(
              icon: Assets.icons.icSaveZeals,
              index: 1,
              isSelected: selectedIndex == 1,
              onTap: () => onTabTapped(1),
            ),
          ),
          Expanded(
            child: _ProfileFilterIcon(
              icon: Assets.icons.icSaveWrite,
              index: 2,
              isSelected: selectedIndex == 2,
              onTap: () => onTabTapped(2),
            ),
          ),
          Expanded(
            child: _ProfileFilterIcon(
              icon: Assets.icons.icSavePolls,
              index: 3,
              isSelected: selectedIndex == 3,
              onTap: () => onTabTapped(3),
            ),
          ),
          Expanded(
            child: _ProfileFilterIcon(
              icon: Assets.icons.icPostTag,
              index: 4,
              isSelected: selectedIndex == 4,
              onTap: () => onTabTapped(4),
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget for filter icon to optimize rebuilds
class _ProfileFilterIcon extends StatelessWidget {
  final SvgGenImage icon;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileFilterIcon({required this.icon, required this.index, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? AppColors.black000000 : Colors.transparent, width: 2)),
        ),
        child: icon.svg(
          colorFilter: ColorFilter.mode(isSelected ? AppColors.black000000 : AppColors.greyC4CACE, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _OtherUserZealThumbnail extends StatelessWidget {
  final PostData post;
  final VoidCallback? onTap;

  const _OtherUserZealThumbnail({required this.post, this.onTap});

  String? get _thumbnailUrl {
    final images = post.images;
    if (images != null && images.isNotEmpty) return images.first;
    if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty) return post.thumbnailUrl;
    if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) return post.mediaUrl;
    final videos = post.videos;
    if (videos != null && videos.isNotEmpty) return videos.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _thumbnailUrl != null
                ? CommonNetworkImage(
                    imageUrl: _thumbnailUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 250,
                    memCacheHeight: null,
                  )
                : Container(
                    color: AppColors.grayEDF1F4,
                    child: Assets.icons.icImgPlaceholder.image(fit: BoxFit.cover),
                  ),
            Positioned(top: 8.h, right: 8.w, child: Assets.icons.icZealsFill.svg()),
          ],
        ),
      ),
    );
  }
}

// Grid item used by OtherUserPostTabView
class _OtherUserSquareGridItem extends StatelessWidget {
  final PostData post;
  final bool showFlameIcon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _OtherUserSquareGridItem({
    super.key,
    required this.post,
    required this.onTap,
    this.onLongPress,
    this.showFlameIcon = false,
  });

  String? get _thumbnailUrl {
    final images = post.images;
    if (images != null && images.isNotEmpty) return images.first;
    if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty) return post.thumbnailUrl;
    if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) return post.mediaUrl;
    final videos = post.videos;
    if (videos != null && videos.isNotEmpty) return videos.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _thumbnailUrl != null
              ? CommonNetworkImage(
                  imageUrl: _thumbnailUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 250,
                  memCacheHeight: null,
                )
              : Container(
                  color: AppColors.grayEDF1F4,
                  child: Assets.icons.icImgPlaceholder.image(fit: BoxFit.cover),
                ),
          if (showFlameIcon) Positioned(top: 8.h, right: 8.w, child: Assets.icons.icZealsFill.svg()),
        ],
      ),
    );
  }
}

double getExtraScrollHeight(BuildContext context, int itemCount, int size) {
  final screenWidth = MediaQuery.sizeOf(context).width;

  const crossAxisCount = 3;
  const aspectRatio = 0.8;

  final crossSpacing = 2.w;
  final mainSpacing = 2.w;

  final totalCrossSpacing = crossSpacing * (crossAxisCount - 1);

  final itemWidth = (screenWidth - totalCrossSpacing) / crossAxisCount;

  final itemHeight = itemWidth / aspectRatio;

  final currentRows = (itemCount / crossAxisCount).ceil();

  const minRowsToFill = 5;

  if (currentRows >= minRowsToFill) return 0;

  final missingRows = minRowsToFill - currentRows;

  final extraHeight = (missingRows * itemHeight) + (missingRows * mainSpacing);

  return extraHeight + size;
}

class _OtherUserPostLongPressPreviewOverlay extends StatefulWidget {
  const _OtherUserPostLongPressPreviewOverlay({
    required this.controller,
    required this.fromRect,
    required this.imageUrl,
    required this.authorName,
    required this.timeAgo,
    this.profileImageUrl,
    required this.mediaAspectRatio,
    required this.onDismiss,
  });

  final AnimationController controller;
  final Rect fromRect;
  final String imageUrl;
  final String authorName;
  final String timeAgo;
  final String? profileImageUrl;
  final double mediaAspectRatio; // width / height
  final VoidCallback onDismiss;

  @override
  State<_OtherUserPostLongPressPreviewOverlay> createState() => _OtherUserPostLongPressPreviewOverlayState();
}

class _OtherUserPostLongPressPreviewOverlayState extends State<_OtherUserPostLongPressPreviewOverlay> {
  Offset _dragOffset = Offset.zero;

  Rect _targetRect(Size screen, EdgeInsets padding) {
    final maxW = screen.width - 24.w;
    final maxH = screen.height - padding.top - padding.bottom - 90.h;

    final headerH = 56.h;
    final ar = widget.mediaAspectRatio <= 0 ? 1.0 : widget.mediaAspectRatio;

    double cardW = maxW;
    double mediaH = cardW / ar;
    double cardH = headerH + mediaH;

    if (cardH > maxH) {
      final scale = maxH / cardH;
      cardW *= scale;
      mediaH = cardW / ar;
      cardH = headerH + mediaH;
    }

    final left = (screen.width - cardW) / 2;
    final top = padding.top + (screen.height - padding.top - padding.bottom - cardH) / 2;
    return Rect.fromLTWH(left, top, cardW, cardH);
  }

  double _dragProgress() {
    final d = _dragOffset.distance;
    return (d / 140.0).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rectTween = RectTween(begin: widget.fromRect, end: _targetRect(screen, padding));
    final ease = CurvedAnimation(
      parent: widget.controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: ease,
        builder: (context, _) {
          final t = ease.value;
          final rect = rectTween.lerp(t)!;
          final dragT = _dragProgress();
          final blurSigma = lerpDouble(0, 14, t)! * (1 - dragT);
          final dimOpacity = lerpDouble(0.0, isDark ? 0.55 : 0.35, t)! * (1 - dragT);
          final scale = lerpDouble(0.96, 1.0, t)! * (1 - (dragT * 0.06));

          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                onPanUpdate: (d) {
                  setState(() => _dragOffset += d.delta);
                },
                onPanEnd: (_) {
                  if (_dragOffset.distance > 90) {
                    widget.onDismiss();
                  } else {
                    setState(() => _dragOffset = Offset.zero);
                  }
                },
                onPanCancel: () {
                  setState(() => _dragOffset = Offset.zero);
                },
                child: Stack(
                  children: [
                    if (blurSigma > 0)
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                        child: const SizedBox.expand(),
                      ),
                    Container(color: Colors.black.withValues(alpha: dimOpacity)),
                  ],
                ),
              ),
              Positioned(
                left: rect.left + _dragOffset.dx,
                top: rect.top + _dragOffset.dy,
                width: rect.width,
                height: rect.height,
                child: Transform.scale(
                  scale: scale,
                  child: RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: ColoredBox(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 56.h,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                                  child: Row(
                                    children: [
                                      CommonProfileImage(imageUrl: widget.profileImageUrl, width: 32.w, height: 32.w),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.authorName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyles.semiBold(14.sp, fontColor: AppColors.black2F3039),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              widget.timeAgo,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyles.regular(12.sp, fontColor: AppColors.gray707070),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return CommonNetworkImage(
                                      imageUrl: widget.imageUrl,
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 1400,
                                      memCacheHeight: 1400,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// SliverPersistentHeader delegate for the tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => 48.h;

  @override
  double get maxExtent => 48.h;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
