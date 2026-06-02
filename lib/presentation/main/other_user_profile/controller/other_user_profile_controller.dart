import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/follow_list_response_model.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/models/user_profile_response_model.dart';
import 'package:omeeba_new/core/repository/home_repository.dart';
import 'package:omeeba_new/core/repository/post_repository.dart';
import 'package:omeeba_new/core/repository/profile_repository.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/utils/exports.dart';
import '../../home/controller/home_controller.dart';

class OtherUserProfileController extends GetxController {
  final ProfileRepository _repo = ProfileRepository();
  final HomeRepository _homeRepo = Get.find<HomeRepository>();
  final PostRepository _postRepository = PostRepository();

  /// Increment to force bookmark UI refresh (e.g. in pushed detail screen).
  final RxInt bookmarkRefreshTrigger = 0.obs;

  /// Increment to force comment count UI refresh (e.g. in pushed detail screen).
  final RxInt commentRefreshTrigger = 0.obs;

  // ── Profile ───────────────────────────────────────────────────────────────
  final Rx<Profile?> profile = Rx<Profile?>(null);
  final RxBool isLoading = true.obs;
  final RxBool isFollowing = false.obs;
  final RxBool followActionLoading = false.obs;

  // ── Posts tab ─────────────────────────────────────────────────────────────
  final Rx<PostDataResponse?> postsData = Rx<PostDataResponse?>(null);
  final RxBool postsLoading = false.obs;
  final RxBool postsLoadMoreLoading = false.obs;
  final RxInt postsPage = 1.obs;
  final RxBool postsHasNext = false.obs;
  final RxInt postsLimit = 15.obs;

  // ── Zeals tab ─────────────────────────────────────────────────────────────
  final Rx<PostDataResponse?> zealsData = Rx<PostDataResponse?>(null);
  final RxBool zealsLoading = false.obs;
  final RxBool zealsLoadMoreLoading = false.obs;
  final RxInt zealsPage = 1.obs;
  final RxBool zealsHasNext = false.obs;
  final RxInt zealsLimit = 15.obs;

  // ── Writes tab ────────────────────────────────────────────────────────────
  final Rx<PostDataResponse?> writesData = Rx<PostDataResponse?>(null);
  final RxBool writesLoading = false.obs;
  final RxBool writesLoadMoreLoading = false.obs;
  final RxInt writesPage = 1.obs;
  final RxBool writesHasNext = false.obs;
  final RxInt writesLimit = 10.obs;

  // ── Polls tab ─────────────────────────────────────────────────────────────
  final Rx<PostDataResponse?> pollsData = Rx<PostDataResponse?>(null);
  final RxBool pollsLoading = false.obs;
  final RxBool pollsLoadMoreLoading = false.obs;
  final RxInt pollsPage = 1.obs;
  final RxBool pollsHasNext = false.obs;
  final RxInt pollsLimit = 10.obs;

  // ── Tagged tab ────────────────────────────────────────────────────────────
  final Rx<PostDataResponse?> taggedData = Rx<PostDataResponse?>(null);
  final RxBool taggedLoading = false.obs;
  final RxBool taggedLoadMoreLoading = false.obs;
  final RxInt taggedPage = 1.obs;
  final RxBool taggedHasNext = false.obs;
  final RxInt taggedLimit = 10.obs;

  // ── Follow list (Following / Audience) ─────────────────────────────────────
  final RxString followListType = 'following'.obs; // 'following' | 'followers'
  final RxList<FollowListItem> followListItems = <FollowListItem>[].obs;
  final RxBool followListLoading = true.obs;
  final RxBool followListLoadMoreLoading = false.obs;
  final RxInt followListPage = 1.obs;
  final RxBool followListHasNext = false.obs;
  static const int followListLimit = 20;
  final Rx<String?> followListActionLoadingForId = Rx<String?>(null);

