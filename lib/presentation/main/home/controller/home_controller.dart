import 'dart:async';
import 'package:omeeba_new/core/data/home/home_feed_local.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/home_repository.dart';
import 'package:omeeba_new/core/repository/post_repository.dart';
import 'package:omeeba_new/core/services/purchase_status_api_service.dart';
import 'package:omeeba_new/core/services/socket_service.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/utils/exports.dart';

class HomeController extends GetxController {
  final HomeRepository _repo = Get.find<HomeRepository>();
  final HomeFeedLocal _local = Get.find<HomeFeedLocal>();

  final RxDouble scrollOffset = 0.0.obs;
  final RxBool isScrolled = false.obs;

  /// When [new_message] socket event fires, set to true to show badge on chat icon.
  /// Cleared when user navigates to ChatScreen and comes back.
  final RxBool hasNewMessage = false.obs;
  StreamSubscription<dynamic>? _newMessageSubscription;

  /// Scroll direction & search field: scroll up (away from top) → hide search; scroll down / at top → show.
  double _lastScrollOffset = 0.0;
  static const double _scrollDirectionThreshold = 8.0;
  final RxBool isScrollingUp = false.obs;
  final RxBool isScrollingDown = false.obs;
  final RxBool showSearchButton = false.obs;

  /// Feed data (posts + isFollowing). Use [feedData].value?.posts for list.
  final Rx<PostDataResponse?> feedData = Rx<PostDataResponse?>(null);

  /// Page-based pagination state (always loaded from local DB).
  final RxInt currentPage = 1.obs;
  final RxBool hasNext = false.obs;
  final RxInt limit = 20.obs;

  /// True while loading from API (initial refresh or load more).
  final RxBool isLoading = false.obs;
  final RxBool isLoadMoreLoading = false.obs;

  /// True when cache was empty on first load (show shimmer until first data).
  final RxBool hasTriedInitialLoad = false.obs;

  /// Callback wired from `HomeScreen` so other parts of the app (e.g. the
  /// dashboard bottom navigation) can tell the home feed "you were re‑selected".
  /// When invoked, the UI will typically scroll to top and trigger a refresh,
  /// Instagram‑style.
  VoidCallback? _onHomeTabReselected;

  @override
  void onInit() {
    super.onInit();
    loadFromCacheThenRefresh();
    _verifyPurchaseStatusSilently();
    _newMessageSubscription = SocketService.instance.onNewMessageStream.listen((
      _,
    ) {
      hasNewMessage.value = true;
    });
  }

  void _verifyPurchaseStatusSilently() {
    unawaited(PurchaseStatusApiService().verifySilently());
  }

  @override
  void onClose() {
    _newMessageSubscription?.cancel();
    super.onClose();
  }

  /// Call when user returns from ChatScreen to remove the new message badge.
  void clearNewMessageIndicator() {
    hasNewMessage.value = false;
  }

  /// Called from `HomeScreen` to register how the UI should react when the
  /// Home tab is tapped again while already selected.
  void registerHomeTabReselectCallback(VoidCallback callback) {
    _onHomeTabReselected = callback;
  }

  /// Called from `DashboardController` when the Home tab is tapped while the
  /// user is already on Home. Delegates to the UI callback if available.
  void handleHomeTabReselected() {
    _onHomeTabReselected?.call();
  }

  /// 1) Load from cache and show immediately. 2) In background, fetch latest and save to DB.
  Future<void> loadFromCacheThenRefresh() async {
    hasTriedInitialLoad.value = true;
    await loadFromCache();
    refreshFeedInBackground();
  }

  /// Read from local DB only. UI binds to [feedData].
  Future<void> loadFromCache() async {
    final cached = await _local.getCachedFeed();
    feedData.value = cached.data;
    final p = cached.pagination;
    currentPage.value = p?.page ?? 1;
    hasNext.value = p?.hasNext ?? false;
    limit.value = p?.limit ?? limit.value;
  }

  void _setFeedPosts(List<PostData> list, {bool? isFollowing}) {
    feedData.value = PostDataResponse(
      posts: list,
      isFollowing: isFollowing ?? feedData.value?.isFollowing,
    );
  }

