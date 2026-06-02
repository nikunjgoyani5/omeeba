import 'dart:async';
import 'package:omeeba_new/core/data/explore/explore_feed_local.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/explore_repository.dart';
import 'package:omeeba_new/core/repository/home_repository.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/repository/post_repository.dart';
import '../../../../core/utils/exports.dart';
import '../../home/controller/home_controller.dart';

/// Explore controller. Cache-first (Instagram-like):
/// - Load from local DB first; API only when cache empty or on pull-to-refresh.
/// - Load more (pagination) on scroll.
class ExploreController extends GetxController {
  final ExploreRepository _repo = Get.find<ExploreRepository>();
  final ExploreFeedLocal _local = Get.find<ExploreFeedLocal>();
  final HomeRepository _homeRepo = Get.find<HomeRepository>();

  static const String contentTypeExplore = 'explore';
  static const String contentTypeWrite = 'write';
  static const String contentTypePoll = 'poll';

  final Rx<PostDataResponse?> exploreData = Rx<PostDataResponse?>(null);
  final Rx<PostDataResponse?> trendingData = Rx<PostDataResponse?>(null);
  final Rx<PostDataResponse?> pollData = Rx<PostDataResponse?>(null);

  final RxBool exploreLoading = false.obs;
  final RxBool trendingLoading = false.obs;
  final RxBool pollLoading = false.obs;

  final RxBool exploreLoadMoreLoading = false.obs;
  final RxBool trendingLoadMoreLoading = false.obs;
  final RxBool pollLoadMoreLoading = false.obs;

  final RxBool exploreHasTriedLoad = false.obs;
  final RxBool trendingHasTriedLoad = false.obs;
  final RxBool pollHasTriedLoad = false.obs;

  final RxInt explorePage = 1.obs;
  final RxInt trendingPage = 1.obs;
  final RxInt pollPage = 1.obs;

  final RxBool exploreHasNext = false.obs;
  final RxBool trendingHasNext = false.obs;
  final RxBool pollHasNext = false.obs;

  final RxInt limit = 20.obs;

  @override
  void onInit() {
    super.onInit();
    loadExploreFromCacheThenFetchIfEmpty();
  }

  void onTabSelected(int index) {
    if (index == 1 && !trendingHasTriedLoad.value) {
      loadTrendingFromCacheThenFetchIfEmpty();
    } else if (index == 2 && !pollHasTriedLoad.value) {
      loadPollsFromCacheThenFetchIfEmpty();
    }
  }

  /// Load explore from cache first; API only when cache empty.
  Future<void> loadExploreFromCacheThenFetchIfEmpty() async {
    exploreHasTriedLoad.value = true;
    await loadExploreFromCache();
    if ((exploreData.value?.posts?.isEmpty ?? true) && !exploreLoading.value) {
      _fetchExploreFromApi();
    }
  }

  Future<void> loadExploreFromCache() async {
    final cached = await _local.getCachedExplore();
    exploreData.value = cached.data;
    final p = cached.pagination;
    explorePage.value = p?.page ?? 1;
    exploreHasNext.value = p?.hasNext ?? false;
  }

  void _setTrendingPosts(List<PostData> list, {bool? isFollowing}) {
    trendingData.value = PostDataResponse(posts: list, isFollowing: isFollowing ?? trendingData.value?.isFollowing);
  }

  void _setPollPosts(List<PostData> list, {bool? isFollowing}) {
    pollData.value = PostDataResponse(posts: list, isFollowing: isFollowing ?? pollData.value?.isFollowing);
  }

  void _fetchExploreFromApi({bool refresh = false}) {
    if (exploreLoading.value) return;
    if (refresh) {
      explorePage.value = 1;
      exploreData.value = null;
    }
    exploreLoading.value = true;

    _repo.getExploreFeed(
      contentType: contentTypeExplore,
      page: refresh ? 1 : explorePage.value,
      limit: limit.value,
      onSuccess: (model) async {
        if (model.data != null) await _local.saveExplore(data: model.data!, pagination: model.pagination);
        await loadExploreFromCache();
        _updatePagination(model.pagination, explorePage, exploreHasNext);
        exploreLoading.value = false;
      },
      onError: (_) {
        exploreLoading.value = false;
      },
    );
  }

  /// Load trending from cache first; API only when cache empty.
  Future<void> loadTrendingFromCacheThenFetchIfEmpty() async {
    trendingHasTriedLoad.value = true;
    await loadTrendingFromCache();
    if ((trendingData.value?.posts?.isEmpty ?? true) && !trendingLoading.value) {
      _fetchTrendingFromApi();
    }
  }

  Future<void> loadTrendingFromCache() async {
    final cached = await _local.getCachedTrending();
    trendingData.value = cached.data;
    final p = cached.pagination;
    trendingPage.value = p?.page ?? 1;
    trendingHasNext.value = p?.hasNext ?? false;
  }

