import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/userlikelist_model.dart';
import 'package:omeeba_new/core/repository/content_repository.dart';
import 'package:omeeba_new/core/repository/profile_repository.dart';
import 'package:omeeba_new/core/utils/exports.dart';

class LikedUsersController extends GetxController {
  final repository = ContentRepository();
  final ProfileRepository _profileRepo = ProfileRepository();

  RxBool isLoading = false.obs;

  RxList<LikedUser> users = <LikedUser>[].obs;
  RxList<LikedUser> filteredUsers = <LikedUser>[].obs;

  final TextEditingController searchController = TextEditingController();


  final Rx<String?> followActionLoadingForUserId = Rx<String?>(null);

  LikedUser _userWithFollowing(LikedUser u, bool following) => LikedUser(
        id: u.id,
        name: u.name,
        username: u.username,
        bio: u.bio,
        profileImage: u.profileImage,
        coverImage: u.coverImage,
        isFollowing: following,
        isSelf: u.isSelf,
      );

  void _setUserFollowing(String userId, bool following) {
    users.assignAll(
      users.map((u) => u.id == userId ? _userWithFollowing(u, following) : u).toList(),
    );
    filteredUsers.assignAll(
      filteredUsers.map((u) => u.id == userId ? _userWithFollowing(u, following) : u).toList(),
    );
  }

  Future<void> getLikedUsers({
    required String contentType,
    required String contentId,
  }) async {
    isLoading.value = true;

    await repository.getLikedUsers(
      contentType: contentType,
      contentId: contentId,
      onSuccess: (data) {
        users.assignAll(data.data.users);
        filteredUsers.assignAll(data.data.users);

        print(filteredUsers.length);
      },

      onError: (error) {
        Get.snackbar("Error", error.message);
      },
    );

    isLoading.value = false;
  }

  void searchUser(String value) {
    final query = value.trim().toLowerCase();

    if (query.isEmpty) {
      filteredUsers.assignAll(users);
    } else {
      filteredUsers.assignAll(
        users.where((e) {
          return e.name
                  .toLowerCase()
                  .contains(query) ||
              e.username
                  .toLowerCase()
                  .contains(query);
        }).toList(),
      );
    }
  }


  Future<void> followLikedUser(
    String userId, {
    void Function()? onSuccess,
    void Function(String message)? onError,
  }) async {
    if (userId.isEmpty || followActionLoadingForUserId.value != null) return;
    followActionLoadingForUserId.value = userId;
    await _profileRepo.followUser(
      userId: userId,
      onSuccess: () {
        _setUserFollowing(userId, true);
        followActionLoadingForUserId.value = null;
        onSuccess?.call();
      },
      onError: (AppException e) {
        followActionLoadingForUserId.value = null;
        onError?.call(e.message);
      },
    );
  }

  Future<void> unfollowLikedUser(
    String userId, {
    void Function()? onSuccess,
    void Function(String message)? onError,
  }) async {
    if (userId.isEmpty || followActionLoadingForUserId.value != null) return;
    followActionLoadingForUserId.value = userId;
    await _profileRepo.unfollowUser(
      userId: userId,
      onSuccess: () {
        _setUserFollowing(userId, false);
        followActionLoadingForUserId.value = null;
        onSuccess?.call();
      },
      onError: (AppException e) {
        followActionLoadingForUserId.value = null;
        onError?.call(e.message);
      },
    );
  }

  Future<void> syncLikedUserFollowStatus(String userId) async {
    if (userId.isEmpty) return;
    await _profileRepo.getOtherUserProfile(
      userId: userId,
      onSuccess: (data) {
        final status = data.data?.profile?.followStatus;
        bool isFollowing = false;
        if (status is bool) {
          isFollowing = status;
        } else if (status is String) {
          isFollowing = status.toLowerCase() == 'following';
        }
        _setUserFollowing(userId, isFollowing);
      },
      onError: (_) {},
    );
  }
}
