import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/api_response.dart';
import 'package:omeeba_new/core/models/mention_user_model.dart';
import 'package:omeeba_new/core/repository/content_repository.dart';
import 'package:omeeba_new/core/repository/post_repository.dart';
import 'package:omeeba_new/core/repository/profile_repository.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';
import 'package:omeeba_new/presentation/main/dashboard/controller/dashboard_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/controller/zeals_controller.dart';

import '../../create_post/controller/create_post_controller.dart';
import '../../home/controller/home_controller.dart';

class PostDataController extends GetxController {
  ContentRepository get _contentRepository =>
      Get.isRegistered<ContentRepository>() ? Get.find<ContentRepository>() : Get.put(ContentRepository());

  ///new
  RxList<double> waves = RxList();
  double oneBarValue = 0;
  final double borderWidth = 10;
  final double barWidth = 2;
  final double barHorizontalMargin = 1;
  final double barInBoxCount = 30;
  RxDouble currentProgress = 0.0.obs;
  RxDouble scrollOffset = 0.0.obs;
  ScrollController scrollController = ScrollController();

  double get barTotalWidth => barWidth + (barHorizontalMargin * 2);

  double get boxWidth => barTotalWidth * barInBoxCount;

  int get previousBar => (scrollOffset.value / barTotalWidth).toInt();

  int get currentBars => (previousBar + (currentProgress.value * barInBoxCount)).toInt();

  ///finish new

  late final MentionTextController captionController;
  final FocusNode captionFocusNode = FocusNode();
  final RxString selectedSong = ''.obs;
  final RxString selectedAudioUrl = ''.obs;
  final Rx<Duration> audioStartTime = Duration.zero.obs;
  final Rx<Duration> audioEndTime = Duration.zero.obs;
  List<String> mentionedUsers = [];
  final RxInt characterCount = 1.obs;
  final RxBool isKeyboardVisible = false.obs;
  final RxBool isImageVisible = true.obs;
  final RxBool showMentionList = false.obs;
  final RxString mentionSearchQuery = ''.obs;
  final RxInt mentionStartPosition = (-1).obs;
  final int maxCharacters = 1000;
  final String initialCaption = '';

  /// Users selected from mention list - persist across searches so all mentions stay highlighted.
  final RxList<MentionUser> selectedMentionUsers = <MentionUser>[].obs;
  final RxList<MentionUser> mentionSearchResults = <MentionUser>[].obs;
  final RxInt mentionSearchPage = 1.obs;
  final RxBool mentionSearchHasNext = false.obs;
  final RxBool isLoadingMentionSearch = false.obs;
  final RxBool isLoadingMoreMentionUsers = false.obs;
  static const int _mentionSearchDebounceMs = 600;
  Timer? _mentionSearchDebounce;
  String _lastScheduledQuery = '';
  String _lastSearchedQuery = '';
  final ScrollController mentionListScrollController = ScrollController();

  List<MentionUser> get knownUsersForStyling {
    final ids = <String>{};
    final result = <MentionUser>[];
    for (final u in selectedMentionUsers) {
      if (ids.add(u.id)) result.add(u);
    }
    for (final u in mentionSearchResults) {
      if (ids.add(u.id)) result.add(u);
    }
    return result;
  }

  @override
  void onInit() {
    super.onInit();
    captionController = MentionTextController(getAvailableUsers: () => knownUsersForStyling, text: initialCaption);
    characterCount.value = initialCaption.length;
    captionController.addListener(updateCharacterCount);
    captionController.addListener(_onTextChanged);
    captionFocusNode.addListener(_onFocusChange);
    mentionListScrollController.addListener(_onMentionListScroll);
  }