  void _fetchTrendingFromApi({bool refresh = false}) {
    if (trendingLoading.value) return;
    if (refresh) {
      trendingPage.value = 1;
      trendingData.value = null;
    }
    trendingLoading.value = true;

    _repo.getExploreFeed(
      contentType: contentTypeWrite,
      page: refresh ? 1 : trendingPage.value,
      limit: limit.value,
      onSuccess: (model) async {
        if (model.data != null) await _local.saveTrending(data: model.data!, pagination: model.pagination);
        await loadTrendingFromCache();
        _updatePagination(model.pagination, trendingPage, trendingHasNext);
        trendingLoading.value = false;
      },
      onError: (_) {
        trendingLoading.value = false;
      },
    );
  }

  /// Load polls from cache first; API only when cache empty.
  Future<void> loadPollsFromCacheThenFetchIfEmpty() async {
    pollHasTriedLoad.value = true;
    //   await loadPollsFromCache();
    if ((pollData.value?.posts?.isEmpty ?? true) && !pollLoading.value) {
      _fetchPollsFromApi();
    }
  }

  Future<void> loadPollsFromCache() async {
    final cached = await _local.getCachedPolls();
    pollData.value = cached.data;
    final p = cached.pagination;
    pollPage.value = p?.page ?? 1;
    pollHasNext.value = p?.hasNext ?? false;
  }

  void _fetchPollsFromApi({bool refresh = false}) {
    if (pollLoading.value) return;
    if (refresh) {
      pollPage.value = 1;
      pollData.value = null;
    }
    pollLoading.value = true;

    _repo.getExploreFeed(
      contentType: contentTypePoll,
      page: refresh ? 1 : pollPage.value,
      limit: limit.value,
      onSuccess: (model) async {
        if (model.data != null) await _local.savePolls(data: model.data!, pagination: model.pagination);
        await loadPollsFromCache();
        _updatePagination(model.pagination, pollPage, pollHasNext);
        pollLoading.value = false;
      },
      onError: (_) {
        pollLoading.value = false;
      },
    );
  }

  void _updatePagination(Pagination? p, RxInt pageObs, RxBool hasNextObs) {
    if (p != null) {
      pageObs.value = p.page ?? 1;
      hasNextObs.value = p.hasNext ?? false;
    }
  }

