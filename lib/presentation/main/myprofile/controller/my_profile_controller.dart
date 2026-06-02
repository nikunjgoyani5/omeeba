import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/models/user_profile_response_model.dart';
import 'package:omeeba_new/core/repository/home_repository.dart';
import 'package:omeeba_new/core/repository/post_repository.dart';
import 'package:omeeba_new/core/repository/profile_repository.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/utils/app_prefrence.dart';
import '../../../../core/utils/exports.dart';
import '../../home/controller/home_controller.dart';

class MyProfileController extends GetxController {
  final ProfileRepository _repo = Get.find<ProfileRepository>();
  final HomeRepository _homeRepo = Get.find<HomeRepository>();
  final PostRepository _postRepository = PostRepository();

  final Rx<Profile?> profile = Rx<Profile?>(null);
  final RxBool isLoading = false.obs;
  final RxBool hasLoadedOnce = false.obs;
  final RxString emailError = "".obs;

  // Posts tab state (current user's posts).
  final Rx<PostDataResponse?> myPostsData = Rx<PostDataResponse?>(null);
  final RxBool myPostsLoading = false.obs;
  final RxBool myPostsLoadMoreLoading = false.obs;
  final RxInt myPostsPage = 1.obs;
  final RxBool myPostsHasNext = false.obs;
  final RxInt myPostsLimit = 15.obs;

  // Tagged tab state (current user's mentioned-posts).
  final Rx<PostDataResponse?> myTaggedData = Rx<PostDataResponse?>(null);
  final RxBool myTaggedLoading = false.obs;
  final RxBool myTaggedLoadMoreLoading = false.obs;
  final RxInt myTaggedPage = 1.obs;
  final RxBool myTaggedHasNext = false.obs;
  final RxInt myTaggedLimit = 10.obs;

  // Polls tab state (current user's polls).
  final Rx<PostDataResponse?> myPollsData = Rx<PostDataResponse?>(null);
  final RxBool myPollsLoading = false.obs;
  final RxBool myPollsLoadMoreLoading = false.obs;
  final RxInt myPollsPage = 1.obs;
  final RxBool myPollsHasNext = false.obs;
  final RxInt myPollsLimit = 10.obs;

  // Writes tab state (current user's write-posts).
  final Rx<PostDataResponse?> myWritesData = Rx<PostDataResponse?>(null);
  final RxBool myWritesLoading = false.obs;
  final RxBool myWritesLoadMoreLoading = false.obs;
  final RxInt myWritesPage = 1.obs;
  final RxBool myWritesHasNext = false.obs;
  final RxInt myWritesLimit = 10.obs;

  // Zeals tab state (current user's zeals).
  final Rx<PostDataResponse?> myZealsData = Rx<PostDataResponse?>(null);
  final RxBool myZealsLoading = false.obs;
  final RxBool myZealsLoadMoreLoading = false.obs;
  final RxInt myZealsPage = 1.obs;
  final RxBool myZealsHasNext = false.obs;
  final RxInt myZealsLimit = 15.obs;

  // Edit profile state
  final Rx<File?> selectedCoverImage = Rx<File?>(null);
  final Rx<File?> selectedProfileImage = Rx<File?>(null);
  final RxBool isUpdatingProfile = false.obs;
  final ImagePicker _picker = ImagePicker();

  /// Bump so Obx rebuilds when save/unsave state changes (instant UI).
  final RxInt bookmarkRefreshTrigger = 0.obs;
  final Set<int> selectedIndices = {};

  void toggleSelection(int index) {
    if (selectedIndices.contains(index)) {
      selectedIndices.remove(index);
    } else {
      selectedIndices.add(index);
    }

    // 🔥 Only rebuild this grid item
    update(['post_$index']);
  }

  bool isSelected(int index) => selectedIndices.contains(index);
  /// Load / refresh the user's profile.
  /// [silent] when true does not set [isLoading] (used for pull-to-refresh).
  /// On first load success, loads tab 0 (posts).
  Future<void> loadProfile({bool silent = false}) async {
    if (!silent && !hasLoadedOnce.value) {
      isLoading.value = true;
    }

    await _repo.getProfile(
      onSuccess: (model) {
        profile.value = model.data?.profile;
        PrefService.setValue(PrefKeys.userProfile,profile.value?.profileImage.toString());
        PrefService.setValue(PrefKeys.isVerifiedBeach,profile.value?.isVerifiedBadge);
        hasLoadedOnce.value = true;
        if (!silent) isLoading.value = false;
        if (!silent) loadMyPostsIfNeeded();
      },
      onError: (error) {
        AppFunctions().showToast(error.message, bgColor: AppColors.red);
        if (!silent) isLoading.value = false;
      },
    );
  }

