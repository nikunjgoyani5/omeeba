import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/widgets/common_post_detail_widget.dart';
import 'package:omeeba_new/core/widgets/common_write_post_item.dart';
import 'package:omeeba_new/core/widgets/press_scale_button.dart';
import 'package:omeeba_new/core/widgets/poll_card.dart';
import 'package:omeeba_new/presentation/main/chat/views/chat_screen.dart';
import 'package:omeeba_new/presentation/main/zeals/widget/comments_bottom_sheet.dart';
import '../../../../core/helper/like_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_prefrence.dart';
import '../../../../gen/assets.gen.dart';
import '../../report/controller/report_controller.dart';
import '../../report/view/report_bottom_sheet.dart';
import '../widgets/share_bottom_sheet.dart';
import '../../dashboard/controller/dashboard_controller.dart';
import '../controller/home_controller.dart';
import '../widgets/animated_search_field.dart';
import '../widgets/home_feed_shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const int _homeTabIndex = 0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  late final HomeController controller;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasDisconnected = false;
  bool _isAppInForeground = true;
  Timer? _connectivityDebounce;
  static const _connectivityDebounceDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeController>();
    _scrollController.addListener(_onScroll);
    controller.registerHomeTabReselectCallback(_handleHomeTabReselected);
    WidgetsBinding.instance.addObserver(this);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection =
          results.isNotEmpty &&
          results.any(
            (r) =>
                r == ConnectivityResult.wifi ||
                r == ConnectivityResult.mobile ||
                r == ConnectivityResult.ethernet,
          );
      if (hasConnection && _wasDisconnected) {
        _wasDisconnected = false;
        _connectivityDebounce?.cancel();
        _connectivityDebounce = Timer(_connectivityDebounceDuration, () {
          if (!mounted) return;
          if (!_isAppInForeground) return;
          final dashboard = Get.find<DashboardController>();
          if (dashboard.currentIndex.value != _homeTabIndex) return;
          if (controller.isLoading.value) return;
          _refreshKey.currentState?.show();
        });
      } else if (!hasConnection) {
        _wasDisconnected = true;
        _connectivityDebounce?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _connectivityDebounce?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isAppInForeground = false;
    } else if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    controller.onScroll(offset, maxScrollExtent);
  }

  /// Called when the Home tab in the bottom navigation is tapped while the
  /// user is already on Home. Scrolls the feed to the top and triggers a
  /// pull‑to‑refresh, mimicking Instagram's behaviour.
  void _handleHomeTabReselected() {
    if (!mounted) return;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    // Give the scroll animation a brief moment, then show the refresh indicator.
    if (!controller.isLoading.value) {
      Future.delayed(const Duration(milliseconds: 360), () {
        if (!mounted) return;
        _refreshKey.currentState?.show();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final expandedAppBarHeight = 150.h;
    final collapsedAppBarHeight = 70.h;

    return Scaffold(
      backgroundColor: AppColors.grayEDF1F4,
      body: Stack(
        children: [
          Obx(() {
            final posts = controller.feedData.value?.posts ?? [];
            final isInitialLoadShimmer =
                posts.isEmpty &&
                controller.hasTriedInitialLoad.value &&
                controller.isLoading.value;
            final isEmptyState =
                posts.isEmpty &&
                !controller.hasTriedInitialLoad.value &&
                !controller.isLoading.value;
            final isRefreshing = controller.isLoading.value && posts.isNotEmpty;

            final refreshChild = ListView.builder(
              controller: _scrollController,
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: expandedAppBarHeight + statusBarHeight,
                bottom: isInitialLoadShimmer ? 0 : 80.h,
              ),
              itemCount: () {
                if (isInitialLoadShimmer) return 5;
                if (isEmptyState) return 1;
                int count = posts.length;
                if (isRefreshing) count += 1; // top shimmer
                if (controller.isLoadMoreLoading.value) {
                  count += 1; // bottom loader
                }
                return count;
              }(),
              itemBuilder: (context, index) {
                // Initial: only shimmer items
                if (isInitialLoadShimmer) {
                  return const HomeFeedShimmer();
                }

                // Empty state: show a friendly placeholder instead of nothing.
                if (isEmptyState) {
                  return _buildEmptyFeedState(context);
                }

                // Top shimmer while refreshing
                if (isRefreshing) {
                  return const HomeFeedShimmer();
                }

                final topOffset = isRefreshing ? 1 : 0;
                final adjustedIndex = index - topOffset;

                // Bottom loader
                if (controller.isLoadMoreLoading.value &&
                    adjustedIndex >= posts.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Center(
                      child: SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (adjustedIndex < 0 || adjustedIndex >= posts.length) {
                  return const SizedBox.shrink();
                }

                final post = posts[adjustedIndex];
                return GestureDetector(
                  // onTap: () => _openPostDetail(post, adjustedIndex),
                  child: _buildPostItem(post, adjustedIndex),
                );
              },
            );

            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: RefreshIndicator(
                key: _refreshKey,
                onRefresh: controller.onRefresh,
                color: AppColors.primaryColor,
                edgeOffset: expandedAppBarHeight + statusBarHeight,
                child: refreshChild,
              ),
            );
          }),
          Obx(
            () => _buildCustomAppBar(
              context,
              statusBarHeight,
              expandedAppBarHeight,
              collapsedAppBarHeight,
            ),
          ),
          Obx(() {
            final offset = controller.scrollOffset.value;
            final scrollProgress = (offset / 50.0).clamp(0.0, 1.0);
            final hideSearch =
                controller.showSearchButton.value && offset > 0.0;

            final screenWidth = MediaQuery.of(context).size.width;
            final searchFieldWidthExpanded = screenWidth - 32.w;
            final searchFieldWidthCollapsed = 240.w;
            final currentSearchFieldWidth =
                searchFieldWidthExpanded -
                (searchFieldWidthExpanded - searchFieldWidthCollapsed) *
                    scrollProgress;
            final statusBarHeight = MediaQuery.of(context).padding.top;
            final expandedAppBarHeight = 150.h;
            final collapsedAppBarHeight = 70.h;
            final currentAppBarHeight =
                expandedAppBarHeight -
                (expandedAppBarHeight - collapsedAppBarHeight) * scrollProgress;
            final searchFieldHeight = 25.h;
            final searchFieldTop =
                statusBarHeight +
                (currentAppBarHeight / 2) -
                (searchFieldHeight / 2) +
                8.h;
            final searchFieldLeft =
                (screenWidth / 2) - (currentSearchFieldWidth / 2);

            return Positioned(
              top: searchFieldTop,
              left: searchFieldLeft,
              right: searchFieldLeft,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                opacity: hideSearch ? 0.0 : 1.0,
                child: Material(
                  type: MaterialType.transparency,
                  child: PressScaleButton(
                    onTap: () => Get.toNamed(AppRoutes.explore),
                    child: Hero(
                      tag: "search_field",
                      child: Material(
                        type: MaterialType.transparency,
                        child: AnimatedSearchField(
                          isScrolled: controller.isScrolled.value,
                          scrollProgress: scrollProgress,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Intentionally not wired to taps in this screen right now.
  // ignore: unused_element
  void _openPostDetail(PostData post, int index) {
    final isPostType = post.contentType == null || post.contentType == 'Post';
    Get.toNamed(
      AppRoutes.postContentDetail,
      arguments: {
        'post': post,
        if (isPostType) 'heroTagPrefix': 'home_post_$index',
      },
    )?.then((result) {
      if (result is String) controller.removePostById(result);
    });
  }

  Widget _buildEmptyFeedState(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 40.h),
      child: SizedBox(
        height: 380.h,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.post_add_outlined,
                size: 54.w,
                color: AppColors.black2F3039.withOpacity(0.45),
              ),
              SizedBox(height: 12.h),
              Text(
                'No posts yet',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black2F3039,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'When new posts appear, they will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.black2F3039.withOpacity(0.6),
                ),
              ),
              SizedBox(height: 22.h),
              TextButton.icon(
                onPressed: () async {
                  await controller.onRefresh();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostItem(PostData post, int index) {
    final contentType = post.contentType ?? '';

    // ── Write Post ──────────────────────────────────────────────────────────
    if (contentType == 'Write Post') {
      return CommonWritePostItem(
        key: ValueKey('home_write_${post.id}_$index'.toString()),
        postData: post,
        onReport: () async {
          Get.find<ReportController>().reset();
          Get.find<ReportController>().getReportsCategories(context);
          final success = await ReportBottomSheet.show(
            postId: post.id ?? '',
            postType: post.contentType ?? 'Post',
          );
          if (success == true) controller.removePostById(post.id ?? '');
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
          ShareBottomSheet.show(
            postId: post.id,
            postType: post.contentType,
            shareUrl: post.shareableLink,
          );
        },
        onComment: () {
          CommentsBottomSheet.show(
            postId: post.id ?? '',
            commentsCount: post.commentCount ?? 0,
            contentType: post.contentType ?? '',
            onCommentAdded: (newCount) {
              post.commentCount = newCount;
              controller.refreshFeedData();
            },
            onCommentRemove: (newCount) {
              post.commentCount = newCount;
              controller.refreshFeedData();
            },
          );
        },
        onSave: () {
          controller.saveUnSavePost(
            context,
            post.contentType ?? '',
            post.id ?? "",
            index,
          );
        },
        onBookmark: () {
          controller.saveUnSavePost(
            context,
            post.contentType ?? '',
            post.id ?? "",
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
        onLike: () {
          LikeHelper.toggleLike(
            contentId: post.id ?? '',
            contentType: post.contentType ?? 'Poll',
            isLiked: post.isLiked ?? false,
            likeCount: post.likeCount ?? 0,
            onLocalUpdate: (liked, count) {
              post.isLiked = liked;
              post.likeCount = count;
              controller.refreshFeedData();
            },
          );
        },
        onCopyLink: () {
          Clipboard.setData(ClipboardData(text: post.shareableLink ?? "demo"));
        },
        onSave: () {
          controller.saveUnSavePost(
            context,
            post.contentType?.capitalizeFirst ?? '',
            post.id ?? "",
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
              controller.refreshFeedData();
            },
            onCommentRemove: (newCount) {
              post.commentCount = newCount;
              controller.refreshFeedData();
            },
          );
        },
        hasVoted: post.displayHasVoted,
        votedOptionId: post.displayVotedOptionId,
        isExpired: post.isPollExpired,
        onReport: () async {
          Get.find<ReportController>().reset();
          Get.find<ReportController>().getReportsCategories(context);
          final success = await ReportBottomSheet.show(
            postId: post.id ?? '',
            postType: post.contentType ?? 'Poll',
          );
          if (success == true) controller.removePostById(post.id ?? '');
        },
        onOptionTap: (optionId) =>
            controller.submitPollVote(post.id!, optionId),
        onBookmark: () {
          controller.saveUnSavePost(
            context,
            post.contentType?.capitalizeFirst ?? '',
            post.id ?? "",
            index,
          );
        },
        onShare: () {
          ShareBottomSheet.show(
            postId: post.id,
            postType: post.contentType,
            shareUrl: post.shareableLink,
          );
        },
        onDelete: () => controller.removePostById(post.id ?? ''),
      );
    }
    String idd = post.userId?.id ?? "" ;
    bool isNavigation = idd == PrefService.getString(PrefKeys.userId) ;
    // ── Default: Post / Zeal ────────────────────────────────────────────────
    return CommonPostDetailWidget(
      key: ValueKey('home_post_${post.id}_$index'),
      post: post,
    //  isNavigation: !isNavigation,
      heroTagPrefix: 'home_post_$index',
      onBookmark: () {
        controller.saveUnSavePost(
          context,
          post.contentType ?? '',
          post.id ?? "",
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
            controller.refreshFeedData();
          },
          onCommentRemove: (newCount) {
            post.commentCount = newCount;
            controller.refreshFeedData();
          },
        );
      },
      onSave: () {
        controller.saveUnSavePost(
          context,
          post.contentType ?? '',
          post.id ?? "",
          index,
        );
      },

      onShare: () {
        ShareBottomSheet.show(
          postId: post.id,
          postType: post.contentType,
          shareUrl: post.shareableLink,
        );
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
      onReport: () async {
        Get.find<ReportController>().reset();
        Get.find<ReportController>().getReportsCategories(context);
        final success = await ReportBottomSheet.show(
          postId: post.id ?? '',
          postType: post.contentType ?? 'Post',
        );
        if (success == true) controller.removePostById(post.id ?? '');
      },
      onDelete: () {
        controller.removePostById(post.id ?? '');
      },
    );
  }

  Widget _buildCustomAppBar(
    BuildContext context,
    double statusBarHeight,
    double expandedAppBarHeight,
    double collapsedAppBarHeight,
  ) {
    final offset = controller.scrollOffset.value;
    final scrollProgress = (offset / 50.0).clamp(0.0, 1.0);

    // App icon & chat: show on scroll up, hide on scroll down, always visible at very top.
    double appBarVisibility;
    if (offset <= 5.0) {
      appBarVisibility = 1.0;
    } else if (controller.isScrollingUp.value) {
      appBarVisibility = 1.0;
    } else if (controller.isScrollingDown.value) {
      appBarVisibility = 0.0;
    } else {
      appBarVisibility = 1.0 - scrollProgress;
    }

    // When the main search field is hidden, we show a compact search icon
    // near the chat button so users can still tap to search.
    final hideSearch = controller.showSearchButton.value && offset > 0.0;

    // Icons animate to initial position when reappearing on scroll up (not stuck at very top).
    double positionProgress;
    if (offset <= 5.0) {
      positionProgress = scrollProgress;
    } else if (controller.isScrollingUp.value) {
      positionProgress = 0.0;
    } else {
      positionProgress = scrollProgress;
    }

    final currentAppBarHeight =
        expandedAppBarHeight -
        (expandedAppBarHeight - collapsedAppBarHeight) * scrollProgress;
    final logoTopPosition = statusBarHeight + 15.h - (30.h * positionProgress);
    final chatIconTopPosition =
        statusBarHeight + 15.h - (30.h * positionProgress);
    final logoOpacity = appBarVisibility;
    final chatIconOpacity = appBarVisibility;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: currentAppBarHeight + statusBarHeight,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  top: logoTopPosition,
                  left: 16.w,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: logoOpacity,
                    child: Assets.icons.icAppName.svg(height: 30.h),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  top: chatIconTopPosition,
                  right: 8.w,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: chatIconOpacity,
                    child: Obx(() {
                      final hasNewMessage = controller.hasNewMessage.value;
                      return PressScaleButton(
                        onTap: () {
                          Get.to(() => const ChatScreen())?.then((_) {
                            controller.clearNewMessageIndicator();
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.all(8.w),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Assets.icons.icChat.svg(),
                              if (hasNewMessage)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 10.w,
                                    height: 10.w,
                                    decoration: BoxDecoration(
                                      color: AppColors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.grayEDF1F4,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // Compact search icon that appears only when the main search
                // field is hidden (on scroll up away from the top).
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  top: chatIconTopPosition,
                  right: 48.w,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: hideSearch ? appBarVisibility : 0.0,
                    child: PressScaleButton(
                      onTap: () => Get.toNamed(AppRoutes.explore),
                      child: Padding(
                        padding: EdgeInsets.all(8.w),
                        child: Assets.icons.icSearch.svg(height: 25.h),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