  /// Pull-to-refresh: fetch from API, save to DB, reload from cache.
  Future<void> refreshExplore() async {
    final completer = Completer<void>();
    exploreLoading.value = true;
    _repo.getExploreFeed(
      contentType: contentTypeExplore,
      page: 1,
      limit: limit.value,
      onSuccess: (model) async {
        if (model.data != null) await _local.saveExplore(data: model.data!, pagination: model.pagination);
        await loadExploreFromCache();
        _updatePagination(model.pagination, explorePage, exploreHasNext);
        exploreLoading.value = false;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_) {
        exploreLoading.value = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  Future<void> refreshTrending() async {
    final completer = Completer<void>();
    trendingLoading.value = true;
    _repo.getExploreFeed(
      contentType: contentTypeWrite,
      page: 1,
      limit: limit.value,
      onSuccess: (model) async {
        if (model.data != null) await _local.saveTrending(data: model.data!, pagination: model.pagination);
        await loadTrendingFromCache();
        _updatePagination(model.pagination, trendingPage, trendingHasNext);
        trendingLoading.value = false;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_) {
        trendingLoading.value = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  Future<void> refreshPolls() async {
    final completer = Completer<void>();
    pollLoading.value = true;
    _repo.getExploreFeed(
      contentType: contentTypePoll,
      page: 1,
      limit: limit.value,
      onSuccess: (model) async {
        if (model.data != null) await _local.savePolls(data: model.data!, pagination: model.pagination);
        await loadPollsFromCache();
        _updatePagination(model.pagination, pollPage, pollHasNext);
        pollLoading.value = false;
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_) {
        pollLoading.value = false;
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  /// Load more (pagination) on scroll.
  Future<void> loadMoreExplore() async {
    if (exploreLoadMoreLoading.value || !exploreHasNext.value) return;
    exploreLoadMoreLoading.value = true;

    _repo.getExploreFeed(
      contentType: contentTypeExplore,
      page: explorePage.value + 1,
      limit: limit.value,
      onSuccess: (model) async {
        await _local.appendExplore(newPosts: model.data?.posts ?? [], pagination: model.pagination);
        await loadExploreFromCache();
        _updatePagination(model.pagination, explorePage, exploreHasNext);
        exploreLoadMoreLoading.value = false;
      },
      onError: (_) {
        exploreLoadMoreLoading.value = false;
      },
    );
  }

  Future<void> loadMoreTrending() async {
    if (trendingLoadMoreLoading.value || !trendingHasNext.value) return;
    trendingLoadMoreLoading.value = true;

    _repo.getExploreFeed(
      contentType: contentTypeWrite,
      page: trendingPage.value + 1,
      limit: limit.value,
      onSuccess: (model) async {
        await _local.appendTrending(newPosts: model.data?.posts ?? [], pagination: model.pagination);
        await loadTrendingFromCache();
        _updatePagination(model.pagination, trendingPage, trendingHasNext);
        trendingLoadMoreLoading.value = false;
      },
      onError: (_) {
        trendingLoadMoreLoading.value = false;
      },
    );
  }

  Future<void> loadMorePolls() async {
    if (pollLoadMoreLoading.value || !pollHasNext.value) return;
    pollLoadMoreLoading.value = true;

    _repo.getExploreFeed(
      contentType: contentTypePoll,
      page: pollPage.value + 1,
      limit: limit.value,
      onSuccess: (model) async {
        await _local.appendPolls(newPosts: model.data?.posts ?? [], pagination: model.pagination);
        await loadPollsFromCache();
        _updatePagination(model.pagination, pollPage, pollHasNext);
        pollLoadMoreLoading.value = false;
      },
      onError: (_) {
        pollLoadMoreLoading.value = false;
      },
    );
  }

  PostRepository postRepository = PostRepository();

  void refreshExploreData() {
    final d = exploreData.value;
    if (d != null) exploreData.value = PostDataResponse(posts: d.posts ?? [], isFollowing: d.isFollowing);
  }

  void refreshTrendingData() {
    final d = trendingData.value;
    if (d != null) trendingData.value = PostDataResponse(posts: d.posts ?? [], isFollowing: d.isFollowing);
  }

  void refreshPollData() {
    final d = pollData.value;
    if (d != null) pollData.value = PostDataResponse(posts: d.posts ?? [], isFollowing: d.isFollowing);
  }

  /// Optimistic update: toggle save state immediately, then call API. On error, revert.
  Future<void> saveUnSavePost(BuildContext context, String type, String postId, int index, bool isPoll) async {
    if (isPoll) {
      final list = pollData.value?.posts ?? [];
      if (index < 0 || index >= list.length) return;
      final previousSaved = list[index].isSaved ?? false;
      final updated = List<PostData>.from(list);
      updated[index].isSaved = !previousSaved;
      _setPollPosts(updated);
      await postRepository.savePost(
        data: {"contentType": type, "contentId": postId},
        onSuccess: (ApiResponse response) {
          Get.find<HomeController>().feedData.value!.posts![index].isSaved = response.data['isSaved'];
          Get.find<HomeController>().feedData.refresh();
        },
        onError: (AppException error) {
          final reverted = List<PostData>.from(pollData.value?.posts ?? []);
          if (index < reverted.length) reverted[index].isSaved = previousSaved;
          _setPollPosts(reverted);
          AppFunctions().showToast(error.message, bgColor: AppColors.red);
        },
      );
    } else {
      final list = trendingData.value?.posts ?? [];
      if (index < 0 || index >= list.length) return;
      final previousSaved = list[index].isSaved ?? false;
      final updated = List<PostData>.from(list);
      updated[index].isSaved = !previousSaved;
      _setTrendingPosts(updated);
      await postRepository.savePost(
        data: {"contentType": type, "contentId": postId},
        onSuccess: (ApiResponse response) {
          Get.find<HomeController>().feedData.value!.posts![index].isSaved = response.data['isSaved'];
          Get.find<HomeController>().feedData.refresh();
        },
        onError: (AppException error) {
          final reverted = List<PostData>.from(trendingData.value?.posts ?? []);
          if (index < reverted.length) reverted[index].isSaved = previousSaved;
          _setTrendingPosts(reverted);
          AppFunctions().showToast(error.message, bgColor: AppColors.red);
        },
      );
    }
  }

  /// Remove a post from explore/trending/poll lists (e.g. after delete). Call from onDelete callback.
  void removePostById(String id) {
    void removeFrom(Rx<PostDataResponse?> rx) {
      final list = rx.value?.posts ?? [];
      if (list.isEmpty) return;
      rx.value = PostDataResponse(posts: list.where((p) => p.id != id).toList(), isFollowing: rx.value?.isFollowing);
    }

    removeFrom(exploreData);
    removeFrom(trendingData);
    removeFrom(pollData);
  }

  /// Submit poll vote (same behavior as home): optimistic update, then API; merge on success.
  void submitPollVote(String postId, String optionId) {
    final list = pollData.value?.posts ?? [];
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
    _setPollPosts(newList);

    _homeRepo.submitPollVote(
      pollId: postId,
      optionId: optionId,
      onSuccess: (updatedPost) {
        final currentList = pollData.value?.posts ?? [];
        if (index >= currentList.length || currentList[index].id != postId) return;
        final current = currentList[index];
        final merged = current.copyWith(
          options: updatedPost?.options ?? current.options,
          totalVotes: updatedPost?.totalVotes ?? current.totalVotes,
          hasVoted: updatedPost?.hasVoted ?? true,
          votedOptionId: updatedPost?.votedOptionId ?? optionId,
        );
        final mergedList = List<PostData>.from(currentList)..[index] = merged;
        _setPollPosts(mergedList);
      },
      onError: (_) {
        final currentList = pollData.value?.posts ?? [];
        if (index < currentList.length && currentList[index].id == postId) {
          final revertedList = List<PostData>.from(currentList)..[index] = previousPost;
          _setPollPosts(revertedList);
        }
      },
    );
  }
}
