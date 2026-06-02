import 'dart:async';
import 'package:omeeba_new/core/data/zeals/zeals_feed_local.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/repository/profile_repository.dart';
import 'package:omeeba_new/core/repository/zeals_repository.dart';

import '../../../../core/models/api_response.dart';
import '../../../../core/repository/post_repository.dart';
import '../../../../core/utils/exports.dart';
import '../../home/controller/home_controller.dart';

class ZealsController extends GetxController {
  final ZealsRepository _repo = Get.find<ZealsRepository>();
  final ZealsFeedLocal _local = Get.find<ZealsFeedLocal>();
  final ProfileRepository _profileRepo = ProfileRepository();
  final PostRepository _postRepository = PostRepository();

  final Rx<PostDataResponse?> reelsData = Rx<PostDataResponse?>(null);
  final currentIndex = 0.obs;

  final RxBool isLoading = false.obs;
  final RxInt currentPage = 1.obs;
  final RxBool hasNext = false.obs;
  final RxInt limit = 20.obs;

  /// Bumped when a full tab refresh invalidates an in-flight `loadMore` or older page-1 fetch.
  int _feedEpoch = 0;

  void _setReelsPosts(List<PostData> list, {bool? isFollowing}) {
    reelsData.value = PostDataResponse(posts: list, isFollowing: isFollowing ?? reelsData.value?.isFollowing);
  }

  void refreshReelsData() {
    final d = reelsData.value;
    if (d != null) reelsData.value = PostDataResponse(posts: d.posts ?? [], isFollowing: d.isFollowing);
  }

  /// Remove a reel from the list (e.g. after delete). Call from onDelete callback.
  void removeReelById(String id) {
    final list = reelsData.value?.posts ?? [];
    if (list.isEmpty) return;
    reelsData.value = PostDataResponse(
      posts: list.where((p) => p.id != id).toList(),
      isFollowing: reelsData.value?.isFollowing,
    );
    refreshReelsData();
  }

  @override
  void onInit() {
    super.onInit();
    _loadFromCacheThenRefresh();
  }

  Future<void> _loadFromCacheThenRefresh() async {
    await _loadFromCache();
    _refreshInBackground();
  }

  Future<void> _loadFromCache() async {
    final cached = await _local.getCachedFeed();
    reelsData.value = cached.data;
    final p = cached.pagination;
    currentPage.value = p?.page ?? 1;
    hasNext.value = p?.hasNext ?? false;
    limit.value = p?.limit ?? limit.value;
  }

  /// Called when user taps Zeal tab: clear UI, show shimmer, call API. On success clear
  /// local DB and store fresh data; on fail load from local (offline).
  Future<void> refreshZeals() async {
    await _fetchZealsPage1(clearReelsFirst: true);
  }

  /// Pull-to-refresh: same API logic, no list clear so refresh indicator at top only (no full-screen shimmer).
  /// clearReelsFirst: false for manual pull and auto-trigger when data exists; resets pagination and replaces list on success.
  Future<void> refreshZealsAsync({bool clearReelsFirst = false}) async {
    final completer = Completer<void>();
    if (isLoading.value) {
      completer.complete();
      return completer.future;
    }
    _fetchZealsPage1(clearReelsFirst: clearReelsFirst, completer: completer);
    return completer.future;
  }

  void _refreshInBackground() {
    if (isLoading.value) return;
    _fetchZealsPage1(clearReelsFirst: false);
  }

  Future<void> _fetchZealsPage1({required bool clearReelsFirst, Completer<void>? completer}) async {
    // Tab refresh (clearReelsFirst) must run even if loadMore left isLoading true; otherwise feed stays empty/stale.
    if (isLoading.value && completer == null && !clearReelsFirst) return;
    if (clearReelsFirst) {
      _feedEpoch++;
      reelsData.value = null;
      currentIndex.value = 0;
    }
    final epoch = _feedEpoch;
    isLoading.value = true;
    _repo.getZeals(
      page: 1,
      limit: limit.value,
      onSuccess: (model) async {
        if (epoch != _feedEpoch) {
          isLoading.value = false;
          if (completer != null && !completer.isCompleted) completer.complete();
          return;
        }
        await _local.clear();
        if (model.data != null) await _local.saveFeed(data: model.data!, pagination: model.pagination);
        await _loadFromCache();
        isLoading.value = false;
        if (completer != null && !completer.isCompleted) completer.complete();
      },
      onError: (_) async {
        if (epoch != _feedEpoch) {
          isLoading.value = false;
          if (completer != null && !completer.isCompleted) completer.complete();
          return;
        }
        if (clearReelsFirst) {
          await _loadFromCache();
        }
        isLoading.value = false;
        if (completer != null && !completer.isCompleted) completer.complete();
      },
    );
  }

  Future<void> loadMore() async {
    if (isLoading.value) return;
    if (hasNext.value != true) return;

    final epoch = _feedEpoch;
    isLoading.value = true;
    _repo.getZeals(
      page: currentPage.value + 1,
      limit: limit.value,
      onSuccess: (model) async {
        if (epoch != _feedEpoch) {
          isLoading.value = false;
          return;
        }
        await _local.appendFeed(newPosts: model.data?.posts ?? [], pagination: model.pagination);
        await _loadFromCache();
        isLoading.value = false;
      },
      onError: (_) {
        if (epoch != _feedEpoch) {
          isLoading.value = false;
          return;
        }
        isLoading.value = false;
      },
    );
  }

  void onPageChanged(int index) {
    currentIndex.value = index;
  }

  final RxInt pauseVideosTrigger = 0.obs;

  void requestPauseVideos() {
    pauseVideosTrigger.value++;
  }

  void disposeAllVideos() {
    // Clean up any resources if needed in future
  }

  /// Follow a user. On success, updates isFollowing for matching reels.
  Future<void> followUser(String userId, {void Function()? onSuccess, void Function(String message)? onError}) async {
    if (userId.isEmpty) return;
    await _profileRepo.followUser(
      userId: userId,
      onSuccess: () {
        _updateReelsFollowStatus(userId, true);
        onSuccess?.call();
      },
      onError: (AppException e) {
        onError?.call(e.message);
      },
    );
  }

  /// Unfollow a user. On success, updates isFollowing for matching reels.
  Future<void> unfollowUser(String userId, {void Function()? onSuccess, void Function(String message)? onError}) async {
    if (userId.isEmpty) return;
    await _profileRepo.unfollowUser(
      userId: userId,
      onSuccess: () {
        _updateReelsFollowStatus(userId, false);
        onSuccess?.call();
      },
      onError: (AppException e) {
        onError?.call(e.message);
      },
    );
  }

  Future<void> saveUnSavePost(BuildContext context, PostData post) async {
    final previousSaved = post.isSaved ?? false;
    post.isSaved = !previousSaved;

    await _postRepository.savePost(
      data: {'contentType': post.contentType, 'contentId': post.id},
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

        AppFunctions().showToast(error.message, bgColor: AppColors.red);
      },
    );
  }

  void _updateReelsFollowStatus(String userId, bool isFollowing) {
    final list = reelsData.value?.posts ?? [];
    if (list.isEmpty) return;
    final updated = <PostData>[];
    for (final p in list) {
      if (p.userId?.id == userId) {
        updated.add(p.copyWith(isFollowing: isFollowing));
      } else {
        updated.add(p);
      }
    }
    _setReelsPosts(updated);
  }
}
