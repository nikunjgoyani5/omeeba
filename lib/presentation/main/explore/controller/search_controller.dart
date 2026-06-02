import 'dart:async';

import 'package:get/get.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/models/search_hashtag_model.dart';
import 'package:omeeba_new/core/models/search_user_model.dart';
import 'package:omeeba_new/core/repository/explore_repository.dart';

class ExploreSearchController extends GetxController {
  final ExploreRepository _repo = Get.find<ExploreRepository>();

  static const String typeUsers = 'users';
  static const String typePosts = 'posts';
  static const String typeZeals = 'zeals';
  static const String typeHashtag = 'hashtag';
  String selectedType = 'users';

  static const int _debounceMs = 500;

  /// When set, search uses hashtag API (explore/hashtag/{tag}?contentType=...) instead of explore/search.
  final RxString initialHashtag = ''.obs;

  /// Last query user submitted (for tab switching).
  final RxString lastSearchQuery = ''.obs;

  final RxList<SearchUserData> users = <SearchUserData>[].obs;
  final RxList<PostData> posts = <PostData>[].obs;
  final RxList<PostData> zeals = <PostData>[].obs;
  final RxList<SearchHashtagData> hashtags = <SearchHashtagData>[].obs;
  final RxBool isLoading = false.obs;
  Timer? _debounceTimer;

  /// Called while typing (debounce) or on submit (immediate). type=users for Accounts.
  /// No-op when in hashtag mode (initialHashtag is set) — use searchHashtagByType instead.
  void onQueryChanged(String query, {bool submit = false}) {
    if (initialHashtag.value.isNotEmpty) return;

    _debounceTimer?.cancel();
    final trimmed = query.trim();
    lastSearchQuery.value = trimmed;
    if (trimmed.isEmpty) {
      users.clear();
      return;
    }

    if (submit) {
      // lastSearchQuery.value = trimmed;
      _search(trimmed, selectedType);
      return;
    }

    _debounceTimer = Timer(Duration(milliseconds: _debounceMs), () {
      _search(trimmed, selectedType);
    });
  }

  /// Called when user changes tab (after submit). Uses lastSearchQuery + type.
  /// When in hashtag mode, maps internal tab type → API contentType and calls searchHashtagByType.
  void searchByType(String type) {
    selectedType = type;
    final tag = initialHashtag.value.trim();
    if (tag.isNotEmpty) {
      final contentType = type == typeUsers
          ? contentTypeWrite
          : type == typePosts
          ? contentTypePost
          : type == typeZeals
          ? contentTypeZeal
          : contentTypePoll;
      searchHashtagByType(contentType);
      return;
    }
    // final query = lastSearchQuery.value.trim();
    final query = lastSearchQuery.value.trim();
    if (query.isEmpty) {
      selectedType = typeUsers;
      return;
    }
    _search(query, type);
  }

  /// Set hashtag for hashtag-mode search. Clears lists and stores tag.
  void setInitialHashtag(String tag) {
    final normalized = tag.startsWith('#') ? tag.substring(1) : tag;
    initialHashtag.value = normalized;
    lastSearchQuery.value = tag.startsWith('#') ? tag : '#$tag';
    users.clear();
    posts.clear();
    zeals.clear();
    hashtags.clear();
  }

  /// API content types for explore/hashtag/{tag}?contentType=...
  static const String contentTypeWrite = 'user';
  static const String contentTypePost = 'post';
  static const String contentTypeZeal = 'zeal';
  static const String contentTypePoll = 'hashtag';

  /// Calls explore/hashtag/{tag}?contentType={contentType}.
  /// [contentType] must be one of: write | post | zeal | poll.
  void searchHashtagByType(String contentType) {
    final tag = initialHashtag.value.trim();
    if (tag.isEmpty) return;
    isLoading.value = true;

    if (contentType == contentTypeWrite) {
      users.clear();
    } else if (contentType == contentTypePost) {
      posts.clear();
    } else if (contentType == contentTypeZeal) {
      zeals.clear();
    } else if (contentType == contentTypePoll) {
      hashtags.clear();
    }

    _repo.getHashtagContent(
      hashtag: tag,
      contentType: contentType,
      onUsersSuccess: (list) {
        users.assignAll(list);
        isLoading.value = false;
      },
      onPostsSuccess: (list) {
        if (contentType == contentTypePost) posts.assignAll(list);
        if (contentType == contentTypeZeal) zeals.assignAll(list);
        isLoading.value = false;
      },
      onHashtagsSuccess: (list) {
        hashtags.assignAll(list);
        isLoading.value = false;
      },
      onError: (_) {
        isLoading.value = false;
      },
    );
  }

  void _search(String query, String type) {
    isLoading.value = true;
    if (type == typeUsers) {
      users.clear();
    } else if (type == typePosts) {
      posts.clear();
    } else if (type == typeZeals) {
      zeals.clear();
    } else if (type == typeHashtag) {
      hashtags.clear();
    }

    if (type == typeHashtag) {
      _repo.searchExploreHashtags(
        query: query,
        onSuccess: (list) {
          hashtags.assignAll(list);
          isLoading.value = false;
        },
        onError: (_) {
          isLoading.value = false;
        },
      );
      return;
    }

    if (type == typePosts || type == typeZeals) {
      _repo.searchExploreContent(
        query: query,
        type: type,
        onSuccess: (list) {
          if (type == typePosts) posts.assignAll(list);
          if (type == typeZeals) zeals.assignAll(list);
          isLoading.value = false;
        },
        onError: (_) {
          isLoading.value = false;
        },
      );
      return;
    }

    _repo.searchExplore(
      query: query,
      type: type,
      onSuccess: (list) {
        if (type == typeUsers) users.assignAll(list);
        isLoading.value = false;
      },
      onError: (_) {
        isLoading.value = false;
      },
    );
  }

  void clearSearch() {
    initialHashtag.value = '';
    lastSearchQuery.value = '';
    users.clear();
    posts.clear();
    zeals.clear();
    hashtags.clear();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }
}