  late final String userId;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is String) {
      userId = args;
    } else if (args is Map) {
      userId = args['userId']?.toString() ?? '';
    } else {
      userId = '';
    }
    if (userId.isNotEmpty) {
      fetchProfile();
    } else {
      isLoading.value = false;
    }
  }

  void setFollowListType(String type) {
    followListType.value = type;
  }

  bool get isFollowListFollowing => followListType.value == 'following';

  Future<void> loadFollowList() async {
    if (userId.isEmpty) {
      followListLoading.value = false;
      return;
    }
    followListLoading.value = true;
    followListPage.value = 1;
    followListHasNext.value = false;
    await _fetchFollowList(page: 1, replace: true);
    followListLoading.value = false;
  }

  Future<void> loadMoreFollowList() async {
    if (followListLoadMoreLoading.value || !followListHasNext.value) return;
    followListLoadMoreLoading.value = true;
    await _fetchFollowList(page: followListPage.value + 1, replace: false);
    followListLoadMoreLoading.value = false;
  }

  Future<void> _fetchFollowList({required int page, required bool replace}) async {
    void onSuccess(FollowListResponseModel data) {
      final list = data.data ?? [];
      if (replace) {
        followListItems.assignAll(list);
      } else {
        followListItems.addAll(list);
      }
      followListPage.value = data.pagination?.page ?? page;
      followListHasNext.value = data.pagination?.hasNext ?? false;
    }

    void onError(AppException _) {}
    if (isFollowListFollowing) {
      await _repo.getFollowing(
        userId: userId,
        page: page,
        limit: followListLimit,
        onSuccess: onSuccess,
        onError: onError,
      );
    } else {
      await _repo.getFollowers(
        userId: userId,
        page: page,
        limit: followListLimit,
        onSuccess: onSuccess,
        onError: onError,
      );
    }
  }

  Future<void> followUserInList(
    String targetUserId, {
    void Function()? onSuccess,
    void Function(String)? onError,
  }) async {
    if (followListActionLoadingForId.value != null) return;
    followListActionLoadingForId.value = targetUserId;
    await _repo.followUser(
      userId: targetUserId,
      onSuccess: () {
        _updateFollowListItemStatus(targetUserId, 'following');
        followListActionLoadingForId.value = null;
        onSuccess?.call();
      },
      onError: (e) {
        followListActionLoadingForId.value = null;
        onError?.call(e.message);
      },
    );
  }

  Future<void> unfollowUserInList(
    String targetUserId, {
    void Function()? onSuccess,
    void Function(String)? onError,
  }) async {
    if (followListActionLoadingForId.value != null) return;
    followListActionLoadingForId.value = targetUserId;
    await _repo.unfollowUser(
      userId: targetUserId,
      onSuccess: () {
        _updateFollowListItemStatus(targetUserId, 'not_following');
        followListActionLoadingForId.value = null;
        onSuccess?.call();
      },
      onError: (e) {
        followListActionLoadingForId.value = null;
        onError?.call(e.message);
      },
    );
  }

  void _updateFollowListItemStatus(String id, String status) {
    final i = followListItems.indexWhere((e) => e.id == id);
    if (i >= 0) {
      followListItems[i] = followListItems[i].copyWith(status: status);
      followListItems.refresh();
    }
  }

  /// [FollowingListView] keeps an **untagged** controller; nested profiles use **tagged** controllers.
  /// When follow/unfollow happens on a nested profile, sync the open list's row for that user.
  void _propagateFollowChangeToOpenFollowList(String profileUserId, String listItemStatus) {
    if (!Get.isRegistered<OtherUserProfileController>()) return;
    try {
      final openListCtrl = Get.find<OtherUserProfileController>();
      if (identical(openListCtrl, this)) {
        _updateFollowListItemStatus(profileUserId, listItemStatus);
      } else {
        openListCtrl._updateFollowListItemStatus(profileUserId, listItemStatus);
      }
    } catch (_) {}
  }

  bool isFollowListActionLoading(String? id) => id != null && followListActionLoadingForId.value == id;

  // ── Profile ───────────────────────────────────────────────────────────────

  /// [silent] when true does not set [isLoading] (used for pull-to-refresh).
  Future<void> fetchProfile({bool silent = false}) async {
    if (!silent) isLoading.value = true;
    await _repo.getOtherUserProfile(
      userId: userId,
      onSuccess: (UserProfileResponseModel data) {
        profile.value = data.data?.profile;
        _syncFollowStatusFromProfile(data.data?.profile);
        if (!silent) isLoading.value = false;
        if (!silent) loadPostsIfNeeded(); // Load first tab when profile loads
      },
      onError: (AppException error) {
        if (!silent) isLoading.value = false;
        AppFunctions().showToast(error.message, bgColor: AppColors.red);
      },
    );
  }

  /// Syncs Follow/Following button from profile.followStatus.
  /// "following" -> Following button; "not_following" or anything else -> Follow button.
  void _syncFollowStatusFromProfile(Profile? p) {
    if (p == null) return;
    final status = p.followStatus;
    if (status is bool) {
      isFollowing.value = status;
      return;
    }
    if (status is String) {
      final s = status.toString().toLowerCase();
      isFollowing.value = (s == 'following');
      return;
    }
    // null or other type: treat as not following
    isFollowing.value = false;
  }

  Future<void> followUser({void Function()? onSuccess, void Function(String message)? onError}) async {
    if (followActionLoading.value) return;
    followActionLoading.value = true;
    await _repo.followUser(
      userId: userId,
      onSuccess: () {
        isFollowing.value = true;
        final p = profile.value;
        if (p != null) {
          profile.value = Profile(
            id: p.id,
            name: p.name,
            username: p.username,
            profileImage: p.profileImage,
            coverImage: p.coverImage,
            bio: p.bio,
            isVerifiedBadge: p.isVerifiedBadge,
            isAccountVerified: p.isAccountVerified,
            followersCount: (p.followersCount ?? 0) + 1,
            followingCount: p.followingCount,
            contentCounts: p.contentCounts,
            followStatus: 'following',
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
          );
        }
        followActionLoading.value = false;
        _propagateFollowChangeToOpenFollowList(userId, 'following');
        onSuccess?.call();
      },
      onError: (e) {
        followActionLoading.value = false;
        onError?.call(e.message);
      },
    );
  }

  Future<void> unfollowUser({void Function()? onSuccess, void Function(String message)? onError}) async {
    if (followActionLoading.value) return;
    followActionLoading.value = true;
    await _repo.unfollowUser(
      userId: userId,
      onSuccess: () {
        isFollowing.value = false;
        final p = profile.value;
        if (p != null) {
          profile.value = Profile(
            id: p.id,
            name: p.name,
            username: p.username,
            profileImage: p.profileImage,
            coverImage: p.coverImage,
            bio: p.bio,
            isVerifiedBadge: p.isVerifiedBadge,
            isAccountVerified: p.isAccountVerified,
            followersCount: (p.followersCount ?? 1) - 1,
            followingCount: p.followingCount,
            contentCounts: p.contentCounts,
            followStatus: 'none',
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
          );
        }
        followActionLoading.value = false;
        _propagateFollowChangeToOpenFollowList(userId, 'not_following');
        onSuccess?.call();
      },
      onError: (e) {
        followActionLoading.value = false;
        onError?.call(e.message);
      },
    );
  }

  /// Finds [post] in one of the content lists; returns (dataRef, index) or null.
  ({Rx<PostDataResponse?> dataRef, int index})? _findPostInLists(String? postId) {
    if (postId == null || postId.isEmpty) return null;
    final postsList = postsData.value?.posts ?? [];
    int i = postsList.indexWhere((p) => p.id == postId);
    if (i >= 0) return (dataRef: postsData, index: i);
    final writesList = writesData.value?.posts ?? [];
    i = writesList.indexWhere((p) => p.id == postId);
    if (i >= 0) return (dataRef: writesData, index: i);
    final zealsList = zealsData.value?.posts ?? [];
    i = zealsList.indexWhere((p) => p.id == postId);
    if (i >= 0) return (dataRef: zealsData, index: i);
    final pollsList = pollsData.value?.posts ?? [];
    i = pollsList.indexWhere((p) => p.id == postId);
    if (i >= 0) return (dataRef: pollsData, index: i);
    final taggedList = taggedData.value?.posts ?? [];
    i = taggedList.indexWhere((p) => p.id == postId);
    if (i >= 0) return (dataRef: taggedData, index: i);
    return null;
  }

  /// Optimistic bookmark toggle: update UI instantly, then call save-post API. Revert on error.
  /// Works for posts shown in lists or in the pushed detail screen (same [post] reference).
  Future<void> saveUnSavePost(BuildContext context, PostData post) async {
    final postId = post.id ?? '';
    if (postId.isEmpty) return;

    final found = _findPostInLists(postId);
    if (found == null) {
      final previousSaved = post.isSaved ?? false;
      post.isSaved = !previousSaved;
      bookmarkRefreshTrigger.value++;
      await _postRepository.savePost(
        data: {'contentType': post.contentType ?? 'Poll', 'contentId': postId},
        onSuccess: (ApiResponse response) {
          final controller = Get.find<HomeController>();

          controller.feedData.value = controller.feedData.value
            ?..posts = controller.feedData.value!.posts!.map((e) {
              if (e.id == postId) {
                e.isSaved = response.data["isSaved"];
              }
              return e;
            }).toList();

          controller.feedData.refresh();
        },

        onError: (AppException error) {
          post.isSaved = previousSaved;
          bookmarkRefreshTrigger.value++;
          AppFunctions().showToast(error.message, bgColor: AppColors.red);
        },
      );
      return;
    }
    final list = found.dataRef.value?.posts ?? [];
    final index = found.index;
    if (index < 0 || index >= list.length) return;
    final previousSaved = list[index].isSaved ?? false;
    final updated = List<PostData>.from(list);
    updated[index].isSaved = !previousSaved;
    found.dataRef.value = PostDataResponse(posts: updated, isFollowing: found.dataRef.value?.isFollowing);
    bookmarkRefreshTrigger.value++;

    await _postRepository.savePost(
      data: {'contentType': post.contentType ?? 'Poll', 'contentId': postId},
      onSuccess: (ApiResponse response) {
        final controller = Get.find<HomeController>();

        controller.feedData.value = controller.feedData.value
          ?..posts = controller.feedData.value!.posts!.map((e) {
            if (e.id == postId) {
              e.isSaved = response.data["isSaved"];
            }
            return e;
          }).toList();

        controller.feedData.refresh();
      },

      onError: (AppException error) {
        final reverted = List<PostData>.from(found.dataRef.value?.posts ?? []);
        if (index < reverted.length) reverted[index].isSaved = previousSaved;
        found.dataRef.value = PostDataResponse(posts: reverted, isFollowing: found.dataRef.value?.isFollowing);
        bookmarkRefreshTrigger.value++;
        AppFunctions().showToast(error.message, bgColor: AppColors.red);
      },
    );
  }

  /// Load data for the given tab only when user selects that tab. Call from view on tab change.
  void loadTabIfNeeded(int tabIndex) {
    switch (tabIndex) {
      case 0:
        loadPostsIfNeeded();
        break;
      case 1:
        loadZealsIfNeeded();
        break;
      case 2:
        loadWritesIfNeeded();
        break;
      case 3:
        loadPollsIfNeeded();
        break;
      case 4:
        loadTaggedIfNeeded();
        break;
      default:
        loadPostsIfNeeded();
    }
  }

  /// Refreshes profile and the tab at [tabIndex]. Use for pull-to-refresh.
  /// tabIndex: 0=posts, 1=zeals, 2=writes, 3=polls, 4=tagged.
  Future<void> refreshProfileAndCurrentTab(int tabIndex) async {
    await Future.wait([fetchProfile(silent: true), _refreshTabByIndex(tabIndex)]);
  }

  Future<void> _refreshTabByIndex(int index) async {
    switch (index) {
      case 0:
        return refreshPosts();
      case 1:
        return refreshZeals();
      case 2:
        return refreshWrites();
      case 3:
        return refreshPolls();
      case 4:
        return refreshTagged();
      default:
        return refreshPosts();
    }
  }

  // ── Posts ─────────────────────────────────────────────────────────────────

  Future<void> loadPostsIfNeeded() async => loadPosts(force: false);

  Future<void> loadPosts({required bool force}) async {
    if (postsLoading.value) return;
    if (!force && (postsData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshPosts();
  }

  Future<void> refreshPosts() async {
    if (postsLoading.value) return;
    postsLoading.value = true;
    postsLoadMoreLoading.value = false;
    postsPage.value = 1;
    postsHasNext.value = false;
    await _repo.getOtherUserPosts(
      userId: userId,
      page: 1,
      limit: postsLimit.value,
      onSuccess: (PostListResponseModel model) {
        postsData.value = model.data;
        postsPage.value = model.pagination?.page ?? 1;
        postsHasNext.value = model.pagination?.hasNext ?? false;
        postsLoading.value = false;
      },
      onError: (_) => postsLoading.value = false,
    );
  }

  Future<void> loadMorePosts() async {
    if (postsLoading.value || postsLoadMoreLoading.value || !postsHasNext.value) return;
    postsLoadMoreLoading.value = true;
    await _repo.getOtherUserPosts(
      userId: userId,
      page: postsPage.value + 1,
      limit: postsLimit.value,
      onSuccess: (PostListResponseModel model) {
        final existing = postsData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        postsData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? postsData.value?.isFollowing,
        );
        postsPage.value = model.pagination?.page ?? (postsPage.value + 1);
        postsHasNext.value = model.pagination?.hasNext ?? false;
        postsLoadMoreLoading.value = false;
      },
      onError: (_) => postsLoadMoreLoading.value = false,
    );
  }

  // ── Zeals ─────────────────────────────────────────────────────────────────

  Future<void> loadZealsIfNeeded() async => loadZeals(force: false);

  Future<void> loadZeals({required bool force}) async {
    if (zealsLoading.value) return;
    if (!force && (zealsData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshZeals();
  }

  Future<void> refreshZeals() async {
    if (zealsLoading.value) return;
    zealsLoading.value = true;
    zealsLoadMoreLoading.value = false;
    zealsPage.value = 1;
    zealsHasNext.value = false;
    await _repo.getOtherUserZeals(
      userId: userId,
      page: 1,
      limit: zealsLimit.value,
      onSuccess: (PostListResponseModel model) {
        zealsData.value = model.data;
        zealsPage.value = model.pagination?.page ?? 1;
        zealsHasNext.value = model.pagination?.hasNext ?? false;
        zealsLoading.value = false;
      },
      onError: (_) => zealsLoading.value = false,
    );
  }

  Future<void> loadMoreZeals() async {
    if (zealsLoading.value || zealsLoadMoreLoading.value || !zealsHasNext.value) return;
    zealsLoadMoreLoading.value = true;
    await _repo.getOtherUserZeals(
      userId: userId,
      page: zealsPage.value + 1,
      limit: zealsLimit.value,
      onSuccess: (PostListResponseModel model) {
        final existing = zealsData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        zealsData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? zealsData.value?.isFollowing,
        );
        zealsPage.value = model.pagination?.page ?? (zealsPage.value + 1);
        zealsHasNext.value = model.pagination?.hasNext ?? false;
        zealsLoadMoreLoading.value = false;
      },
      onError: (_) => zealsLoadMoreLoading.value = false,
    );
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> loadWritesIfNeeded() async => loadWrites(force: false);

  Future<void> loadWrites({required bool force}) async {
    if (writesLoading.value) return;
    if (!force && (writesData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshWrites();
  }

  Future<void> refreshWrites() async {
    if (writesLoading.value) return;
    writesLoading.value = true;
    writesLoadMoreLoading.value = false;
    writesPage.value = 1;
    writesHasNext.value = false;
    await _repo.getOtherUserWritePosts(
      userId: userId,
      page: 1,
      limit: writesLimit.value,
      onSuccess: (PostListResponseModel model) {
        writesData.value = model.data;
        writesPage.value = model.pagination?.page ?? 1;
        writesHasNext.value = model.pagination?.hasNext ?? false;
        writesLoading.value = false;
      },
      onError: (_) => writesLoading.value = false,
    );
  }

  Future<void> loadMoreWrites() async {
    if (writesLoading.value || writesLoadMoreLoading.value || !writesHasNext.value) return;
    writesLoadMoreLoading.value = true;
    await _repo.getOtherUserWritePosts(
      userId: userId,
      page: writesPage.value + 1,
      limit: writesLimit.value,
      onSuccess: (PostListResponseModel model) {
        final existing = writesData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        writesData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? writesData.value?.isFollowing,
        );
        writesPage.value = model.pagination?.page ?? (writesPage.value + 1);
        writesHasNext.value = model.pagination?.hasNext ?? false;
        writesLoadMoreLoading.value = false;
      },
      onError: (_) => writesLoadMoreLoading.value = false,
    );
  }

  // ── Polls ─────────────────────────────────────────────────────────────────

  Future<void> loadPollsIfNeeded() async => loadPolls(force: false);

  Future<void> loadPolls({required bool force}) async {
    if (pollsLoading.value) return;
    if (!force && (pollsData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshPolls();
  }

  Future<void> refreshPolls() async {
    if (pollsLoading.value) return;
    pollsLoading.value = true;
    pollsLoadMoreLoading.value = false;
    pollsPage.value = 1;
    pollsHasNext.value = false;
    await _repo.getOtherUserPolls(
      userId: userId,
      page: 1,
      limit: pollsLimit.value,
      onSuccess: (PostListResponseModel model) {
        pollsData.value = model.data;
        pollsPage.value = model.pagination?.page ?? 1;
        pollsHasNext.value = model.pagination?.hasNext ?? false;
        pollsLoading.value = false;
      },
      onError: (_) => pollsLoading.value = false,
    );
  }

  Future<void> loadMorePolls() async {
    if (pollsLoading.value || pollsLoadMoreLoading.value || !pollsHasNext.value) return;
    pollsLoadMoreLoading.value = true;
    await _repo.getOtherUserPolls(
      userId: userId,
      page: pollsPage.value + 1,
      limit: pollsLimit.value,
      onSuccess: (PostListResponseModel model) {
        final existing = pollsData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        pollsData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? pollsData.value?.isFollowing,
        );
        pollsPage.value = model.pagination?.page ?? (pollsPage.value + 1);
        pollsHasNext.value = model.pagination?.hasNext ?? false;
        pollsLoadMoreLoading.value = false;
      },
      onError: (_) => pollsLoadMoreLoading.value = false,
    );
  }

  /// Submit poll vote: optimistic update, then API; merge on success.
  void submitPollVote(String postId, String optionId) {
    final list = pollsData.value?.posts ?? [];
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
    pollsData.value = PostDataResponse(posts: newList, isFollowing: pollsData.value?.isFollowing);

    _homeRepo.submitPollVote(
      pollId: postId,
      optionId: optionId,
      onSuccess: (updatedPost) {
        final currentList = pollsData.value?.posts ?? [];
        if (index >= currentList.length || currentList[index].id != postId) return;
        final current = currentList[index];
        final merged = current.copyWith(
          options: updatedPost?.options ?? current.options,
          totalVotes: updatedPost?.totalVotes ?? current.totalVotes,
          hasVoted: updatedPost?.hasVoted ?? true,
          votedOptionId: updatedPost?.votedOptionId ?? optionId,
        );
        final mergedList = List<PostData>.from(currentList)..[index] = merged;
        pollsData.value = PostDataResponse(posts: mergedList, isFollowing: pollsData.value?.isFollowing);
      },
      onError: (_) {
        final currentList = pollsData.value?.posts ?? [];
        if (index < currentList.length && currentList[index].id == postId) {
          final revertedList = List<PostData>.from(currentList)..[index] = previousPost;
          pollsData.value = PostDataResponse(posts: revertedList, isFollowing: pollsData.value?.isFollowing);
        }
      },
    );
  }

  // ── Tagged ────────────────────────────────────────────────────────────────
  void _removeFromData(Rx<PostDataResponse?> dataRef, String id) {
    final list = dataRef.value?.posts ?? [];
    if (list.isEmpty) return;
    dataRef.value = PostDataResponse(
      posts: list.where((p) => p.id != id).toList(),
      isFollowing: dataRef.value?.isFollowing,
    );
  }

  void removeWritePostById(String id) => _removeFromData(writesData, id);

  void removePollPostById(String id) => _removeFromData(pollsData, id);

  void removePostById(String id) => _removeFromData(postsData, id);

  void removeTaggedPostById(String id) => _removeFromData(taggedData, id);

  void removeZealById(String id) => _removeFromData(zealsData, id);

  Future<void> loadTaggedIfNeeded() async => loadTagged(force: false);

  Future<void> loadTagged({required bool force}) async {
    if (taggedLoading.value) return;
    if (!force && (taggedData.value?.posts?.isNotEmpty ?? false)) return;
    await refreshTagged();
  }

  Future<void> refreshTagged() async {
    if (taggedLoading.value) return;
    taggedLoading.value = true;
    taggedLoadMoreLoading.value = false;
    taggedPage.value = 1;
    taggedHasNext.value = false;
    await _repo.getOtherUserMentionedPosts(
      userId: userId,
      page: 1,
      limit: taggedLimit.value,
      onSuccess: (PostListResponseModel model) {
        taggedData.value = model.data;
        taggedPage.value = model.pagination?.page ?? 1;
        taggedHasNext.value = model.pagination?.hasNext ?? false;
        taggedLoading.value = false;
      },
      onError: (_) => taggedLoading.value = false,
    );
  }

  Future<void> loadMoreTagged() async {
    if (taggedLoading.value || taggedLoadMoreLoading.value || !taggedHasNext.value) return;
    taggedLoadMoreLoading.value = true;
    await _repo.getOtherUserMentionedPosts(
      userId: userId,
      page: taggedPage.value + 1,
      limit: taggedLimit.value,
      onSuccess: (PostListResponseModel model) {
        final existing = taggedData.value?.posts ?? [];
        final newPosts = model.data?.posts ?? [];
        taggedData.value = PostDataResponse(
          posts: [...existing, ...newPosts],
          isFollowing: model.data?.isFollowing ?? taggedData.value?.isFollowing,
        );
        taggedPage.value = model.pagination?.page ?? (taggedPage.value + 1);
        taggedHasNext.value = model.pagination?.hasNext ?? false;
        taggedLoadMoreLoading.value = false;
      },
      onError: (_) => taggedLoadMoreLoading.value = false,
    );
  }
}