  /// Call feed API (no cursor), save to local, then sync UI from API response.
  Future<void> refreshFeedInBackground() async {
    if (isLoading.value) return;
    isLoading.value = true;
    _repo.getFeed(
      page: 1,
      limit: limit.value,
      onSuccess: (model) async {
        final data = model.data;
        if (data != null) {
          await _local.saveFeed(data: data, pagination: model.pagination);
        }
        _applyFeedFromApi(data, model.pagination);
        isLoading.value = false;
      },
      onError: (_) {
        isLoading.value = false;
      },
    );
  }

  /// Load next page when user scrolls near bottom. Uses cached [currentPage] + [hasNext].
  Future<void> loadMore() async {
    if (isLoadMoreLoading.value) return;
    if (hasNext.value != true) return;

    isLoadMoreLoading.value = true;
    _repo.getFeed(
      page: currentPage.value + 1,
      limit: limit.value,
      onSuccess: (model) async {
        final newPosts = model.data?.posts ?? [];
        await _local.appendFeed(
          newPosts: newPosts,
          pagination: model.pagination,
        );
        final current = feedData.value?.posts ?? [];
        feedData.value = PostDataResponse(
          posts: [...current, ...newPosts],
          isFollowing: model.data?.isFollowing ?? feedData.value?.isFollowing,
        );
        final p = model.pagination;
        if (p != null) {
          currentPage.value = p.page ?? (currentPage.value + 1);
          hasNext.value = p.hasNext ?? false;
        }
        isLoadMoreLoading.value = false;
      },
      onError: (_) {
        isLoadMoreLoading.value = false;
      },
    );
  }

  /// Call from scroll listener. Tracks direction for app bar + search visibility; triggers [loadMore] near bottom.
  void onScroll(double offset, double maxScrollExtent) {
    scrollOffset.value = offset;
    isScrolled.value = offset > 50.0;

    final delta = offset - _lastScrollOffset;
    if (delta > _scrollDirectionThreshold) {
      isScrollingDown.value = true;
      isScrollingUp.value = false;
      showSearchButton.value = false;
    } else if (delta < -_scrollDirectionThreshold) {
      isScrollingDown.value = false;
      isScrollingUp.value = true;
      if (offset > 50.0) showSearchButton.value = true;
    }
    if (offset <= 20.0) showSearchButton.value = false;
    _lastScrollOffset = offset;

    if (maxScrollExtent <= 0) return;
    if (offset >= maxScrollExtent * 0.8) {
      loadMore();
    }
  }

