import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:shimmer/shimmer.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/models/user_profile_response_model.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/core/widgets/common_post_detail_widget.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/core/widgets/common_write_post_item.dart';
import 'package:omeeba_new/core/widgets/poll_card.dart';
import 'package:omeeba_new/presentation/main/dashboard/controller/dashboard_controller.dart';
import 'package:omeeba_new/presentation/main/home/widgets/share_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/myprofile/controller/my_profile_controller.dart';
import 'package:omeeba_new/presentation/main/myprofile/widgets/my_profile_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/explore_grid_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/explore_list_shimmer.dart';
import 'package:omeeba_new/presentation/main/explore/widgets/poll_list_shimmer.dart';
import 'package:omeeba_new/presentation/main/zeals/views/zeal_detail_screen.dart';
import 'package:omeeba_new/presentation/main/zeals/widget/comments_bottom_sheet.dart';

import '../../../../core/helper/like_helper.dart';
import '../../report/controller/report_controller.dart';
import '../../report/view/report_bottom_sheet.dart';
import '../widgets/edit_profile_bottom_sheet.dart';
import '../widgets/following_list_view.dart';

class MyProfileView extends StatefulWidget {
  const MyProfileView({super.key});

  @override
  State<MyProfileView> createState() => _MyProfileViewState();
}

class _MyProfileViewState extends State<MyProfileView> with TickerProviderStateMixin {
  int _selectedContentTab = 0; // 0: Posts, 1: Zeals, 2: Writes, 3: Polls, 4: Tagged
  final ScrollController _scrollController = ScrollController();
  MyProfileController? _controller;