  void _onMentionListScroll() {
    if (!mentionListScrollController.hasClients) return;
    final pos = mentionListScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 80) loadMoreMentionUsers();
  }

  void _scheduleMentionSearch() {
    final q = mentionSearchQuery.value.trim();
    if (q == _lastScheduledQuery) return;
    if (q == _lastSearchedQuery) return;
    _lastScheduledQuery = q;

    _mentionSearchDebounce?.cancel();
    _mentionSearchDebounce = Timer(Duration(milliseconds: _mentionSearchDebounceMs), () {
      final currentQ = mentionSearchQuery.value.trim();
      _lastScheduledQuery = '';
      if (currentQ.isEmpty) {
        _lastSearchedQuery = '';
        mentionSearchResults.clear();
        mentionSearchPage.value = 1;
        mentionSearchHasNext.value = false;
        return;
      }
      if (isLoadingMentionSearch.value) return;
      _lastSearchedQuery = currentQ;
      searchMentionUsers(page: 1);
    });
  }

  void searchMentionUsers({int page = 1}) {
    final query = mentionSearchQuery.value.trim();
    if (query.isEmpty) {
      mentionSearchResults.clear();
      return;
    }
    if (page == 1) {
      isLoadingMentionSearch.value = true;
    } else {
      isLoadingMoreMentionUsers.value = true;
    }
    final repo = Get.isRegistered<ProfileRepository>() ? Get.find<ProfileRepository>() : ProfileRepository();
    repo.searchUsers(
      query: query,
      page: page,
      onSuccess: (users, hasNext) {
        if (page == 1) {
          mentionSearchResults.assignAll(users);
          mentionSearchPage.value = 1;
        } else {
          mentionSearchResults.addAll(users);
          mentionSearchPage.value = page;
        }
        mentionSearchHasNext.value = hasNext;
        isLoadingMentionSearch.value = false;
        isLoadingMoreMentionUsers.value = false;
      },
      onError: (_) {
        isLoadingMentionSearch.value = false;
        isLoadingMoreMentionUsers.value = false;
      },
    );
  }

  void loadMoreMentionUsers() {
    if (isLoadingMoreMentionUsers.value || !mentionSearchHasNext.value) return;
    searchMentionUsers(page: mentionSearchPage.value + 1);
  }

  void updateCharacterCount() {
    characterCount.value = captionController.text.length;
  }

  void _onTextChanged() {
    final text = captionController.text;
    int cursorPosition = captionController.selection.baseOffset;
    if (cursorPosition < 0 || cursorPosition > text.length) {
      cursorPosition = text.length;
    }

    // Find the last @ symbol before cursor
    int lastAtIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        lastAtIndex = i;
        break;
      } else if (text[i] == ' ' || text[i] == '\n') {
        // Stop if we hit a space or newline before finding @
        break;
      }
    }

    if (lastAtIndex != -1) {
      final searchQuery = text.substring(lastAtIndex + 1, cursorPosition).trim();
      mentionStartPosition.value = lastAtIndex;
      mentionSearchQuery.value = searchQuery;
      showMentionList.value = true;
      _scheduleMentionSearch();
    } else {
      _mentionSearchDebounce?.cancel();
      _lastScheduledQuery = '';
      _lastSearchedQuery = '';
      showMentionList.value = false;
      mentionSearchQuery.value = '';
      mentionStartPosition.value = -1;
    }
  }

  void _onFocusChange() {
    isKeyboardVisible.value = captionFocusNode.hasFocus;
    // Hide/show image based on keyboard visibility
    isImageVisible.value = !captionFocusNode.hasFocus;
    // Hide mention list when keyboard closes
    if (!captionFocusNode.hasFocus) {
      showMentionList.value = false;
    }
  }

  RxList<String> mentionedUserIds = <String>[].obs;

  void toggleMentionList() {
    // When mention button is tapped, insert @ and show list
    final currentText = captionController.text;
    int cursorPosition = captionController.selection.baseOffset;
    // baseOffset can be -1 when field has no focus or selection is invalid
    if (cursorPosition < 0 || cursorPosition > currentText.length) {
      cursorPosition = currentText.length;
    }
    final textBefore = currentText.substring(0, cursorPosition);
    final textAfter = currentText.substring(cursorPosition);

    // Insert @ at cursor position

    captionController.text = '$textBefore@$textAfter';
    captionController.selection = TextSelection.fromPosition(TextPosition(offset: cursorPosition + 1));

    // Show mention list and open keyboard
    mentionStartPosition.value = cursorPosition;
    mentionSearchQuery.value = '';
    showMentionList.value = true;
    captionFocusNode.requestFocus();
  }

  List<MentionUser> getFilteredUsers() => mentionSearchResults;
  void addMention(MentionUser user) {
    final mention = '@${user.username}';

    int limitTofCaption = captionController.text.length + mention.length;
    if (limitTofCaption > 1000) {
      AppFunctions().showToast('Caption limit exceeded', bgColor: Colors.red);
      return;
    }
    if (!mentionedUsers.contains(mention)) {
      mentionedUsers.add(mention);
    }
    if (!mentionedUserIds.contains(user.id)) {
      mentionedUserIds.add(user.id);
    }
    if (!selectedMentionUsers.any((u) => u.id == user.id)) {
      selectedMentionUsers.add(user);
    }
    if (!mentionSearchResults.any((u) => u.id == user.id)) {
      mentionSearchResults.insert(0, user);
    }
    captionController.refreshStyling();

    // Insert mention into text field
    if (mentionStartPosition.value >= 0) {
      final currentText = captionController.text;
      int cursorPosition = captionController.selection.baseOffset;
      if (cursorPosition < 0 || cursorPosition > currentText.length) {
        cursorPosition = currentText.length;
      }
      final startPos = mentionStartPosition.value.clamp(0, currentText.length);
      final textBefore = currentText.substring(0, startPos);
      final textAfter = currentText.substring(cursorPosition);

      // Insert @username with space after it
      final newText = '$textBefore@${user.username} $textAfter';

      // Calculate the new cursor position (after the mention and space)
      final newCursorPosition = startPos + mention.length + 1;

      // Update text and cursor position using TextEditingValue to ensure both are set atomically
      captionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );

      // Ensure cursor position is set correctly after the frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (captionController.text == newText) {
          captionController.selection = TextSelection.collapsed(offset: newCursorPosition);
        }
      });
    } else {
      // If no @ position found, append at the end
      final currentText = captionController.text;
      final newText = currentText.isEmpty ? '@${user.username} ' : '$currentText @${user.username} ';
      final newCursorPosition = newText.length;

      captionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );

      // Ensure cursor position is set correctly after the frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (captionController.text == newText) {
          captionController.selection = TextSelection.collapsed(offset: newCursorPosition);
        }
      });
    }

    // Hide mention list after selection
    showMentionList.value = false;
    mentionSearchQuery.value = '';
    mentionStartPosition.value = -1;
  }

  // void addMention(MentionUser user) {
  //   final mention = '@${user.username}';
  //   if (!mentionedUsers.contains(mention)) {
  //     mentionedUsers.add(mention);
  //     mentionedUsersIds.add(user.id);
  //   }
  //   if (!mentionSearchResults.any((u) => u.id == user.id)) {
  //     mentionSearchResults.insert(0, user);
  //   }
  //
  //   // Insert mention into FlutterMentions text field
  //   if (mentionStartPosition.value >= 0) {
  //     final currentText = captionController.text;
  //     final cursorPosition = captionController.selection.baseOffset;
  //     final textBefore = currentText.substring(0, mentionStartPosition.value);
  //     final textAfter = currentText.substring(cursorPosition);
  //
  //     // Insert @username with proper formatting for FlutterMentions
  //     // FlutterMentions will automatically format it based on the Mention configuration
  //     final newText = '$textBefore@${user.username} $textAfter';
  //     captionController.text = newText;
  //
  //     // Set cursor position after the mention
  //     final newCursorPosition = mentionStartPosition.value + mention.length + 1;
  //     captionController.selection = TextSelection.fromPosition(TextPosition(offset: newCursorPosition));
  //   } else {
  //     // If no @ position found, append at the end
  //     final currentText = captionController.text;
  //     final newText = currentText.isEmpty ? '@${user.username} ' : '$currentText @${user.username} ';
  //     captionController.text = newText;
  //     captionController.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
  //   }
  //
  //   // Hide mention list after selection
  //   showMentionList.value = false;
  //   mentionSearchQuery.value = '';
  //   mentionStartPosition.value = -1;
  // }

  void removeMention(String mention, int index) {
    // Only remove from mentions list, not from text field
    mentionedUsers.remove(mention);
    mentionedUsers.removeAt(index);
  }

  void removeSong() {
    selectedSong.value = '';
  }

  void selectSong(String songTitle) {
    selectedSong.value = songTitle;
  }

  void setAudioTrim({required String audioUrl, required Duration startTime, required Duration endTime}) {
    selectedAudioUrl.value = audioUrl;
    audioStartTime.value = startTime;
    audioEndTime.value = endTime;
  }

  void uploadZealVideo({
    required String? videoFilePath,
    required void Function(ValueNotifier<double> progress) onUploadStarted,
    required void Function() onUploadComplete,
  }) {
    if (videoFilePath == null || videoFilePath.isEmpty) {
      AppFunctions().showToast('No video file to upload', bgColor: Colors.red);
      return;
    }

    final file = File(videoFilePath);
    if (!file.existsSync()) {
      AppFunctions().showToast('Video file not found', bgColor: Colors.red);
      return;
    }

    final progress = ValueNotifier<double>(0);
    onUploadStarted(progress);

    _contentRepository.uploadZealVideo(
      file: file,
      onProgress: (percent) => progress.value = percent,
      onSuccess: (uploadData) {
        final zealDraftId = uploadData is Map ? uploadData['zealDraftId']?.toString() : null;
        if (zealDraftId == null || zealDraftId.isEmpty) {
          onUploadComplete();
          progress.dispose();
          AppFunctions().showToast('Invalid upload response', bgColor: Colors.red);
          return;
        }
        Future.delayed(Duration(seconds: 2), () {
          final audio = Get.isRegistered<CreatePostController>()
              ? Get.find<CreatePostController>().zealAudioForApi
              : (audioAction: 'original', musicId: null, musicStartTime: null, musicEndTime: null);
          _contentRepository.createZeal(
            zealDraftId: zealDraftId,
            caption: captionController.text.trim(),
            mentionedUserIds: List<String>.from(mentionedUserIds),
            audioAction: audio.audioAction,
            musicId: audio.musicId,
            musicStartTime: audio.musicStartTime,
            musicEndTime: audio.musicEndTime,
            isDevelopByAi: false,
            onSuccess: (_) async {
              progress.value = 100;
              onUploadComplete();
              progress.dispose();
              AppFunctions().showToast('Post created successfully', bgColor: Colors.green);
              clearAllAfterPostSuccess();
              if (Get.isRegistered<CreatePostController>()) {
                await Get.find<CreatePostController>().clearMusicAfterPostSuccess();
              }
              Get.until((route) => route.isFirst);
              await Get.find<ZealsController>().refreshZeals();
              Get.find<DashboardController>().changeIndex(3);
            },
            onError: (AppException error) {
              onUploadComplete();
              progress.dispose();
              AppFunctions().showToast(error.message, bgColor: Colors.red);
            },
          );
        });
      },
      onError: (AppException error) {
        onUploadComplete();
        progress.dispose();
        AppFunctions().showToast(error.message, bgColor: Colors.red);
      },
    );
  }

  @override
  void onClose() {
    _mentionSearchDebounce?.cancel();
    mentionListScrollController.dispose();
    captionController.dispose();
    captionFocusNode.dispose();
    super.onClose();
  }

  RxBool createPostLoader = false.obs;
  PostRepository postRepository = PostRepository();

  /// Clears all post/zeal form state after a successful create. Call from createPostAPI and uploadZealVideo success.
  void clearAllAfterPostSuccess() {
    captionController.clear();
    characterCount.value = initialCaption.length;
    selectedSong.value = '';
    selectedAudioUrl.value = '';
    audioStartTime.value = Duration.zero;
    audioEndTime.value = Duration.zero;
    mentionedUsers.clear();
    mentionedUserIds.clear();
    selectedMentionUsers.clear();
    mentionSearchResults.clear();
    mentionSearchQuery.value = '';
    mentionSearchPage.value = 1;
    mentionSearchHasNext.value = false;
    showMentionList.value = false;
    mentionStartPosition.value = -1;
    captionController.refreshStyling();
  }

  Future<void> createPostAPI(BuildContext context, List<File> imagesList) async {
    createPostLoader.value = true;
    await postRepository.createPost(
      data: {"caption": captionController.text, "mentionedUserIds": List<String>.from(mentionedUserIds)},
      imageList: imagesList,

      onSuccess: (ApiResponse response) {
        try {
          createPostLoader.value = false;
          AppFunctions().showToast(response.message ?? 'Post created!');
          clearAllAfterPostSuccess();
          Get.until((route) => route.settings.name == AppRoutes.dashboard);
          if (Get.isRegistered<HomeController>()) {
            Get.find<HomeController>().refreshFeedInBackground();
            Get.find<DashboardController>().changeIndex(0);
          }
        } catch (e) {
          debugPrint('error:::${e.toString()} ');
          createPostLoader.value = false;
          AppFunctions().showToast(response.message ?? 'Something went wrong!!', bgColor: AppColors.red);
        }
      },
      onError: (AppException error) {
        createPostLoader.value = false;
        String message = error.message;
        AppFunctions().showToast(message, bgColor: AppColors.red);
      },
    );
  }
}