  /// Submit poll vote. Optimistic update, then API; on success replace post with server data, on error revert.
  void submitPollVote(String postId, String optionId) {
    final list = feedData.value?.posts ?? [];
    final index = list.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    final post = list[index];
    if (post.hasVoted == true) return;
    final opts = post.options;
    if (opts == null || opts.isEmpty) return;

    final previousPost = PostData(
      id: post.id,
      contentType: post.contentType,
      userId: post.userId,
      mentionedUsers: post.mentionedUsers,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      shareCount: post.shareCount,
      isLiked: post.isLiked,
      isSaved: post.isSaved,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      caption: post.caption,
      images: post.images,
      videos: post.videos,
      mediaUrl: post.mediaUrl,
      thumbnailUrl: post.thumbnailUrl,
      music: post.music,
      musicStartTime: post.musicStartTime,
      musicEndTime: post.musicEndTime,
      content: post.content,
      options: opts
          .map(
            (o) => PollOptionItem(
              optionId: o.optionId,
              optionText: o.optionText,
              voteCount: o.voteCount,
              votePercentage: o.votePercentage,
            ),
          )
          .toList(),
      totalVotes: post.totalVotes,
      status: post.status,
      duration: post.duration,
      hasVoted: post.hasVoted,
      votedOptionId: post.votedOptionId,
      createdBy: post.createdBy,
    );

    final currentTotal = post.totalVotes ?? 0;
    final newTotal = currentTotal + 1;
    final newOptions = <PollOptionItem>[];
    for (final o in opts) {
      final isSelected = o.optionId == optionId;
      final count = (o.voteCount ?? 0) + (isSelected ? 1 : 0);
      newOptions.add(
        PollOptionItem(
          optionId: o.optionId,
          optionText: o.optionText,
          voteCount: count,
          votePercentage: newTotal > 0 ? ((count / newTotal) * 100).round() : 0,
        ),
      );
    }
    final optimisticPost = post.copyWith(
      options: newOptions,
      totalVotes: newTotal,
      hasVoted: true,
      votedOptionId: optionId,
    );
    final newList = List<PostData>.from(list)..[index] = optimisticPost;
    _setFeedPosts(newList);

    _repo.submitPollVote(
      pollId: postId,
      optionId: optionId,
      onSuccess: (updatedPost) {
        final currentList = feedData.value?.posts ?? [];
        if (index >= currentList.length || currentList[index].id != postId) {
          return;
        }
        final current = currentList[index];
        final merged = current.copyWith(
          options: updatedPost?.options ?? current.options,
          totalVotes: updatedPost?.totalVotes ?? current.totalVotes,
          hasVoted: updatedPost?.hasVoted ?? true,
          votedOptionId: updatedPost?.votedOptionId ?? optionId,
        );
        final mergedList = List<PostData>.from(currentList)..[index] = merged;
        _setFeedPosts(mergedList);
      },
      onError: (_) {
        final currentList = feedData.value?.posts ?? [];
        if (index < currentList.length && currentList[index].id == postId) {
          final revertedList = List<PostData>.from(currentList)
            ..[index] = previousPost;
          _setFeedPosts(revertedList);
        }
      },
    );
  }

  /// Pull-to-refresh: fetch from API, save to local, sync list from API response.
  Future<void> onRefresh() async {
    final completer = Completer<void>();
    isLoading.value = true;
    _repo.getFeed(
      page: 1,
      limit: limit.value,
      onSuccess: (model) async {
        final data = model.data;
        if (data != null) {
          await _local.saveFeed(data: data, pagination: model.pagination);
        }
        _applyFeedFromApi(data, model.pagination);
        isLoading.value = false;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_) {
        isLoading.value = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  /// Updates [feedData] and pagination from API response.
  void _applyFeedFromApi(PostDataResponse? data, Pagination? pagination) {
    feedData.value = data;
    final p = pagination;
    currentPage.value = p?.page ?? 1;
    hasNext.value = p?.hasNext ?? false;
    if (p?.limit != null) limit.value = p!.limit!;
  }

  void refreshFeedData() {
    final d = feedData.value;
    if (d != null) {
      feedData.value = PostDataResponse(
        posts: d.posts ?? [],
        isFollowing: d.isFollowing,
      );
    }
  }

  PostRepository postRepository = PostRepository();

  /// Remove a post from the feed list (e.g. after delete). Call from onDelete callback.
  void removePostById(String id) {
    final list = feedData.value?.posts ?? [];
    _setFeedPosts(list.where((p) => p.id != id).toList());
  }

  /// Optimistic update: toggle save state immediately, then call API. On error, revert.
  Future<void> saveUnSavePost(
    BuildContext context,
    String type,
    String postId,
    int index,
  ) async {
    final list = feedData.value?.posts ?? [];
    if (index < 0 || index >= list.length) return;
    final previousSaved = list[index].isSaved ?? false;
    final updatedList = List<PostData>.from(list);
    updatedList[index].isSaved = !previousSaved;
    _setFeedPosts(updatedList);

    await postRepository.savePost(
      data: {"contentType": type, "contentId": postId},
      onSuccess: (ApiResponse response) {
        Get.find<HomeController>().feedData.value!.posts![index].isSaved = response.data['isSaved'];
        Get.find<HomeController>().feedData.refresh();
      },
      onError: (AppException error) {
        final reverted = List<PostData>.from(feedData.value?.posts ?? []);
        if (index < reverted.length) reverted[index].isSaved = previousSaved;
        _setFeedPosts(reverted);
        AppFunctions().showToast(error.message, bgColor: AppColors.red);
      },
    );
  }
}