  /// Load data for the given tab only when user selects that tab.
  void loadTabIfNeeded(int tabIndex) {
    switch (tabIndex) {
      case 0:
        loadMyPostsIfNeeded();
        break;
      case 1:
        loadMyZealsIfNeeded();
        break;
      case 2:
        loadMyWritesIfNeeded();
        break;
      case 3:
        loadMyPollsIfNeeded();
        break;
      case 4:
        loadMyTaggedIfNeeded();
        break;
      default:
        loadMyPostsIfNeeded();
    }
  }

  /// Refreshes profile and the tab at [tabIndex]. Use for pull-to-refresh.
  Future<void> refreshProfileAndCurrentTab(int tabIndex) async {
    await Future.wait([
      loadProfile(silent: true),
      _refreshTabByIndex(tabIndex),
    ]);
  }

  Future<void> _refreshTabByIndex(int index) async {
    switch (index) {
      case 0:
        return refreshMyPosts();
      case 1:
        return refreshMyZeals();
      case 2:
        return refreshMyWrites();
      case 3:
        return refreshMyPolls();
      case 4:
        return refreshMyTagged();
      default:
        return refreshMyPosts();
    }
  }

  Future<void> pickCoverImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      selectedCoverImage.value = File(picked.path);
    }
  }

  Future<void> pickProfileImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      selectedProfileImage.value = File(picked.path);
    }
  }

  void clearCoverImage() {
    selectedCoverImage.value = null;
  }

  void clearProfileImage() {
    selectedProfileImage.value = null;
  }

  Future<void> updateProfile({
    required String name,
    required String username,
    required String bio,
    bool removeCoverImage = false,
    bool removeProfileImage = false,
    required BuildContext context,
  }) async {
    if (isUpdatingProfile.value) return;

    if (name.trim().isEmpty || username.trim().isEmpty) {
      return;
    }

    isUpdatingProfile.value = true;

    await _repo.updateProfile(
      name: name.trim(),
      username: username.trim(),
      bio: bio.trim(),
      coverImagePath: selectedCoverImage.value?.path,
      profileImagePath: selectedProfileImage.value?.path,
      removeCoverImage: removeCoverImage,
      removeProfileImage: removeProfileImage,
      onSuccess: (model) {
        profile.value = model.data?.profile;
        PrefService.setValue(PrefKeys.userProfile,profile.value?.profileImage.toString());
        PrefService.setValue(PrefKeys.userName,profile.value?.username.toString());
        PrefService.setValue(PrefKeys.name,profile.value?.name.toString());
        hasLoadedOnce.value = true;
        isUpdatingProfile.value = false;

        loadProfile();
        Get.back();
      },
      onError: (e) {
        AppFunctions.showCustomToast(context, message: e.message, isSuccess: false);
        isUpdatingProfile.value = false;
      },
    );
  }

  /// Ensure posts are loaded at least once (won't refetch if already present).
  Future<void> loadMyPostsIfNeeded() async {
    return loadMyPosts(force: false);
  }

  /// Load posts. If [force] is true, always hits API (used when user opens Profile tab).
  Future<void> loadMyPosts({required bool force}) async {
    if (myPostsLoading.value) return;
    if (!force && (myPostsData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshMyPosts();
  }

  /// Ensure tagged posts are loaded at least once (won't refetch if already present).
  Future<void> loadMyTaggedIfNeeded() async => loadMyTagged(force: false);

  /// Load tagged posts. If [force] is true, always hits API.
  Future<void> loadMyTagged({required bool force}) async {
    if (myTaggedLoading.value) return;
    if (!force && (myTaggedData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshMyTagged();
  }

  /// Pull-to-refresh tagged posts: page=1
  Future<void> refreshMyTagged() async {
    if (myTaggedLoading.value) return;
    myTaggedLoading.value = true;
    myTaggedLoadMoreLoading.value = false;
    myTaggedPage.value = 1;
    myTaggedHasNext.value = false;

    await _repo.getMyMentionedPosts(
      page: 1,
      limit: myTaggedLimit.value,
      onSuccess: (model) {
        myTaggedData.value = model.data;
        myTaggedPage.value = model.pagination?.page ?? 1;
        myTaggedHasNext.value = model.pagination?.hasNext ?? false;
        myTaggedLoading.value = false;
      },
      onError: (_) {
        myTaggedLoading.value = false;
      },
    );
  }

  /// Pagination: load next page of tagged posts.
  Future<void> loadMoreMyTagged() async {
    if (myTaggedLoading.value) return;
    if (myTaggedLoadMoreLoading.value || !myTaggedHasNext.value) return;
    myTaggedLoadMoreLoading.value = true;

    await _repo.getMyMentionedPosts(
      page: myTaggedPage.value + 1,
      limit: myTaggedLimit.value,
      onSuccess: (model) {
        final existing = myTaggedData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        myTaggedData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? myTaggedData.value?.isFollowing,
        );
        myTaggedPage.value = model.pagination?.page ?? (myTaggedPage.value + 1);
        myTaggedHasNext.value = model.pagination?.hasNext ?? false;
        myTaggedLoadMoreLoading.value = false;
      },
      onError: (_) {
        myTaggedLoadMoreLoading.value = false;
      },
    );
  }

  /// Ensure polls are loaded at least once (won't refetch if already present).
  Future<void> loadMyPollsIfNeeded() async => loadMyPolls(force: false);

  /// Load polls. If [force] is true, always hits API.
  Future<void> loadMyPolls({required bool force}) async {
    if (myPollsLoading.value) return;
    if (!force && (myPollsData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshMyPolls();
  }

  /// Pull-to-refresh polls: page=1
  Future<void> refreshMyPolls() async {
    if (myPollsLoading.value) return;
    myPollsLoading.value = true;
    myPollsLoadMoreLoading.value = false;
    myPollsPage.value = 1;
    myPollsHasNext.value = false;

    await _repo.getMyPolls(
      page: 1,
      limit: myPollsLimit.value,
      onSuccess: (model) {
        myPollsData.value = model.data;
        myPollsPage.value = model.pagination?.page ?? 1;
        myPollsHasNext.value = model.pagination?.hasNext ?? false;
        myPollsLoading.value = false;
      },
      onError: (_) {
        myPollsLoading.value = false;
      },
    );
  }

  /// Pagination: load next page of polls.
  Future<void> loadMoreMyPolls() async {
    if (myPollsLoading.value) return;
    if (myPollsLoadMoreLoading.value || !myPollsHasNext.value) return;
    myPollsLoadMoreLoading.value = true;

    await _repo.getMyPolls(
      page: myPollsPage.value + 1,
      limit: myPollsLimit.value,
      onSuccess: (model) {
        final existing = myPollsData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        myPollsData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? myPollsData.value?.isFollowing,
        );
        myPollsPage.value = model.pagination?.page ?? (myPollsPage.value + 1);
        myPollsHasNext.value = model.pagination?.hasNext ?? false;
        myPollsLoadMoreLoading.value = false;
      },
      onError: (_) {
        myPollsLoadMoreLoading.value = false;
      },
    );
  }

  void _setMyPollsAt(int index, PostData newPost) {
    final list = myPollsData.value?.posts ?? [];
    if (index < 0 || index >= list.length) return;
    final updated = List<PostData>.from(list)..[index] = newPost;
    myPollsData.value = PostDataResponse(posts: updated, isFollowing: myPollsData.value?.isFollowing);
  }

  /// Submit poll vote: optimistic update, then API; merge on success.
  void submitPollVote(String postId, String optionId) {
    final list = myPollsData.value?.posts ?? [];
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
      options: opts.map((o) => PollOptionItem(optionId: o.optionId, optionText: o.optionText, voteCount: o.voteCount, votePercentage: o.votePercentage)).toList(),
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
      newOptions.add(PollOptionItem(
        optionId: o.optionId,
        optionText: o.optionText,
        voteCount: count,
        votePercentage: newTotal > 0 ? ((count / newTotal) * 100).round() : 0,
      ));
    }
    final optimisticPost = post.copyWith(
      options: newOptions,
      totalVotes: newTotal,
      hasVoted: true,
      votedOptionId: optionId,
    );
    _setMyPollsAt(index, optimisticPost);

    _homeRepo.submitPollVote(
      pollId: postId,
      optionId: optionId,
      onSuccess: (updatedPost) {
        final currentList = myPollsData.value?.posts ?? [];
        if (index >= currentList.length || currentList[index].id != postId) return;
        final current = currentList[index];
        final merged = current.copyWith(
          options: updatedPost?.options ?? current.options,
          totalVotes: updatedPost?.totalVotes ?? current.totalVotes,
          hasVoted: updatedPost?.hasVoted ?? true,
          votedOptionId: updatedPost?.votedOptionId ?? optionId,
        );
        _setMyPollsAt(index, merged);
      },
      onError: (_) {
        final currentList = myPollsData.value?.posts ?? [];
        if (index < currentList.length && currentList[index].id == postId) {
          _setMyPollsAt(index, previousPost);
        }
      },
    );
  }

  /// Ensure writes are loaded at least once (won't refetch if already present).
  Future<void> loadMyWritesIfNeeded() async {
    return loadMyWrites(force: false);
  }

  /// Load writes. If [force] is true, always hits API.
  Future<void> loadMyWrites({required bool force}) async {
    if (myWritesLoading.value) return;
    if (!force && (myWritesData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshMyWrites();
  }

  /// Pull-to-refresh writes: page=1
  Future<void> refreshMyWrites() async {
    if (myWritesLoading.value) return;
    myWritesLoading.value = true;
    myWritesLoadMoreLoading.value = false;
    myWritesPage.value = 1;
    myWritesHasNext.value = false;

    await _repo.getMyWritePosts(
      page: 1,
      limit: myWritesLimit.value,
      onSuccess: (model) {
        myWritesData.value = model.data;
        myWritesPage.value = model.pagination?.page ?? 1;
        myWritesHasNext.value = model.pagination?.hasNext ?? false;
        myWritesLoading.value = false;
      },
      onError: (_) {
        myWritesLoading.value = false;
      },
    );
  }

  /// Pagination: load next page of writes.
  Future<void> loadMoreMyWrites() async {
    if (myWritesLoading.value) return;
    if (myWritesLoadMoreLoading.value || !myWritesHasNext.value) return;
    myWritesLoadMoreLoading.value = true;

    await _repo.getMyWritePosts(
      page: myWritesPage.value + 1,
      limit: myWritesLimit.value,
      onSuccess: (model) {
        final existing = myWritesData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        myWritesData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? myWritesData.value?.isFollowing,
        );
        myWritesPage.value = model.pagination?.page ?? (myWritesPage.value + 1);
        myWritesHasNext.value = model.pagination?.hasNext ?? false;
        myWritesLoadMoreLoading.value = false;
      },
      onError: (_) {
        myWritesLoadMoreLoading.value = false;
      },
    );
  }

  /// Ensure zeals are loaded at least once (won't refetch if already present).
  Future<void> loadMyZealsIfNeeded() async {
    return loadMyZeals(force: false);
  }

  /// Load zeals. If [force] is true, always hits API (used when user switches to Zeals tab).
  Future<void> loadMyZeals({required bool force}) async {
    if (myZealsLoading.value) return;
    if (!force && (myZealsData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshMyZeals();
  }

  /// Pull-to-refresh posts: page=1
  Future<void> refreshMyPosts() async {
    if (myPostsLoading.value) return;
    myPostsLoading.value = true;
    myPostsLoadMoreLoading.value = false;
    myPostsPage.value = 1;
    myPostsHasNext.value = false;

    await _repo.getMyPosts(
      page: 1,
      limit: myPostsLimit.value,
      onSuccess: (model) {
        myPostsData.value = model.data;
        myPostsPage.value = model.pagination?.page ?? 1;
        myPostsHasNext.value = model.pagination?.hasNext ?? false;
        myPostsLoading.value = false;
      },
      onError: (_) {
        myPostsLoading.value = false;
      },
    );
  }

  /// Pagination: load next page if available.
  Future<void> loadMoreMyPosts() async {
    if (myPostsLoading.value) return;
    if (myPostsLoadMoreLoading.value || !myPostsHasNext.value) return;
    myPostsLoadMoreLoading.value = true;

    await _repo.getMyPosts(
      page: myPostsPage.value + 1,
      limit: myPostsLimit.value,
      onSuccess: (model) {
        final existing = myPostsData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        myPostsData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? myPostsData.value?.isFollowing,
        );
        myPostsPage.value = model.pagination?.page ?? (myPostsPage.value + 1);
        myPostsHasNext.value = model.pagination?.hasNext ?? false;
        myPostsLoadMoreLoading.value = false;
      },
      onError: (_) {
        myPostsLoadMoreLoading.value = false;
      },
    );
  }

  /// Pull-to-refresh zeals: page=1
  Future<void> refreshMyZeals() async {
    if (myZealsLoading.value) return;
    myZealsLoading.value = true;
    myZealsLoadMoreLoading.value = false;
    myZealsPage.value = 1;
    myZealsHasNext.value = false;

    await _repo.getMyZeals(
      page: 1,
      limit: myZealsLimit.value,
      onSuccess: (model) {
        myZealsData.value = model.data;
        myZealsPage.value = model.pagination?.page ?? 1;
        myZealsHasNext.value = model.pagination?.hasNext ?? false;
        myZealsLoading.value = false;
      },
      onError: (_) {
        myZealsLoading.value = false;
      },
    );
  }

  /// Pagination: load next page if available.
  Future<void> loadMoreMyZeals() async {
    if (myZealsLoading.value) return;
    if (myZealsLoadMoreLoading.value || !myZealsHasNext.value) return;
    myZealsLoadMoreLoading.value = true;

    await _repo.getMyZeals(
      page: myZealsPage.value + 1,
      limit: myZealsLimit.value,
      onSuccess: (model) {
        final existing = myZealsData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        myZealsData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? myZealsData.value?.isFollowing,
        );
        myZealsPage.value = model.pagination?.page ?? (myZealsPage.value + 1);
        myZealsHasNext.value = model.pagination?.hasNext ?? false;
        myZealsLoadMoreLoading.value = false;
      },
      onError: (_) {
        myZealsLoadMoreLoading.value = false;
      },
    );
  }

  void _removeFromData(Rx<PostDataResponse?> dataRef, String id) {
    final list = dataRef.value?.posts ?? [];
    if (list.isEmpty) return;
    dataRef.value = PostDataResponse(
      posts: list.where((p) => p.id != id).toList(),
      isFollowing: dataRef.value?.isFollowing,
    );
  }

  void removePostById(String id) => _removeFromData(myPostsData, id);
  void removeTaggedPostById(String id) => _removeFromData(myTaggedData, id);
  void removeWritePostById(String id) => _removeFromData(myWritesData, id);
  void removePollPostById(String id) => _removeFromData(myPollsData, id);
  void removeZealById(String id) => _removeFromData(myZealsData, id);

  /// Optimistic update: toggle save state immediately, then call API. On error, revert.
  /// [dataRef] is the Rx<PostDataResponse?> (e.g. myPostsData) and [index] the item index.
  Future<void> saveUnSavePost(
    BuildContext context,
    String type,
    String postId,
    Rx<PostDataResponse?> dataRef,
    int index,
  ) async {
    final list = dataRef.value?.posts ?? [];
    if (index < 0 || index >= list.length) return;
    final previousSaved = list[index].isSaved ?? false;
    final updated = List<PostData>.from(list);
    updated[index].isSaved = !previousSaved;
    dataRef.value = PostDataResponse(posts: updated, isFollowing: dataRef.value?.isFollowing);
    bookmarkRefreshTrigger.value++;

    await _postRepository.savePost(
      data: {"contentType": type, "contentId": postId},
      onSuccess: (ApiResponse response) {
        Get.find<HomeController>().feedData.value!.posts![index].isSaved = response.data['isSaved'];
        Get.find<HomeController>().feedData.refresh();
        update();
      },
      onError: (AppException error) {
        final reverted = List<PostData>.from(dataRef.value?.posts ?? []);
        if (index < reverted.length) reverted[index].isSaved = previousSaved;
        dataRef.value = PostDataResponse(posts: reverted, isFollowing: dataRef.value?.isFollowing);
        bookmarkRefreshTrigger.value++;
        AppFunctions().showToast(error.message, bgColor: AppColors.red);
      },
    );
  }
}