  OverlayEntry? _postPreviewEntry;
  AnimationController? _postPreviewController;
  bool _suppressGridTap = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (Get.isRegistered<MyProfileController>()) {
      _controller = Get.find<MyProfileController>();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Get.isRegistered<MyProfileController>()) {
        setState(() => _controller = Get.find<MyProfileController>());
      }
    });
  }

  @override
  void dispose() {
    _removePostPreview(immediate: true);
    _postPreviewController?.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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

  void _releaseTapSuppressionSoon() {
    // Prevent accidental navigation right after dismiss.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _suppressGridTap = false;
    });
  }

  void _handleGridPostTap(PostData post, int index, String? heroTagPrefix) {
    if (_suppressGridTap || _postPreviewEntry != null) return;
    _navigateToPostDetail(post, index, heroTagPrefix);
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
        return _PostLongPressPreviewOverlay(
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
    final c = _controller;
    if (c == null || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      switch (_selectedContentTab) {
        case 0:
          c.loadMoreMyPosts();
          break;
        case 1:
          c.loadMoreMyZeals();
          break;
        case 2:
          c.loadMoreMyWrites();
          break;
        case 3:
          c.loadMoreMyPolls();
          break;
        case 4:
          c.loadMoreMyTagged();
          break;
      }
    }
  }

  void _onTabTapped(int index) {
    if (_selectedContentTab == index) return;
    setState(() => _selectedContentTab = index);
    _controller?.loadTabIfNeeded(index);
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

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const MyProfileShimmer();
    }

    return Obx(() {
      c.bookmarkRefreshTrigger.value; // force rebuild on save/unsave
      if (c.isLoading.value && !c.hasLoadedOnce.value) {
        return const MyProfileShimmer();
      }

      final profile = c.profile.value;

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
              onRefresh: () => c.refreshProfileAndCurrentTab(_selectedContentTab),
              color: AppColors.primaryColor,
              child: CustomScrollView(
                controller: _scrollController,
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildProfileHeader(profile)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      child: _ProfileFilterBar(selectedIndex: _selectedContentTab, onTabTapped: _onTabTapped),
                    ),
                  ),
                  ..._buildCurrentTabSlivers(c),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildCurrentTabSlivers(MyProfileController c) {
    switch (_selectedContentTab) {
      case 0:
        return _buildPostsSlivers(c);
      case 1:
        return _buildZealsSlivers(c);
      case 2:
        return _buildWritesSlivers(c);
      case 3:
        return _buildPollsSlivers(c);
      case 4:
        return _buildTaggedSlivers(c);
      default:
        return _buildPostsSlivers(c);
    }
  }

  /*  List<Widget> _buildPostsSlivers(MyProfileController c) {
    final isLoading = c.myPostsLoading.value;
    final posts = c.myPostsData.value?.posts ?? [];
    final showShimmer = isLoading && posts.isEmpty;
    if (showShimmer) {
      return [const SliverToBoxAdapter(child: ExploreGridShimmer())];
    }
    if (!isLoading && posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _emptyState(
            icon: Assets.icons.icPostPlaceholder.svg(),
            message: 'Create your first post',
            subtitle: 'Create Your First Post',
          ),
        ),
      ];
    }
    final loadMore = c.myPostsLoadMoreLoading.value;
    return [
      SliverPadding(
        padding: EdgeInsets.all(1.w),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2.w,
            mainAxisSpacing: 2.w,
            childAspectRatio: 0.9,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= posts.length) {
              return Center(
                child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final post = posts[index];
            final isZealPost = (post.contentType ?? '').toLowerCase().contains('zeal');
            return _ProfileSquareGridItem(
              post: post,
              showFlameIcon: isZealPost,
              onTap: () => _navigateToPostDetail(post),
            );
          }, childCount: posts.length + (loadMore ? 1 : 0)),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).size.height * 0.6)),
    ];
  }
  */

  List<Widget> _buildPostsSlivers(MyProfileController c) {
    final isLoading = c.myPostsLoading.value;
    final posts = c.myPostsData.value?.posts ?? [];
    final showShimmer = isLoading && posts.isEmpty;
    if (showShimmer) {
      return [const SliverToBoxAdapter(child: ExploreGridShimmer())];
    }
    if (!isLoading && posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: GestureDetector(
            onTap: () {
              Get.find<DashboardController>().changeIndex(2);
            },
            child: _emptyState(
              icon: Assets.icons.icPostPlaceholder.svg(),
              message: 'Create your first post',
              subtitle: 'Create Your First Post',
            ),
          ),
        ),
      ];
    }
    final loadMore = c.myPostsLoadMoreLoading.value;
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
            final isPostType = post.contentType == null || post.contentType == 'Post';
            final tileKey = GlobalKey();
            final heroPrefix = isPostType ? 'profile_post_$index' : null;
            return _ProfileSquareGridItem(
              key: tileKey,
              post: post,
              showFlameIcon: isZealPost,
              index: index,
              heroTagPrefix: heroPrefix,
              onTap: () => _handleGridPostTap(post, index, heroPrefix),
              onLongPress: () => _handleGridPostLongPressStart(tileKey, post),
              onLongPressEnd: null, // Instagram-style: stay open until tap outside
            );
          }, childCount: posts.length + (loadMore ? 1 : 0)),
        ),
      ),
  //    SliverToBoxAdapter(child: SizedBox(height: getExtraScrollHeight(context, posts.length, -115))),
    ];
  }

  /* List<Widget> _buildZealsSlivers(MyProfileController c) {
    final isLoading = c.myZealsLoading.value;
    final zeals = c.myZealsData.value?.posts ?? [];
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
    final loadMore = c.myZealsLoadMoreLoading.value;
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
            return _ZealThumbnail(
              post: zeals[index],
              onTap: () => Get.to(() => const ZealDetailScreen(), arguments: zeals[index]),
            );
          }, childCount: zeals.length + (loadMore ? 1 : 0)),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).size.height * 0.6)),
    ];
  }*/

  List<Widget> _buildZealsSlivers(MyProfileController c) {
    final isLoading = c.myZealsLoading.value;
    final zeals = c.myZealsData.value?.posts ?? [];
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
    final loadMore = c.myZealsLoadMoreLoading.value;
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
            return _ZealThumbnail(
              post: zeals[index],
              onTap: () {
                Get.to(() => ZealDetailScreen(), arguments: zeals[index])?.then((result) {
                  if (result is String) c.removeZealById(result);
                });
              },
            );
          }, childCount: zeals.length + (loadMore ? 1 : 0)),
        ),
      ),
  //    SliverToBoxAdapter(child: SizedBox(height: getExtraScrollHeightForZeal(context, zeals.length, 55))),
    ];
  }

  /*  List<Widget> _buildWritesSlivers(MyProfileController c) {
    final isLoading = c.myWritesLoading.value;
    final writes = c.myWritesData.value?.posts ?? [];
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
    final loadMore = c.myWritesLoadMoreLoading.value;
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
          final caption = post.caption ?? post.content ?? '';
          final lines = caption.isNotEmpty
              ? caption.split('\n').where((s) => s.trim().isNotEmpty).toList()
              : <String>[];
          return CommonWritePostItem(
            authorName: post.userId?.name ?? post.userId?.username ?? 'User',
            timeAgo: _timeAgo(post.createdAt),
            profileImageUrl: post.userId?.profileImage is String ? post.userId!.profileImage as String? : null,
            postTitle: lines.isNotEmpty ? lines.first : ' ',
            bulletPoints: lines.length > 1 ? lines.sublist(1) : lines,
            likesCount: post.likeCount ?? 0,
            commentsCount: post.commentCount ?? 0,
            isLiked: post.isLiked ?? false,

            isBookmarked: post.isSaved ?? false,
            onComment: () {
              CommentsBottomSheet.show(postId: post.id ?? '', commentsCount: 1, contentType: post.contentType ?? '');
            },

            onBookmark: () {
              c.saveUnSavePost(context, post.contentType ?? '', post.id ?? '', c.myWritesData, index);
            },
          );
        }, childCount: writes.length + (loadMore ? 1 : 0)),
      ),
    ];
  }*/

  List<Widget> _buildWritesSlivers(MyProfileController c) {
    final isLoading = c.myWritesLoading.value;
    final writes = c.myWritesData.value?.posts ?? [];
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
    final loadMore = c.myWritesLoadMoreLoading.value;
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
            onShare: () {
              ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
            },
            postData: post,
            isNavigation: false,
            isBookmarked: post.isSaved ?? false,
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
            onSave: () {
              c.saveUnSavePost(context, post.contentType ?? '', post.id ?? '', c.myWritesData, index);
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
              c.saveUnSavePost(context, post.contentType ?? '', post.id ?? '', c.myWritesData, index);
            },
            onDelete: () => c.removeWritePostById(post.id ?? ''),
          );
        }, childCount: writes.length + (loadMore ? 1 : 0)),
      ),
    ];
  }

  /*
  List<Widget> _buildPollsSlivers(MyProfileController c) {
    final isLoading = c.myPollsLoading.value;
    final polls = c.myPollsData.value?.posts ?? [];
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
    final loadMore = c.myPollsLoadMoreLoading.value;
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
          final pollQuestion = post.caption ?? post.content ?? 'Poll';
          final profileImageUrl = post.userId?.profileImage is String ? post.userId!.profileImage as String? : null;
          final pollOptions = post.options ?? [];
          final options = pollOptions.isEmpty
              ? [
            const PollOption(optionId: '', text: 'Option 1', percentage: 0, isSelected: false),
            const PollOption(optionId: '', text: 'Option 2', percentage: 0, isSelected: false),
          ]
              : pollOptions
              .map(
                (o) => PollOption(
              optionId: o.optionId ?? '',
              text: o.optionText ?? '',
              percentage: o.votePercentage ?? 0,
              isSelected: o.selectedByAuthUser == true,
            ),
          )
              .toList();
          return PollCard(
            key: ValueKey('myprofile_poll_${post.id}'),
            authorName: post.userId?.name ?? post.userId?.username ?? 'User',
            timeAgo: _timeAgo(post.createdAt),
            pollQuestion: pollQuestion,
            options: options,
            isSaved: post.isSaved ?? false,
            likesCount: post.likeCount ?? post.totalVotes ?? 0,
            commentsCount: post.commentCount ?? 0,
            hasVoted: post.displayHasVoted,
            votedOptionId: post.displayVotedOptionId,
            isExpired: post.isPollExpired,
            onOptionTap: (optionId) => c.submitPollVote(post.id!, optionId),
            profileImage: CommonProfileImage(imageUrl: profileImageUrl, width: 35.w, height: 35.h),
            onBookmark: () {
              c.saveUnSavePost(context, post.contentType?.capitalizeFirst ?? 'Poll', post.id ?? '', c.myPollsData, index);
            },
          );
        }, childCount: polls.length + (loadMore ? 1 : 0)),
      ),
    ];
  }
*/

  List<Widget> _buildPollsSlivers(MyProfileController c) {
    final isLoading = c.myPollsLoading.value;
    final polls = c.myPollsData.value?.posts ?? [];
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
    final loadMore = c.myPollsLoadMoreLoading.value;
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
            onCopyLink: () {
              Clipboard.setData(ClipboardData(text: post.shareableLink ?? "demo"));
            },
            onSave: () {
              c.saveUnSavePost(
                context,
                post.contentType?.capitalizeFirst ?? 'Poll',
                post.id ?? '',
                c.myPollsData,
                index,
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
            isSaved: post.isSaved ?? false,
            onBookmark: () {
              c.saveUnSavePost(
                context,
                post.contentType?.capitalizeFirst ?? 'Poll',
                post.id ?? '',
                c.myPollsData,
                index,
              );
            },
            onComment: () {
              CommentsBottomSheet.show(
                postId: post.id ?? '',
                commentsCount: post.commentCount ?? 1,
                contentType: post.contentType ?? 'Poll',
                onCommentAdded: (newCount) {
                  post.commentCount = newCount;
                  setState(() {});
                },
              );
            },

            onOptionTap: (optionId) => c.submitPollVote(post.id!, optionId),
            onDelete: () => c.removePollPostById(post.id ?? ''),
          );
        }, childCount: polls.length + (loadMore ? 1 : 0)),
      ),
    ];
  }

  /*  List<Widget> _buildTaggedSlivers(MyProfileController c) {
    final isLoading = c.myTaggedLoading.value;
    final tagged = c.myTaggedData.value?.posts ?? [];
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
    final loadMore = c.myTaggedLoadMoreLoading.value;
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
          return CommonPostDetailWidget(
            post: post,
            isBookmarked: post.isSaved ?? false,
            onComment: () {
              CommentsBottomSheet.show(postId: post.id ?? '', commentsCount: 1, contentType: post.contentType ?? '');
            },

            onBookmark: () {
              c.saveUnSavePost(context, post.contentType ?? '', post.id ?? '', c.myTaggedData, index);
            },
          );
        }, childCount: tagged.length + (loadMore ? 1 : 0)),
      ),
    ];
  }
  */

  List<Widget> _buildTaggedSlivers(MyProfileController c) {
    final isLoading = c.myTaggedLoading.value;
    final tagged = c.myTaggedData.value?.posts ?? [];
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
    final loadMore = c.myTaggedLoadMoreLoading.value;
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
          return _buildPostItem(post, index, c);
        }, childCount: tagged.length + (loadMore ? 1 : 0)),
      ),
    ];
  }

  Widget _emptyState({required Widget icon, required String message, String? subtitle}) {
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
        if (subtitle != null) ...[
          Gap(8.h),
          Text(subtitle, style: TextStyles.medium(15.sp, fontColor: AppColors.blue3382FF)),
        ],
      ],
    );
  }

  Widget _buildPostItem(PostData post, int index, MyProfileController controller) {
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
          controller.saveUnSavePost(
            context,
            post.contentType ?? 'Write Post',
            post.id ?? '',
            controller.myTaggedData,
            index,
          );
        },
        onBookmark: () {
          controller.saveUnSavePost(
            context,
            post.contentType?.capitalizeFirst ?? 'Write Post',
            post.id ?? '',
            controller.myTaggedData,
            index,
          );
        },
        onDelete: () => controller.removePostById(post.id ?? ''),
      );
    }

    // ── Poll ────────────────────────────────────────────────────────────────
    if (contentType == 'Poll') {
      return PollCard(
        key: ValueKey('explore_poll_${post.id}'),
        postData: post,
        isNavigation: true,
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
          controller.saveUnSavePost(
            context,
            post.contentType?.capitalizeFirst ?? 'Poll',
            post.id ?? '',
            controller.myTaggedData,
            index,
          );
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
        onOptionTap: (optionId) => controller.submitPollVote(post.id!, optionId),
        onBookmark: () {
          controller.saveUnSavePost(
            context,
            post.contentType?.capitalizeFirst ?? 'Poll',
            post.id ?? '',
            controller.myTaggedData,
            index,
          );
        },
        onShare: () {
          ShareBottomSheet.show(postId: post.id, postType: post.contentType, shareUrl: post.shareableLink);
        },
        onDelete: () => controller.removePostById(post.id ?? ''),
      );
    }

    // ── Default: Post / Zeal ────────────────────────────────────────────────
    return CommonPostDetailWidget(
      key: ValueKey('home_post_${post.id}_$index'),
      post: post,
      isNavigation: true,
      heroTagPrefix: 'home_post_$index',
      onBookmark: () {
        controller.saveUnSavePost(
          context,
          post.contentType?.capitalizeFirst ?? 'Post',
          post.id ?? '',
          controller.myTaggedData,
          index,
        );
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
        controller.saveUnSavePost(
          context,
          post.contentType?.capitalizeFirst ?? 'Post',
          post.id ?? '',
          controller.myTaggedData,
          index,
        );
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
      onReport: () {
        Get.find<ReportController>().reset();
        Get.find<ReportController>().getReportsCategories(context);
        ReportBottomSheet.show(postId: post.id ?? '', postType: post.contentType ?? 'Post');
      },
      onDelete: () {
        controller.removePostById(post.id ?? '');
      },
    );
  }

  /*void _navigateToPostDetail(PostData post) {
    if (_isZealWithVideo(post)) {
      Get.to(() =>   ZealDetailScreen(onReport: () {  },), arguments: post);
      return;
    }
    final c = _controller;
    final postId = post.id;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (modalContext) => Scaffold(
          backgroundColor: AppColors.whiteFFFFFF,
          appBar: AppBar(
            backgroundColor: AppColors.whiteFFFFFF,
            elevation: 0,
            leading: IconButton(
              icon: Assets.icons.icArrowBack.image(height: 20.h, width: 20.w),
              onPressed: () => Navigator.pop(modalContext),
            ),
          ),
          body: SingleChildScrollView(
            child: c == null
                ? CommonPostDetailWidget(
              post: post,
              onComment: () {
                CommentsBottomSheet.show(
                    postId: post.id ?? '', commentsCount: 1, contentType: post.contentType ?? '');
              },
              onShare: () {},
              onBookmark: () {},
              onSave: () {},
              onReport: () {},
              onCopyLink: () {},
              onDelete: () {},
            )
                : Obx(() {
              c.bookmarkRefreshTrigger.value;
              final postsList = c.myPostsData.value?.posts ?? [];
              final idx = postsList.indexWhere((p) => p.id == postId);
              final currentPost = idx >= 0 ? postsList[idx] : post;
              return CommonPostDetailWidget(
                post: currentPost,
                onLike: () {},
                onComment: () {
                  CommentsBottomSheet.show(
                      postId: currentPost.id ?? '', commentsCount: 1,
                      contentType: currentPost.contentType ?? '');
                },
                onShare: () {},
                onBookmark: () {
                  if (idx >= 0) {
                    c.saveUnSavePost(
                        modalContext, currentPost.contentType ?? '', currentPost.id ?? '', c.myPostsData, idx);
                  }
                },
                onSave: () {},
                onReport: () {},
                onCopyLink: () {},
                onDelete: () {},
              );
            }),
          ),
        ),
      ),
    );
  }*/

  void _navigateToPostDetail(PostData post, [int? index, String? heroTagPrefix]) {
    final c = _controller;
    Get.toNamed(
      AppRoutes.postContentDetail,
      arguments: {'post': post, if (heroTagPrefix != null && heroTagPrefix.isNotEmpty) 'heroTagPrefix': heroTagPrefix},
    )?.then((result) {
      if (result is String && c != null) {
        c.removePostById(result);
        c.removeTaggedPostById(result);
      }
    });
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

  Widget _buildProfileHeader(Profile? profile) {
    final coverUrl = profile?.coverImage?.toString();
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;

    return Stack(
      children: [
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
                    // Use Image + BoxFit.cover via imageBuilder (no mem-cache resize).
                    // Resizing decode dimensions often stretches; uniform scale fills the banner.
                    return ClipRect(
                      child: hasCover
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
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
              // Username overlay on banner
              Positioned(
                top: 16.h,
                left: 16.w,
                bottom: 16.h,
                child: SizedBox(
                  width: 180.w,
                  child: Text(
                    profile?.username ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.semiBold(20.sp, fontColor: AppColors.whiteFFFFFF),
                  ),
                ),
              ),
              // Edit and Settings icons
              Positioned(
                right: 16.w,
                top: 16.h,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PressScaleButton(
                      onTap: () {
                        if (profile != null) {
                          EditProfileBottomSheet.show(
                            initialName: profile.name ?? '',
                            initialUsername: profile.username ?? '',
                            initialBio: profile.bio ?? '',
                            initialCoverImageUrl: profile.coverImage?.toString(),
                            initialProfileImageUrl: profile.profileImage?.toString(),
                            isVerifiedBadge: profile.isVerifiedBadge ?? false,
                          );
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                        child: Assets.icons.icEdit.svg(width: 16.w, height: 16.w),
                      ),
                    ),
                    Gap(12.w),
                    PressScaleButton(
                      onTap: () {
                        Get.toNamed(AppRoutes.setting);
                      },
                      child: Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                        child: Assets.icons.icSetting.svg(width: 16.w, height: 16.w),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                      boxShadow: [],
                    ),
                    child: CommonProfileImage(imageUrl: profile?.profileImage?.toString(), width: 120.w, height: 120.w),
                  ),
                ),
              ),
              // Verification Badge
              profile?.isVerifiedBadge == true
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
                      count: profile?.followersCount ?? 0,
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
                      count: profile?.followingCount ?? 0,
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

        // Profile Details Section
        Container(
          margin: EdgeInsets.only(top: 200.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              // Full Name
              Text(
                profile?.name ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.bold(18.sp, fontColor: AppColors.black2F3039),
              ),
              // Gap(6.h),
              // // Stats
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.start,
              //   children: [
              //     Text(
              //       '${profile?.contentCounts?.posts ?? 0} Post',
              //       style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039),
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
              //             arguments: {'userId': id, 'listType': 'followers', 'username': profile?.username},
              //           );
              //         }
              //       },
              //       child: Text(
              //         '${profile?.followersCount ?? 0} Audience',
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
              //             arguments: {'userId': id, 'listType': 'following', 'username': profile?.username},
              //           );
              //         }
              //       },
              //       child: Text(
              //         '${profile?.followingCount ?? 0} Following',
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
              // Bio
              ExpandableText(
                text: profile?.bio ?? '',
                style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070),
              ),

              Gap(22.h),
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

class _ProfileSquareGridItem extends StatelessWidget {
  final PostData post;
  final bool showFlameIcon;
  final int index;
  final String? heroTagPrefix;
  final VoidCallback onTap;
  final VoidCallback? onLongPressEnd;
  final VoidCallback? onLongPress;

  const _ProfileSquareGridItem({
    super.key,
    required this.post,
    required this.onTap,
    required this.index,
    this.heroTagPrefix,
    this.showFlameIcon = false,
    this.onLongPressEnd,
    this.onLongPress,
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
    final imageTag = heroTagPrefix != null ? '${heroTagPrefix!}_image_0' : null;
    final imageWidget = _thumbnailUrl != null
        ? CommonNetworkImage(imageUrl: _thumbnailUrl!, fit: BoxFit.cover, memCacheWidth: 250, memCacheHeight: null)
        : Container(
            color: AppColors.grayEDF1F4,
            child: Assets.icons.icImgPlaceholder.image(fit: BoxFit.cover),
          );
    return GestureDetector(
      onTap: onTap,
      // Use onLongPress (gesture arena resolves) to prevent accidental onTap on release.
      onLongPress: onLongPress,
      onLongPressEnd: onLongPressEnd != null ? (_) => onLongPressEnd!.call() : null,
      onLongPressCancel: onLongPressEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageTag != null ? Hero(tag: imageTag, child: imageWidget) : imageWidget,
          if (showFlameIcon) Positioned(top: 8.h, right: 8.w, child: Assets.icons.icZealsFill.svg()),
        ],
      ),
    );
  }
}

double getExtraScrollHeightForZeal(BuildContext context, int itemCount, int size) {
  final screenWidth = MediaQuery.sizeOf(context).width;

  const crossAxisCount = 3;
  const aspectRatio = 0.7;

  final crossSpacing = 3.w;
  final mainSpacing = 3.w;

  final totalCrossSpacing = crossSpacing * (crossAxisCount - 1);

  final itemWidth = (screenWidth - totalCrossSpacing) / crossAxisCount;
  final itemHeight = itemWidth / aspectRatio;

  final currentRows = (itemCount / crossAxisCount).ceil();

  const minRowsToFill = 4;

  if (currentRows >= minRowsToFill) return 0;

  final missingRows = minRowsToFill - currentRows;

  final extraHeight = (missingRows * itemHeight) + (missingRows * mainSpacing);

  return extraHeight - size.h;
}

class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ExpandableText({super.key, required this.text, required this.style});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool isExpanded = false;
  bool isOverflowing = false;

  @override
  Widget build(BuildContext context) {
    final textSpan = TextSpan(text: widget.text, style: widget.style);

    final tp = TextPainter(text: textSpan, maxLines: 3, textDirection: TextDirection.ltr)
      ..layout(maxWidth: MediaQuery.of(context).size.width);

    isOverflowing = tp.didExceedMaxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: isExpanded ? null : 6,
          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: widget.style,
        ),

        if (isOverflowing)
          GestureDetector(
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                isExpanded ? "Read less" : "Read more",
                style: TextStyle(color: AppColors.primaryColor, fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ),
      ],
    );
  }
}

class _PostLongPressPreviewOverlay extends StatefulWidget {
  const _PostLongPressPreviewOverlay({
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
  State<_PostLongPressPreviewOverlay> createState() => _PostLongPressPreviewOverlayState();
}

class _PostLongPressPreviewOverlayState extends State<_PostLongPressPreviewOverlay> {
  Offset _dragOffset = Offset.zero;

  Rect _targetRect(Size screen, EdgeInsets padding) {
    final maxW = screen.width - 24.w;
    final maxH = screen.height - padding.top - padding.bottom - 90.h;

    // Card = header + media. Let the card size adapt to media aspect ratio.
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
            alignment: AlignmentGeometry.center,
            children: [
              // Dismiss area (release or tap outside)
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

              // Preview card animating from tile to center
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
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                child: Row(
                                  children: [
                                    CommonProfileImage(imageUrl: widget.profileImageUrl, width: 32.w, height: 32.w),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
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
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Force exact sizing so the image truly covers
                                    // the entire media region (no white strip).
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

double mathMin(double a, double b) => a < b ? a : b;

class _ZealThumbnail extends StatelessWidget {
  final PostData post;
  final VoidCallback? onTap;

  const _ZealThumbnail({required this.post, this.onTap});

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

class ProfileHeroPreviewScreen extends StatefulWidget {
  final String imageUrl;
  final String username;
  final String tag;

  const ProfileHeroPreviewScreen({super.key, required this.imageUrl, required this.username, required this.tag});

  @override
  State<ProfileHeroPreviewScreen> createState() => _ProfileHeroPreviewScreenState();
}

class _ProfileHeroPreviewScreenState extends State<ProfileHeroPreviewScreen> {
  Offset _dragOffset = Offset.zero;

  double get _dragProgress => (_dragOffset.distance / 150).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final dragT = _dragProgress;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        onPanUpdate: (d) {
          setState(() => _dragOffset += d.delta);
        },
        onPanEnd: (_) {
          if (_dragOffset.distance > 100) {
            Navigator.pop(context);
          } else {
            setState(() => _dragOffset = Offset.zero);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Blur Background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20 * (1 - dragT), sigmaY: 20 * (1 - dragT)),
              child: Container(color: AppColors.black000000.withOpacity(0.5 * (1 - dragT))),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12.h,
              right: 16.w,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(color: AppColors.black000000.withOpacity(0.4), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
            // Hero Animated Profile
            Transform.translate(
              offset: _dragOffset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: widget.tag,
                    child: Container(
                      width: 220.w,
                      height: 220.w,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(
                        child: CommonProfileImage(imageUrl: widget.imageUrl, width: 220.w, height: 220.w),
                      ),
                    ),
                  ),

                  SizedBox(height: 12.h),

                  Text(widget.username, style: TextStyles.semiBold(25.sp, fontColor: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
