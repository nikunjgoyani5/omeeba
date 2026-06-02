import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/models/mention_user_model.dart';
import 'package:omeeba_new/core/models/music_library_item_model.dart';
import 'package:omeeba_new/core/utils/audio_file_helper.dart';
import 'package:omeeba_new/core/repository/content_repository.dart';
import 'package:omeeba_new/core/repository/profile_repository.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';
import 'package:omeeba_new/core/widgets/debounce_action.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/presentation/main/dashboard/controller/dashboard_controller.dart';
import 'package:omeeba_new/presentation/main/home/controller/home_controller.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/video_preview_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/post/views/post_data_screen.dart';
import 'package:omeeba_new/presentation/main/post/views/selected_music_sheet_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

// Custom TextEditingController for mention styling. Uses getter so list can be updated from API.
class MentionTextController extends TextEditingController {
  final List<MentionUser> Function() getAvailableUsers;

  MentionTextController({required this.getAvailableUsers, super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final text = value.text;
    if (text.isEmpty) {
      return TextSpan(text: '', style: style);
    }
    final availableUsers = getAvailableUsers();

    final List<TextSpan> spans = [];
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    int lastIndex = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: style));
      }
      final username = match.group(1) ?? '';
      final userExists = availableUsers.any((user) => user.username == username);
      spans.add(
        TextSpan(
          text: match.group(0),
          style: userExists ? (style?.copyWith(color: AppColors.primaryColor) ?? style) : style,
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }
    return TextSpan(children: spans, style: style);
  }

  /// Call when the list of known users (for @ styling) has changed.
  void refreshStyling() {
    notifyListeners();
  }
}

class CreatePostController extends GetxController {
  // --- Zeal: serialize camera dispose/init (fixes race: music confirm + record start) ---
  Future<void> _cameraSerial = Future.value();

  Future<T> _runCameraSerial<T>(Future<T> Function() action) async {
    final previous = _cameraSerial;
    final gate = Completer<void>();
    _cameraSerial = gate.future;
    try {
      await previous;
      debugPrint('[ZealCamera] serial op begin');
      final result = await action();
      debugPrint('[ZealCamera] serial op end');
      return result;
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }

  /// Guards against double tap while [startRecording] is awaiting camera init.
  bool _zealStartRecordingInFlight = false;

  /// Bumps each time a new Zeal camera recording actually starts; stale
  /// [Future.delayed] auto-stop callbacks from a previous session must no-op.
  int _zealRecordingGeneration = 0;

  ///write post data
  final RxList<String> mentionedUsers = <String>[].obs;
  final RxList<String> mentionedUserIds = <String>[].obs;
  final RxInt characterCount = 1.obs;
  final RxBool isKeyboardVisible = false.obs;
  final RxBool isImageVisible = true.obs;
  final RxBool showMentionList = false.obs;
  final RxString mentionSearchQuery = ''.obs;
  final RxInt mentionStartPosition = (-1).obs;
  final int maxCharacters = 1000;
  final String initialCaption = '';
  late final MentionTextController captionController;
  final FocusNode captionFocusNode = FocusNode();

  void toggleMentionList() {
    // When mention button is tapped, insert @ and show list (unchanged per request)
    final currentText = captionController.text;
    final cursorPosition = captionController.selection.baseOffset;
    final textBefore = currentText.substring(0, cursorPosition);
    final textAfter = currentText.substring(cursorPosition);

    captionController.text = '$textBefore@$textAfter';
    captionController.selection = TextSelection.fromPosition(TextPosition(offset: cursorPosition + 1));

    mentionStartPosition.value = cursorPosition;
    mentionSearchQuery.value = '';
    showMentionList.value = true;
    captionFocusNode.requestFocus();
  }

  /// Users from API search (for dropdown). Pagination applied.
  final RxList<MentionUser> mentionSearchResults = <MentionUser>[].obs;

  /// Users selected from mention list - persist across searches so all mentions stay highlighted.
  final RxList<MentionUser> selectedMentionUsers = <MentionUser>[].obs;
  final RxInt mentionSearchPage = 1.obs;
  final RxBool mentionSearchHasNext = false.obs;
  final RxBool isLoadingMentionSearch = false.obs;
  final RxBool isLoadingMoreMentionUsers = false.obs;
  static const int _mentionSearchLimit = 10;
  static const int _mentionSearchDebounceMs = 600;
  Timer? _mentionSearchDebounce;
  String _lastScheduledQuery = '';
  String _lastSearchedQuery = '';

  /// Users known for @ styling. Only users selected from list get highlighted; manual edits stay normal.
  /// Merges selectedMentionUsers + mentionSearchResults so all mentions highlight across searches.
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

  List<MentionUser> getFilteredUsers() => mentionSearchResults;

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
        captionController.refreshStyling();
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
      limit: _mentionSearchLimit,
      onSuccess: (users, hasNext) {
        if (page == 1) {
          mentionSearchResults.assignAll(users);
          mentionSearchPage.value = 1;
        } else {
          mentionSearchResults.addAll(users);
          mentionSearchPage.value = page;
        }
        mentionSearchHasNext.value = hasNext;
        captionController.refreshStyling();
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

  /// Parse caption for @usernames and return IDs only for users selected from list.
  List<String> _getMentionedUserIdsFromCaption(String caption) {
    final ids = <String>[];
    final known = knownUsersForStyling;
    for (final m in RegExp(r'@(\w+)').allMatches(caption)) {
      final username = m.group(1) ?? '';
      for (final u in known) {
        if (u.username == username && !ids.contains(u.id)) {
          ids.add(u.id);
          break;
        }
      }
    }
    return ids;
  }

  final ScrollController mentionListScrollController = ScrollController();

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
      final cursorPosition = captionController.selection.baseOffset;
      final textBefore = currentText.substring(0, mentionStartPosition.value);
      final textAfter = currentText.substring(cursorPosition);

      // Insert @username with space after it
      final newText = '$textBefore@${user.username} $textAfter';

      // Calculate the new cursor position (after the mention and space)
      final newCursorPosition = mentionStartPosition.value + mention.length + 1;

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

  void removeMention(String mention) {
    mentionedUsers.remove(mention);
    final username = mention.startsWith('@') ? mention.substring(1).trim() : mention.trim();
    if (username.isEmpty) return;
    for (final u in [...selectedMentionUsers, ...mentionSearchResults]) {
      if (u.username == username) {
        mentionedUserIds.remove(u.id);
        selectedMentionUsers.removeWhere((x) => x.id == u.id);
        break;
      }
    }
  }

  ///end

  // Tab management
  final RxInt selectedTabIndex = 1.obs; // 0: write, 1: post, 2: zeal, 3: poll

  // Camera related
  CameraController? cameraController;
  final RxBool isCameraInitialized = false.obs;
  final RxBool isCameraPermissionGranted = false.obs;
  final RxBool isCameraPermissionDialog = false.obs;
  final RxList<XFile> capturedImages = <XFile>[].obs;
  List<CameraDescription> cameraList = [];
  int currentCameraIndex = 0;

  // Video recording related
  final RxBool isRecording = false.obs;
  final RxBool isPaused = false.obs;
  final Rx<XFile?> recordedVideo = Rx<XFile?>(null);
  final Rx<Duration> recordingDuration = Duration.zero.obs;
  DateTime? recordingStartTime;
  DateTime? pauseStartTime;
  Duration totalPausedDuration = Duration.zero;

  // Gallery related
  final RxList<AssetEntity> allAssets = <AssetEntity>[].obs;
  final RxList<AssetEntity> selectedAssets = <AssetEntity>[].obs;
  final RxString selectedAlbumType = 'All'.obs; // All, Photo, Video, Screenshot, Download
  final RxBool isLoadingAssets = false.obs;
  final RxList<AssetPathEntity> albums = <AssetPathEntity>[].obs;

  /// Pre-loaded gallery cache so bottom sheet opens instantly (no loading).
  final Map<String, List<AssetEntity>> _galleryCache = {};
  final RxBool isGalleryPreloadComplete = false.obs;

  /// True when gallery/photos permission is granted; false when user denied or not yet granted.
  final RxBool isGalleryPermissionGranted = true.obs;

  // Poll related — caption created lazily when Poll tab is first opened to avoid using a disposed controller
  TextEditingController? _pollCaptionController;

  TextEditingController get pollCaptionController => _pollCaptionController ??= TextEditingController();
  final RxList<TextEditingController> pollOptionControllers = <TextEditingController>[].obs;
  final RxInt pollDurationDays = 1.obs;
  final RxInt pollDurationHours = 5.obs;
  final RxInt pollDurationMinutes = 0.obs;

  @override
  void onInit() {
    super.onInit();
    // Gallery preload only (asks permission inside); camera when user opens camera tab
    WidgetsBinding.instance.addPostFrameCallback((_) => preloadGalleryInBackground());
    captionController = MentionTextController(getAvailableUsers: () => knownUsersForStyling, text: initialCaption);
    characterCount.value = initialCaption.length;
    captionController.addListener(updateCharacterCount);
    captionController.addListener(_onTextChanged);
    captionFocusNode.addListener(_onFocusChange);
    mentionListScrollController.addListener(_onMentionListScroll);
  }

  void _onMentionListScroll() {
    final pos = mentionListScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 80) loadMoreMentionUsers();
  }

  @override
  void onClose() {
    _mentionSearchDebounce?.cancel();
    mentionListScrollController.dispose();

    disposeCamera();
    _pollCaptionController?.dispose();
    _pollCaptionController = null;
    for (var controller in pollOptionControllers) {
      controller.dispose();
    }
    pollOptionControllers.clear();
    // Clean up audio player resources
    positionSubscription?.cancel();
    _completionSubscription?.cancel();
    _timer?.cancel();
    try {
      audioPlayer.stopPlayer();
    } catch (e) {
      print('Error stopping player: $e');
    }
    audioPlayer.dispose();
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void updateCharacterCount() {
    characterCount.value = captionController.text.length;
  }

  void _onTextChanged() {
    final text = captionController.text;
    final cursorPosition = captionController.selection.baseOffset;

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

  void changeTab(int index) {
    selectedTabIndex.value = index;

    if (index == 2) {
      _requestCameraPermission().then((_) => initializeCameraForVideo());
    } else if (index == 1) {
      _requestCameraPermission().then((_) => initializeCamera());
    }

    update();
  }

  /// Call when Create Post screen is shown – inits camera for Post (1) or Zeal (2) tab if that tab is active.
  void ensureCameraForCurrentTab() {
    final index = selectedTabIndex.value;
    if (index == 2) {
      _requestCameraPermission().then((_) => initializeCameraForVideo());
    } else if (index == 1) {
      _requestCameraPermission().then((_) => initializeCamera());
    }
  }

  // Camera methods
  Future<void> initializeCamera() async {
    try {
      cameraList = await availableCameras();
      if (cameraList.isEmpty) {
        debugPrint('No cameras available');
        return;
      }

      // Start with rear camera (index 0) if available, otherwise use first available
      currentCameraIndex = 0;
      for (int i = 0; i < cameraList.length; i++) {
        if (cameraList[i].lensDirection == CameraLensDirection.back) {
          currentCameraIndex = i;
          break;
        }
      }

      await _initializeCameraController();
      // If camera initialized successfully, permission is granted
      if (isCameraInitialized.value) {
        isCameraPermissionDialog.value = true;
        isCameraPermissionGranted.value = true;
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      // Check if error is permission-related
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') ||
          errorString.contains('denied') ||
          errorString.contains('not authorized')) {
        isCameraPermissionDialog.value = true;
        isCameraPermissionGranted.value = false;
        debugPrint('Camera permission denied');
      }
    }
  }

  Future<void> _initializeCameraController({bool enableAudio = false}) async {
    await _runCameraSerial(() async {
      try {
        await _disposeCameraImpl();

        if (cameraList.isEmpty || currentCameraIndex >= cameraList.length) {
          return;
        }

        isCameraInitialized.value = false;

        cameraController = CameraController(
          cameraList[currentCameraIndex],
          ResolutionPreset.high,
          enableAudio: enableAudio,
        );

        await cameraController!.initialize();
        isCameraInitialized.value = true;
        isCameraPermissionDialog.value = true;
        isCameraPermissionGranted.value = true;
      } catch (e) {
        debugPrint('Error initializing camera controller: $e');
        isCameraInitialized.value = false;
        isCameraPermissionDialog.value = true;
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('permission') ||
            errorString.contains('denied') ||
            errorString.contains('not authorized') ||
            errorString.contains('cameraaccessdeniedexception')) {
          isCameraPermissionGranted.value = false;
          debugPrint('Camera permission denied during initialization');
        }
      }
    });
  }

  // Initialize camera for video recording (with audio)
  Future<void> initializeCameraForVideo() async {
    try {
      if (cameraList.isEmpty) {
        cameraList = await availableCameras();
        if (cameraList.isEmpty) {
          debugPrint('No cameras available');
          return;
        }

        // Start with rear camera if available
        currentCameraIndex = 0;
        for (int i = 0; i < cameraList.length; i++) {
          if (cameraList[i].lensDirection == CameraLensDirection.back) {
            currentCameraIndex = i;
            break;
          }
        }
      }

      // If music is confirmed, disable camera audio (we'll use music audio instead)
      // Otherwise, enable audio for normal recording
      final enableAudio = confirmedMusic == null;
      await _initializeCameraController(enableAudio: enableAudio);
      if (isCameraInitialized.value) {
        isCameraPermissionDialog.value = true;

        isCameraPermissionGranted.value = true;
      }
    } catch (e) {
      debugPrint('Error initializing camera for video: $e');
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') ||
          errorString.contains('denied') ||
          errorString.contains('not authorized')) {
        isCameraPermissionDialog.value = true;
        isCameraPermissionGranted.value = false;
      }
    }
  }

  Future<void> switchCamera() async {
    if (cameraList.length < 2) {
      debugPrint('Only one camera available, cannot switch');
      return;
    }

    try {
      // Find the next camera (toggle between front and back)
      int nextIndex = (currentCameraIndex + 1) % cameraList.length;

      // If we have both front and back cameras, prefer switching between them
      if (cameraList.length >= 2) {
        final currentLensDirection = cameraList[currentCameraIndex].lensDirection;
        final targetLensDirection = currentLensDirection == CameraLensDirection.back
            ? CameraLensDirection.front
            : CameraLensDirection.back;

        // Find camera with opposite lens direction
        for (int i = 0; i < cameraList.length; i++) {
          if (cameraList[i].lensDirection == targetLensDirection) {
            nextIndex = i;
            break;
          }
        }
      }

      currentCameraIndex = nextIndex;
      // Preserve audio setting based on whether we're recording
      await _initializeCameraController(enableAudio: isRecording.value);
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  // Switch camera during video recording
  Future<void> switchCameraDuringRecording() async {
    if (!isRecording.value || cameraController == null) {
      return;
    }

    try {
      // Stop recording temporarily
      final wasRecording = isRecording.value;
      if (wasRecording) {
        await cameraController!.stopVideoRecording();
        isRecording.value = false;
      }

      // Switch camera
      await switchCamera();

      // Resume recording if it was recording
      if (wasRecording && cameraController != null && isCameraInitialized.value) {
        await startRecording();
      }
    } catch (e) {
      debugPrint('Error switching camera during recording: $e');
      // Try to resume recording if it failed
      if (isRecording.value == false && cameraController != null && isCameraInitialized.value) {
        try {
          await startRecording();
        } catch (e2) {
          debugPrint('Error resuming recording: $e2');
        }
      }
    }
  }

  // Permission methods
  Future<void> _requestCameraPermission() async {
    try {
      // Camera package handles permissions automatically when initializing
      // We request permission by trying to initialize the camera
      await initializeCamera();
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
      // If camera initialization fails due to permission, it will be caught
    }
  }

  Future<void> takePicture() async {
    if (cameraController == null || !isCameraInitialized.value) {
      return;
    }

    try {
      final XFile image = await cameraController!.takePicture();
      capturedImages.add(image);
      Get.to(() => PostDataScreen(type: 'post', postImages: [File(image.path)]));
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  // Video recording methods
  Future<void> startRecording() async {
    if (_zealStartRecordingInFlight || cameraController == null || !isCameraInitialized.value || isRecording.value) {
      debugPrint(
        '[ZealRecord] startRecording ignored (inFlight=$_zealStartRecordingInFlight, cam=${cameraController != null}, init=${isCameraInitialized.value}, rec=${isRecording.value})',
      );
      return;
    }

    _zealStartRecordingInFlight = true;
    debugPrint('[ZealRecord] startRecording begin (music=${confirmedMusic != null})');
    try {
      await _prepareZealRecordingSession();

      if (confirmedMusic != null) {
        await _initializeCameraController(enableAudio: false);
        await _startMusicForRecording();
      } else {
        await _initializeCameraController(enableAudio: true);
      }

      if (cameraController == null || !isCameraInitialized.value) {
        debugPrint('[ZealRecord] startRecording aborted: camera not ready after init');
        return;
      }

      await cameraController!.startVideoRecording();
      isRecording.value = true;
      isPaused.value = false;
      recordingStartTime = DateTime.now();
      recordingDuration.value = Duration.zero;
      totalPausedDuration = Duration.zero;
      pauseStartTime = null;

      debugPrint('[ZealRecord] recording started, maxMs=$videoDurationInMs');

      _zealRecordingGeneration++;
      final autoStopGen = _zealRecordingGeneration;

      _updateRecordingDuration();

      Future.delayed(Duration(milliseconds: videoDurationInMs), () async {
        if (autoStopGen != _zealRecordingGeneration) {
          return;
        }
        if (isRecording.value && !isPaused.value) {
          await stopRecording();
        }
      });
    } catch (e, st) {
      debugPrint('[ZealRecord] Error starting video recording: $e\n$st');
      isRecording.value = false;
      isPaused.value = false;
    } finally {
      _zealStartRecordingInFlight = false;
    }
  }

  // Start music playback for recording
  Future<void> _startMusicForRecording() async {
    if (confirmedMusic == null || confirmedMusic!.downloadedURL == null) {
      return;
    }

    try {
      // Prepare player with confirmed music
      await audioPlayer.preparePlayer(path: confirmedMusic!.downloadedURL!);
      await audioPlayer.seekTo(confirmedMusic!.audioStartMS ?? 0);
      await audioPlayer.startPlayer();
      audioPlayer.setFinishMode(finishMode: FinishMode.pause);
      debugPrint('[ZealRecord] music playback started at ${confirmedMusic!.audioStartMS}ms');
    } catch (e) {
      debugPrint('[ZealRecord] Error starting music for recording: $e');
    }
  }

  /// Milliseconds as decimal seconds for FFmpeg `-ss` / `-t` (avoids whole-second truncation).
  String msToFfSeconds(int ms) {
    final clamped = ms.clamp(0, 24 * 60 * 60 * 1000);
    return (clamped / 1000.0).toStringAsFixed(3);
  }

  /// FFmpeg on Windows handles forward slashes reliably inside `-i` arguments.
  String _ffmpegPath(String path) => path.replaceAll('\\', '/');

  Future<File> mergeVideoWithTrimmedMusic({
    required String videoPath,
    required String musicPath,
    required int startMS,
    required int endMS,
    required int outputVideoDurationMs,
  }) async {
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final command = _mergeReplacementAudioCommand(
      videoPath: videoPath,
      musicPath: musicPath,
      startMS: startMS,
      endMS: endMS,
      outputVideoDurationMs: outputVideoDurationMs,
      outputPath: outputPath,
    );

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg merge failed:\n$logs');
    }
    recordedVideo.value = XFile(File(outputPath).path);

    return File(outputPath);
  }

  Future<File> mergeVideoWithTrimmedMusicForDownload({
    required String videoPath,
    required String musicPath,
    required int startMS,
    required int endMS,
    required int durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/merged_download_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final command = _mergeReplacementAudioCommand(
      videoPath: videoPath,
      musicPath: musicPath,
      startMS: startMS,
      endMS: endMS,
      outputVideoDurationMs: durationMs,
      outputPath: outputPath,
    );

    final completer = Completer<File>();

    FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          final logs = await session.getAllLogsAsString();
          completer.completeError(Exception('FFmpeg merge failed:\n$logs'));
          return;
        }
        completer.complete(File(outputPath));
      },
      null,
      (statistics) {
        if (durationMs <= 0) return;
        final time = statistics.getTime();
        final percent = (time / durationMs) * 100;
        onProgress?.call(percent.clamp(0, 100));
      },
    );

    return completer.future;
  }

  /// Music replaces original audio: one segment `[startMS, endMS)` from the track, padded with silence if video is longer.
  String _mergeReplacementAudioCommand({
    required String videoPath,
    required String musicPath,
    required int startMS,
    required int endMS,
    required int outputVideoDurationMs,
    required String outputPath,
  }) {
    final musicSpanMs = (endMS - startMS).clamp(1, outputVideoDurationMs);
    final padMs = (outputVideoDurationMs - musicSpanMs).clamp(0, outputVideoDurationMs);
    final startTime = msToFfSeconds(startMS);
    final musicTakeTime = msToFfSeconds(musicSpanMs);
    final outSec = (outputVideoDurationMs / 1000.0).toStringAsFixed(3);

    final vp = _ffmpegPath(videoPath);
    final mp = _ffmpegPath(musicPath);
    final outp = _ffmpegPath(outputPath);

    if (padMs > 2) {
      final padSec = (padMs / 1000.0).toStringAsFixed(3);
      return '-i "$vp" '
          '-ss $startTime -t $musicTakeTime -i "$mp" '
          '-filter_complex "[1:a]apad=pad_dur=$padSec[aout]" '
          '-map 0:v:0 -map "[aout]" -c:v copy -t $outSec "$outp"';
    }

    return '-i "$vp" '
        '-ss $startTime -t $musicTakeTime -i "$mp" '
        '-map 0:v:0 '
        '-map 1:a:0 '
        '-c:v copy '
        '-shortest '
        '"$outp"';
  }

  Future<File> muteVideoAudio({
    required String videoPath,
    required int durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/muted_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final command = '-i "$videoPath" -c:v copy -an "$outputPath"';
    final completer = Completer<File>();

    FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          final logs = await session.getAllLogsAsString();
          completer.completeError(Exception('FFmpeg mute failed:\n$logs'));
          return;
        }
        completer.complete(File(outputPath));
      },
      null,
      (statistics) {
        if (durationMs <= 0) return;
        final time = statistics.getTime();
        final percent = (time / durationMs) * 100;
        onProgress?.call(percent.clamp(0, 100));
      },
    );

    return completer.future;
  }

  /// Merge video original audio + music (both play together).
  /// Falls back to music-only if video has no audio track.
  Future<File> mergeVideoWithOriginalAndMusic({
    required String videoPath,
    required String musicPath,
    required int startMS,
    required int endMS,
    required int durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/merged_original_music_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final musicSpanMs = (endMS - startMS).clamp(1, durationMs);
    final padMs = (durationMs - musicSpanMs).clamp(0, durationMs);
    final startTime = msToFfSeconds(startMS);
    final musicTakeTime = msToFfSeconds(musicSpanMs);
    final outSec = (durationMs / 1000.0).toStringAsFixed(3);

    final vp = _ffmpegPath(videoPath);
    final mp = _ffmpegPath(musicPath);
    final outp = _ffmpegPath(outputPath);

    final String command;
    if (padMs > 2) {
      final padSec = (padMs / 1000.0).toStringAsFixed(3);
      command =
          '-i "$vp" '
          '-ss $startTime -t $musicTakeTime -i "$mp" '
          '-filter_complex "[1:a]apad=pad_dur=$padSec[m1];[0:a][m1]amix=inputs=2:duration=longest[a]" '
          '-map 0:v:0 -map "[a]" -c:v copy -t $outSec "$outp"';
    } else {
      command =
          '-i "$vp" '
          '-ss $startTime -t $musicTakeTime -i "$mp" '
          '-filter_complex "[0:a][1:a]amix=inputs=2:duration=shortest[a]" '
          '-map 0:v:0 -map "[a]" '
          '-c:v copy '
          '-shortest '
          '"$outp"';
    }

    final completer = Completer<File>();

    FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          final logs = await session.getAllLogsAsString();
          completer.completeError(Exception('FFmpeg merge original+music failed:\n$logs'));
          return;
        }
        completer.complete(File(outputPath));
      },
      null,
      (statistics) {
        if (durationMs <= 0) return;
        final time = statistics.getTime();
        final percent = (time / durationMs) * 100;
        onProgress?.call(percent.clamp(0, 100));
      },
    );

    return completer.future;
  }

  /// Build the final confirmed video based on music, trim, and sound settings.
  /// Use this for preview, upload, and download.
  ///
  /// When [assignConfirmedVideoFile] is false, the output file is returned but
  /// [confirmedVideoFile] is not updated (used for temporary preview-only merges).
  Future<File?> buildConfirmedVideo({
    required File baseVideo,
    required int durationMs,
    void Function(double progress)? onProgress,
    bool assignConfirmedVideoFile = true,
  }) async {
    if (!baseVideo.existsSync()) return null;

    final music = confirmedMusic;
    File? outputFile;

    if (music != null && (music.downloadedURL ?? '').isNotEmpty) {
      final startMs = music.audioStartMS ?? 0;
      var endMs = music.endMilliSec ?? (startMs + durationMs);
      if (endMs <= startMs) {
        endMs = startMs + durationMs.clamp(1, 24 * 60 * 60 * 1000);
      }

      if (isOriginalSoundOn) {
        try {
          outputFile = await mergeVideoWithOriginalAndMusic(
            videoPath: baseVideo.path,
            musicPath: music.downloadedURL!,
            startMS: startMs,
            endMS: endMs,
            durationMs: durationMs,
            onProgress: onProgress,
          );
        } catch (_) {
          outputFile = await mergeVideoWithTrimmedMusicForDownload(
            videoPath: baseVideo.path,
            musicPath: music.downloadedURL!,
            startMS: startMs,
            endMS: endMs,
            durationMs: durationMs,
            onProgress: onProgress,
          );
        }
      } else {
        outputFile = await mergeVideoWithTrimmedMusicForDownload(
          videoPath: baseVideo.path,
          musicPath: music.downloadedURL!,
          startMS: startMs,
          endMS: endMs,
          durationMs: durationMs,
          onProgress: onProgress,
        );
      }
    } else {
      if (isOriginalSoundOn) {
        outputFile = baseVideo;
      } else {
        outputFile = await muteVideoAudio(videoPath: baseVideo.path, durationMs: durationMs, onProgress: onProgress);
      }
    }

    if (assignConfirmedVideoFile) {
      confirmedVideoFile = outputFile;
      update();
    }
    return outputFile;
  }

  void setOriginalSoundOn(bool value) {
    isOriginalSoundOn = value;
    update();
  }

  Future<void> pauseRecording() async {
    if (cameraController == null || !isRecording.value || isPaused.value) {
      return;
    }

    try {
      try {
        await cameraController!.pauseVideoRecording();
      } catch (e) {
        // Pause is not supported on all devices/OS versions.
        debugPrint('[ZealRecord] pauseVideoRecording unsupported or failed: $e');
        return;
      }
      isPaused.value = true;
      pauseStartTime = DateTime.now();
      debugPrint('[ZealRecord] recording paused');

      if (confirmedMusic != null) {
        try {
          await audioPlayer.pausePlayer();
        } catch (e) {
          debugPrint('[ZealRecord] Error pausing music: $e');
        }
      }
    } catch (e) {
      debugPrint('Error pausing video recording: $e');
    }
  }

  Future<void> resumeRecording() async {
    if (!isRecording.value || !isPaused.value) {
      return;
    }

    try {
      await cameraController!.resumeVideoRecording();

      // Calculate paused duration and adjust recording start time
      if (pauseStartTime != null && recordingStartTime != null) {
        final pausedDuration = DateTime.now().difference(pauseStartTime!);
        totalPausedDuration += pausedDuration;
        // Adjust recording start time forward by the paused duration
        // This way the duration calculation remains simple
        recordingStartTime = recordingStartTime!.add(pausedDuration);
        pauseStartTime = null;
      }

      isPaused.value = false;

      // Resume music playback if music is confirmed
      if (confirmedMusic != null) {
        try {
          await audioPlayer.startPlayer();
        } catch (e) {
          debugPrint('[ZealRecord] Error resuming music: $e');
        }
      }

      // Restart duration update after resuming
      _updateRecordingDuration();

      // Continue auto-stop timer check (same session as [autoStopGen] from [startRecording])
      final elapsedTime = recordingDuration.value.inMilliseconds;
      final remainingTime = videoDurationInMs - elapsedTime;
      final resumeGen = _zealRecordingGeneration;
      if (remainingTime > 0) {
        Future.delayed(Duration(milliseconds: remainingTime), () async {
          if (resumeGen != _zealRecordingGeneration) {
            return;
          }
          if (isRecording.value && !isPaused.value) {
            await stopRecording();
          }
        });
      }
    } catch (e) {
      debugPrint('Error resuming video recording: $e');
    }
  }

  Future<void> stopRecording({bool showPreview = true}) async {
    if (cameraController == null || !isRecording.value) {
      debugPrint('[ZealRecord] stopRecording ignored (cam=${cameraController != null}, rec=${isRecording.value})');
      return;
    }

    debugPrint('[ZealRecord] stopRecording begin (preview=$showPreview)');
    try {
      if (confirmedMusic != null) {
        try {
          await audioPlayer.pausePlayer();
          positionSubscription?.cancel();
          _completionSubscription?.cancel();
        } catch (e) {
          debugPrint('[ZealRecord] Error stopping music: $e');
        }
      }

      final XFile video = await cameraController!.stopVideoRecording();
      debugPrint('[ZealRecord] stopVideoRecording ok: ${video.path}');
      recordedVideo.value = video;
      isRecording.value = false;
      isPaused.value = false;
      recordingStartTime = null;
      pauseStartTime = null;
      totalPausedDuration = Duration.zero;
      recordingDuration.value = Duration.zero;

      // Show video preview if requested
      if (showPreview) {
        final videoFile = File(video.path);
        if (videoFile.existsSync()) {
          File? mergedVideo;
          if (confirmedMusic != null) {
            // Note: Video will need audio merging - this should be done in post-processing
            mergedVideo = await mergeVideoWithTrimmedMusic(
              videoPath: videoFile.path,
              musicPath: confirmedMusic!.downloadedURL!,
              startMS: confirmedMusic!.audioStartMS ?? 0,
              endMS: confirmedMusic!.endMilliSec ?? (confirmedMusic!.audioStartMS ?? 0) + videoDurationInMs,
              outputVideoDurationMs: videoDurationInMs,
            );

            debugPrint('Video recorded with music. Audio merging required.');
            // Keep [recordedVideo] as the raw capture so preview FFmpeg/upload use the camera file.
            VideoPreviewBottomSheet.show(
              videoFile: mergedVideo,
              isRecordedVideo: true,
              baseAlreadyIncludesMusicMix: true,
            );
          } else {
            VideoPreviewBottomSheet.show(videoFile: videoFile, isRecordedVideo: true);
          }
        }
      }
    } catch (e, st) {
      debugPrint('[ZealRecord] Error stopping video recording: $e\n$st');
      isRecording.value = false;
      isPaused.value = false;
    }
  }

  // Stop recording without showing preview (used when merging with music)
  Future<void> stopRecordingWithoutPreview() async {
    await stopRecording(showPreview: false);
  }

  void _updateRecordingDuration() {
    if (!isRecording.value || recordingStartTime == null || isPaused.value) {
      return;
    }

    final now = DateTime.now();
    // Since we adjust recordingStartTime when resuming, we can use simple difference
    recordingDuration.value = now.difference(recordingStartTime!);

    // Update every 100ms for smoother animation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (isRecording.value && !isPaused.value) {
        _updateRecordingDuration();
      }
    });
  }

  String getRecordingDurationText() {
    final duration = recordingDuration.value;
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Discard recorded video
  void discardRecordedVideo() {
    _zealRecordingGeneration++;
    recordingDuration.value = Duration.zero;
    recordingStartTime = null;
    pauseStartTime = null;
    totalPausedDuration = Duration.zero;
    videoDurationInMs = kZealDefaultMaxRecordingMs;
    confirmedVideoFile = null;

    if (recordedVideo.value != null) {
      try {
        // Delete the video file
        final videoFile = File(recordedVideo.value!.path);
        if (videoFile.existsSync()) {
          videoFile.deleteSync();
        }
      } catch (e) {
        debugPrint('Error deleting video file: $e');
      }
      recordedVideo.value = null;
    }
  }

  /// Disposes camera hardware. Use [disposeCamera] from UI/lifecycle; [_disposeCameraImpl] is used inside [_runCameraSerial] to avoid deadlock.
  Future<void> _disposeCameraImpl() async {
    if (cameraController != null) {
      if (isRecording.value) {
        try {
          debugPrint('[ZealCamera] dispose: stopping active recording');
          await cameraController!.stopVideoRecording();
        } catch (e) {
          debugPrint('Error stopping recording during dispose: $e');
        }
        isRecording.value = false;
        isPaused.value = false;
      }
      final controllerToDispose = cameraController;
      cameraController = null;
      isCameraInitialized.value = false;
      try {
        await controllerToDispose!.dispose();
      } catch (e) {
        debugPrint('Error disposing camera controller: $e');
      }
    } else {
      isCameraInitialized.value = false;
    }
  }

  Future<void> disposeCamera() async {
    await _runCameraSerial(() => _disposeCameraImpl());
  }

  // Gallery methods

  /// Only checks if gallery permission is granted (no dialog). Used on dashboard.
  /// On iOS 14+ / Android 14+, "limited" / "selected photos" is not [PermissionStatus.granted]
  /// but still allows the picker — [PermissionStatus.isLimited] must be accepted.
  Future<bool> _isGalleryPermissionGranted() async {
    try {
      if (Platform.isAndroid) {
        final photos = await Permission.photos.status;
        if (photos.isGranted || photos.isLimited) return true;
        final storage = await Permission.storage.status;
        return storage.isGranted;
      }
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    } catch (_) {
      return false;
    }
  }

  /// Re-reads photo library access from Photo Manager (matches [insta_assets_picker] / [PhotoManager]).
  /// Updates [isGalleryPermissionGranted] — uses [PermissionState.hasAccess] (full **or** limited library).
  Future<bool> refreshGalleryPermissionState() async {
    try {
      final state = await PhotoManager.requestPermissionExtend();
      final allowed = state.hasAccess;
      isGalleryPermissionGranted.value = allowed;
      return allowed;
    } catch (_) {
      return false;
    }
  }

  /// Preload gallery. [requestPermission] false = only if already granted (dashboard); true = ask then load (Create Post).
  Future<void> preloadGalleryInBackground({bool requestPermission = false}) async {
    try {
      bool canLoad = false;
      if (requestPermission) {
        final status = await PhotoManager.requestPermissionExtend();
        canLoad = status.hasAccess;
        isGalleryPermissionGranted.value = canLoad;
      } else {
        canLoad = await _isGalleryPermissionGranted();
        if (!canLoad) isGalleryPermissionGranted.value = false;
      }
      if (!canLoad) return;
      await loadAlbums();
      final types = ['All', 'Photo', 'Video', 'Screenshot', 'Download'];
      for (final type in types) {
        final list = await _fetchAssetsForType(type);
        _galleryCache[type] = list;
      }
      allAssets.value = _galleryCache['All'] ?? [];
      isGalleryPreloadComplete.value = true;
    } catch (e) {
      debugPrint('Gallery preload error: $e');
    }
  }

  /// Call when Create Post screen is shown: ask for permission then load if not preloaded yet.
  Future<void> ensureGalleryLoaded() async {
    if (isGalleryPreloadComplete.value) return;
    await preloadGalleryInBackground(requestPermission: true);
  }

  /// Call when user returns from app settings after granting permission. Re-checks permission and loads gallery if granted.
  Future<void> recheckGalleryPermissionAndLoad() async {
    final granted = await _isGalleryPermissionGranted();
    if (!granted) return;
    isGalleryPermissionGranted.value = true;
    if (!isGalleryPreloadComplete.value) {
      await preloadGalleryInBackground(requestPermission: false);
    }
    await loadAssets();
  }

  /// Call when Create Post screen opens: ask gallery + camera permission together, then load gallery and init camera.
  Future<void> ensureCreatePostReady() async {
    final galleryStatus = await PhotoManager.requestPermissionExtend();
    isGalleryPermissionGranted.value = galleryStatus.hasAccess;
    await Permission.camera.request();
    if (!isGalleryPreloadComplete.value) {
      await preloadGalleryInBackground(requestPermission: !galleryStatus.hasAccess);
    }
    ensureCameraForCurrentTab();
  }

  /// Fetches assets for a given album type (All, Photo, Video). Used for preload and load.
  Future<List<AssetEntity>> _fetchAssetsForType(String type) async {
    RequestType pathRequestType = RequestType.all;
    if (type == 'Video') pathRequestType = RequestType.video;
    if (type == 'Photo') pathRequestType = RequestType.image;

    final paths = await PhotoManager.getAssetPathList(type: pathRequestType, hasAll: true);
    AssetPathEntity? pathEntity = paths.isNotEmpty ? paths.first : null;
    if (pathEntity == null && type == 'Video') {
      final allPaths = await PhotoManager.getAssetPathList(type: RequestType.all, hasAll: true);
      pathEntity = allPaths.isNotEmpty ? allPaths.first : null;
      pathRequestType = RequestType.all;
    }
    if (pathEntity == null) return [];

    final assets = await pathEntity.getAssetListRange(start: 0, end: 1000);
    if (type == 'All') return assets;
    if (type == 'Screenshot') {
      return assets
          .where(
            (a) =>
                (a.title?.toLowerCase().contains('screenshot') ?? false) ||
                (a.title?.toLowerCase().contains('screen') ?? false),
          )
          .toList();
    }
    if (type == 'Download') {
      return assets
          .where(
            (a) =>
                (a.title?.toLowerCase().contains('download') ?? false) ||
                (a.relativePath?.toLowerCase().contains('download') == true),
          )
          .toList();
    }
    if (type == 'Photo') {
      return pathRequestType == RequestType.image ? assets : assets.where((a) => a.type == AssetType.image).toList();
    }
    if (type == 'Video') {
      return pathRequestType == RequestType.video ? assets : assets.where((a) => a.type == AssetType.video).toList();
    }
    return assets;
  }

  Future<void> loadAlbums() async {
    try {
      List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(type: RequestType.all, hasAll: true);

      for (int i = 0; i < paths.length; i++) {
        if (paths[i].name.trim().isEmpty) {
          paths[i] = paths[i].copyWith(name: "Name not specified");
        }
      }
      albums.clear();
      albums.addAll(paths);
    } catch (e) {
      debugPrint('Error loading albums: $e');
    }
  }

  /// Load albums for gallery bottom sheet: only video folders when [videoOnly] true, only image folders when false.
  Future<void> loadAlbumsForGallery(bool videoOnly) async {
    try {
      final RequestType type = videoOnly ? RequestType.video : RequestType.image;
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(type: type, hasAll: true);
      for (int i = 0; i < paths.length; i++) {
        if (paths[i].name.trim().isEmpty) {
          paths[i] = paths[i].copyWith(name: "Name not specified");
        }
      }
      albums.clear();
      albums.addAll(paths);
      if (paths.isEmpty) {
        selectedAlbumType.value = videoOnly ? 'Videos' : 'Photos';
        allAssets.value = [];
        isLoadingAssets.value = false;
      } else {
        selectedAlbumType.value = paths.first.name;
        await loadAssets(albumId: paths.first.id);
      }
    } catch (e) {
      debugPrint('Error loading albums for gallery: $e');
      isLoadingAssets.value = false;
    }
  }

  Future<void> loadAssets({String? albumId}) async {
    if (albumId == null && _galleryCache.containsKey(selectedAlbumType.value)) {
      allAssets.value = List.from(_galleryCache[selectedAlbumType.value]!);
      isLoadingAssets.value = false;
      return;
    }

    isLoadingAssets.value = true;
    try {
      AssetPathEntity? pathEntity;
      RequestType pathRequestType = RequestType.all;

      if (albumId == null) {
        if (selectedAlbumType.value == 'Video') {
          pathRequestType = RequestType.video;
        } else if (selectedAlbumType.value == 'Photo') {
          pathRequestType = RequestType.image;
        }
        final paths = await PhotoManager.getAssetPathList(type: pathRequestType, hasAll: true);
        pathEntity = paths.isNotEmpty ? paths.first : null;
        if (pathEntity == null && selectedAlbumType.value == 'Video') {
          final allPaths = await PhotoManager.getAssetPathList(type: RequestType.all, hasAll: true);
          pathEntity = allPaths.isNotEmpty ? allPaths.first : null;
          pathRequestType = RequestType.all;
        }
      } else {
        pathEntity = albums.firstWhereOrNull((album) => album.id == albumId);
      }

      if (pathEntity != null) {
        final assets = await pathEntity.getAssetListRange(start: 0, end: 1000);

        if (albumId != null) {
          // Specific album selected from device – show all assets without type filter
          allAssets.value = assets;
          _galleryCache[selectedAlbumType.value] = List.from(allAssets);
        } else {
          if (selectedAlbumType.value == 'All') {
            allAssets.value = assets;
          } else if (selectedAlbumType.value == 'Screenshot') {
            allAssets.value = assets.where((asset) {
              return asset.title!.toLowerCase().contains('screenshot') || asset.title!.toLowerCase().contains('screen');
            }).toList();
          } else if (selectedAlbumType.value == 'Download') {
            allAssets.value = assets.where((asset) {
              return asset.title!.toLowerCase().contains('download') ||
                  asset.relativePath?.toLowerCase().contains('download') == true;
            }).toList();
          } else if (selectedAlbumType.value == 'Photo') {
            allAssets.value = pathRequestType == RequestType.image
                ? assets
                : assets.where((asset) => asset.type == AssetType.image).toList();
          } else if (selectedAlbumType.value == 'Video') {
            allAssets.value = pathRequestType == RequestType.video
                ? assets
                : assets.where((asset) => asset.type == AssetType.video).toList();
          } else {
            allAssets.value = assets;
          }
          _galleryCache[selectedAlbumType.value] = List.from(allAssets);
        }
      }
    } catch (e) {
      debugPrint('Error loading assets: $e');
    } finally {
      isLoadingAssets.value = false;
    }
  }

  void changeAlbumType(String type) {
    selectedAlbumType.value = type;
    loadAssets();
  }

  /// Select a specific album from device (e.g. Recents, Camera, Screenshots). Shows dynamic list like phone gallery.
  void selectAlbum(String albumId, String displayName) {
    selectedAlbumType.value = displayName;
    loadAssets(albumId: albumId);
  }

  void toggleAssetSelection(AssetEntity asset) {
    if (selectedAssets.contains(asset)) {
      selectedAssets.remove(asset);
    } else {
      selectedAssets.add(asset);
    }
    // RxList automatically triggers UI updates, no need for update()
  }

  bool isAssetSelected(AssetEntity asset) {
    return selectedAssets.contains(asset);
  }

  void clearSelectedAssets() {
    selectedAssets.clear();
  }

  Future<List<File>> getSelectedAssetFiles() async {
    final List<File> files = [];
    for (var asset in selectedAssets) {
      final file = await asset.file;
      if (file != null) {
        files.add(file);
      }
    }
    return files;
  }

  // Poll methods
  void initializePollOptions() {
    if (pollOptionControllers.isEmpty) {
      addPollOption();
      addPollOption();
    }
  }

  void addPollOption() {
    pollOptionControllers.add(TextEditingController());
  }

  void removePollOption(int index) {
    if (pollOptionControllers.length > 2) {
      pollOptionControllers[index].dispose();
      pollOptionControllers.removeAt(index);
    }
  }

  void setPollDuration(int days, int hours, int minutes) {
    pollDurationDays.value = days;
    pollDurationHours.value = hours;
    pollDurationMinutes.value = minutes;
  }

  final RxBool isLoadingPoll = false.obs;

  /// Submit write post via API. On success: close to dashboard and refresh home feed.
  final RxBool isLoadingWritePost = false.obs;

  void submitWritePost({void Function()? onSuccess, void Function(String)? onError}) {
    final content = captionController.text.trim();
    if (content.isEmpty) {
      AppFunctions().showToast('Please add a caption');
      onError?.call('Please add a caption');
      return;
    }

    isLoadingWritePost.value = true;
    update();

    final repo = Get.isRegistered<ContentRepository>() ? Get.find<ContentRepository>() : ContentRepository();
    final ids = _getMentionedUserIdsFromCaption(content);
    repo.writePost(
      content: content,
      mentionedUserIds: ids,
      onSuccess: (res) {
        isLoadingWritePost.value = false;
        update();
        AppFunctions().showToast(res.message ?? 'Post created successfully');
        Get.until((route) => route.settings.name == AppRoutes.dashboard);
        if (Get.isRegistered<HomeController>()) {
          captionController.clear();
          Get.find<HomeController>().refreshFeedInBackground();
          Get.find<DashboardController>().changeIndex(0);
        }
        onSuccess?.call();
      },
      onError: (e) {
        isLoadingWritePost.value = false;
        update();
        AppFunctions().showToast(e.message);
        onError?.call(e.message);
      },
    );
  }

  /// Submit poll via API. On success: close to dashboard and refresh home feed.
  void submitPoll() {
    final caption = pollCaptionController.text.trim();
    final options = pollOptionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    if (caption.isEmpty) {
      AppFunctions().showToast('Please add a caption');
      return;
    }
    if (options.length < 2) {
      AppFunctions().showToast('Add at least 2 options');
      return;
    }

    final now = DateTime.now();
    final endDate = now.add(
      Duration(days: pollDurationDays.value, hours: pollDurationHours.value, minutes: pollDurationMinutes.value),
    );
    final duration = endDate.toUtc().toIso8601String();

    isLoadingPoll.value = true;
    update();
    final repo = Get.isRegistered<ContentRepository>() ? Get.find<ContentRepository>() : ContentRepository();
    repo.createPoll(
      caption: caption,
      options: options,
      duration: duration,
      onSuccess: (res) {
        isLoadingPoll.value = false;
        update();
        AppFunctions().showToast(res.message ?? 'Poll created successfully');
        pollCaptionController.clear();
        pollOptionControllers.clear();
        Get.until((route) => route.settings.name == AppRoutes.dashboard);
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().refreshFeedInBackground();
          Get.find<DashboardController>().changeIndex(0);
        }
      },
      onError: (e) {
        isLoadingPoll.value = false;
        update();
        AppFunctions().showToast(e.message);
      },
    );
  }

  String getPollDurationText() {
    return '${pollDurationDays.value.toString().padLeft(2, '0')}d ${pollDurationHours.value.toString().padLeft(2, '0')}h ${pollDurationMinutes.value.toString().padLeft(2, '0')}m';
  }

  /// Zeal view

  RxBool isMusicShowInZeal = false.obs;

  /// Default max capture length for Zeal. Preview/trim UI may assign [videoDurationInMs]
  /// to the actual clip length; always reset to this before a new camera recording.
  static const int kZealDefaultMaxRecordingMs = 30000;

  int videoDurationInMs = kZealDefaultMaxRecordingMs;
  SelectedMusic? selectedMusic;

  // Store confirmed music selection (after "Done" is clicked)
  SelectedMusic? confirmedMusic;

  /// Single confirmed video file - used for preview, upload, download.
  /// Updated when music/trim/sound changes.
  File? confirmedVideoFile;

  /// When true, keep original voice. When false, mute original (music only or silent).
  bool isOriginalSoundOn = true;
  String? musicTitle;
  String? musicArtist;
  String? musicAlbumArtUrl;

  PlayerController audioPlayer = PlayerController();
  Rx<int?> durationInMilliSec = Rx(null);
  Rx<int> audioStartInMilliSec = Rx(0);

  RxBool isPlaying = false.obs;
  Timer? _timer;
  StreamSubscription? positionSubscription;

  Function(SelectedMusic? music)? onMusicAdd;

  ScrollController scrollController = ScrollController();
  RxList<double> waves = RxList();
  double oneBarValue = 0;
  final double borderWidth = 10;
  final double barWidth = 2;
  final double barHorizontalMargin = 1;
  final double barInBoxCount = 30;
  RxDouble currentProgress = 0.0.obs;
  RxDouble scrollOffset = 0.0.obs;

  double get barTotalWidth => barWidth + (barHorizontalMargin * 2);

  double get boxWidth => barTotalWidth * barInBoxCount;

  int get previousBar => (scrollOffset.value / barTotalWidth).toInt();

  int get currentBars => (previousBar + (currentProgress.value * barInBoxCount)).toInt();

  void initPlayer() async {
    print('INITIAL VIDEO DURATION SECOND : (${videoDurationInMs / 1000})');
    print('Selected Audio Data : (${selectedMusic?.toJson()})');
    try {
      // Check if we have a valid audio URL
      if (selectedMusic?.downloadedURL == null || selectedMusic!.downloadedURL!.isEmpty) {
        print("Error: No audio URL provided");
        return;
      }

      // Clear previous waves
      waves.clear();

      // Prepare the player with the audio URL (can be network URL or local file path)
      await audioPlayer.preparePlayer(path: selectedMusic!.downloadedURL!);
      audioPlayer.seekTo(selectedMusic?.audioStartMS ?? 0);
      audioStartInMilliSec.value = selectedMusic?.audioStartMS ?? 0;

      oneBarValue = (barInBoxCount / (videoDurationInMs / 1000));
      durationInMilliSec.value = await audioPlayer.getDuration();

      // Generate waves based on duration
      for (double i = 0; i <= (oneBarValue * ((durationInMilliSec.value ?? 0) / 1000)).toInt(); i++) {
        waves.add(i);
      }

      // Remove previous listener to avoid duplicates
      scrollController.removeListener(_onScroll);
      scrollController.addListener(_onScroll);

      // Wait a bit for player to be fully ready before playing
      await Future.delayed(const Duration(milliseconds: 100));

      DebounceAction.shared.call(() {
        scrollController.animateTo(
          ((selectedMusic?.audioStartMS ?? 0) / 1000) * barTotalWidth * oneBarValue,
          duration: const Duration(milliseconds: 10),
          curve: Curves.bounceIn,
        );
        // Small delay before playing to ensure player is ready
        Future.delayed(const Duration(milliseconds: 200), () {
          playPause();
        });
      });
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  void _onScroll() {
    currentProgress.value = 0.0;
    if (isPlaying.value == true) {
      onPause();
    } else {
      DebounceAction.shared.call(() async {
        int scrollOffset = scrollController.offset.toInt();
        int startDuration = ((scrollOffset / barTotalWidth) / oneBarValue).toInt();
        audioStartInMilliSec.value = (startDuration * 1000);
        this.scrollOffset.value = scrollOffset.toDouble();
        onPlayAudio();
      });
    }
  }

  Future<void> playPause() async {
    (isPlaying.value) ? await onPause() : await onPlayAudio();
  }

  StreamSubscription? _completionSubscription;

  void _listenPlayer() {
    // Cancel previous subscriptions if they exist
    positionSubscription?.cancel();
    _completionSubscription?.cancel();
    currentProgress.value = 0.0;

    positionSubscription = audioPlayer.onCurrentDurationChanged.listen((event) {
      int relativePosition = (event.milliseconds.inMilliseconds + 100) - audioStartInMilliSec.value;
      currentProgress.value = (relativePosition / videoDurationInMs);

      print('Current Progress : $currentProgress');
    });

    // Set up completion listener
    _completionSubscription = audioPlayer.onCompletion.listen((event) {
      print('Audio playback completed');
      currentProgress.value = 1;
      isPlaying.value = false;
      _timer?.cancel();
    });
  }

  Future<void> onPlayAudio() async {
    try {
      // Ensure player is prepared before playing
      if (selectedMusic?.downloadedURL == null || selectedMusic!.downloadedURL!.isEmpty) {
        print('ON PLAY ERROR : No audio URL available');
        return;
      }

      _listenPlayer();
      await audioPlayer.seekTo(audioStartInMilliSec.value);
      // await Future.delayed(const Duration(milliseconds: 500));
      await audioPlayer.startPlayer();
      audioPlayer.setFinishMode(finishMode: FinishMode.pause);

      int endTime = ((durationInMilliSec.value ?? 0) - audioStartInMilliSec.value);

      if (videoDurationInMs < endTime) {
        endTime = videoDurationInMs;
      }

      isPlaying.value = true;

      _timer = Timer(Duration(milliseconds: videoDurationInMs), () async {
        await onPause();
      });
    } catch (e) {
      print('ON PLAY ERROR : $e');
      isPlaying.value = false;
    }
  }

  Future<void> onPause() async {
    try {
      await audioPlayer.pausePlayer();
      positionSubscription?.cancel();
      _completionSubscription?.cancel();
      isPlaying.value = false;
      _timer?.cancel();
    } catch (e) {
      print('PAUSE ERROR: $e');
    } finally {
      print('PAUSE');
    }
  }

  // --- Zeal session lifecycle (fresh state on screen open / between captures) ---

  /// Stops waveform/audio preview only; does not change [selectedMusic] / [confirmedMusic].
  void _resetZealAudioWaveformState() {
    try {
      onPause();
    } catch (_) {}
    positionSubscription?.cancel();
    _completionSubscription?.cancel();
    _timer?.cancel();
    waves.clear();
    durationInMilliSec.value = null;
    audioStartInMilliSec.value = 0;
    currentProgress.value = 0.0;
    scrollOffset.value = 0.0;
    isPlaying.value = false;
    isMusicShowInZeal.value = false;
  }

  void _clearZealMusicModels() {
    selectedMusic = null;
    confirmedMusic = null;
    musicTitle = null;
    musicArtist = null;
    musicAlbumArtUrl = null;
  }

  /// Full Zeal capture reset when Create Post opens so no stale video/music/duration remains.
  Future<void> resetZealSessionForCreatePostEntry() async {
    if (isRecording.value && cameraController != null) {
      try {
        await cameraController!.stopVideoRecording();
      } catch (_) {
        debugPrint('resetZealSession: stop recording');
      }
    }
    isRecording.value = false;
    isPaused.value = false;
    recordingDuration.value = Duration.zero;
    recordingStartTime = null;
    pauseStartTime = null;
    totalPausedDuration = Duration.zero;

    discardRecordedVideo();
    confirmedVideoFile = null;
    videoDurationInMs = kZealDefaultMaxRecordingMs;
    isOriginalSoundOn = true;

    _resetZealAudioWaveformState();
    _clearZealMusicModels();

    _zealStartRecordingInFlight = false;

    update();

    if (selectedTabIndex.value == 2) {
      await initializeCameraForVideo();
    }
  }

  /// Before starting a **new** Zeal recording: drop previous clip (and music tied to it) if any.
  /// Camera is reconfigured in [startRecording] (avoid double [initializeCamera]).
  Future<void> _prepareZealRecordingSession() async {
    // Preview/trim always mutates [videoDurationInMs] to the last clip length; reset the
    // capture cap every time so discard → re-record does not keep a stale duration/auto-stop.
    videoDurationInMs = kZealDefaultMaxRecordingMs;

    if (recordedVideo.value != null) {
      discardRecordedVideo();
      confirmedVideoFile = null;
      _resetZealAudioWaveformState();
      _clearZealMusicModels();
      update();
    }
    recordingDuration.value = Duration.zero;
    recordingStartTime = null;
    pauseStartTime = null;
    totalPausedDuration = Duration.zero;
  }

  /// Payload for POST `/zeals`: `replace` with library id + trim seconds, else `mute` or `original`.
  ({String audioAction, String? musicId, int? musicStartTime, int? musicEndTime}) get zealAudioForApi {
    final m = confirmedMusic;
    final id = m?.musicId?.trim();
    final hasLibraryMusic = m != null && id != null && id.isNotEmpty && (m.downloadedURL ?? '').isNotEmpty;
    if (hasLibraryMusic) {
      final startMs = m.audioStartMS ?? 0;
      final endMs = m.endMilliSec ?? (startMs + videoDurationInMs);
      return (audioAction: 'replace', musicId: id, musicStartTime: startMs ~/ 1000, musicEndTime: endMs ~/ 1000);
    }
    if (!isOriginalSoundOn) {
      return (audioAction: 'mute', musicId: null, musicStartTime: null, musicEndTime: null);
    }
    return (audioAction: 'original', musicId: null, musicStartTime: null, musicEndTime: null);
  }

  /// Zeal: download library audio to a local path so [audioPlayer] and FFmpeg `-i` work reliably.
  /// Remote URLs were stored in [SelectedMusic.downloadedURL] but never downloaded, so merge failed silently.
  Future<bool> applyZealMusicFromTrack(MusicTrack track) async {
    final file = await AudioFileHelper.ensureLocalAudioFile(track.audioUrl);
    if (file == null || !await file.exists()) {
      return false;
    }
    selectedMusic = SelectedMusic(0, file.path, 0, musicId: track.id);
    musicTitle = track.title;
    musicArtist = track.artist;
    musicAlbumArtUrl = track.albumArtUrl.isNotEmpty ? track.albumArtUrl : null;
    audioStartInMilliSec.value = 0;
    await confirmMusicSelection();
    update();
    return true;
  }

  /// Confirms library segment for Zeal. Must [await] so camera reinit never races [startRecording].
  Future<void> confirmMusicSelection() async {
    if (selectedMusic == null) return;

    final endTime = audioStartInMilliSec.value + videoDurationInMs;
    confirmedMusic = SelectedMusic(
      audioStartInMilliSec.value,
      selectedMusic!.downloadedURL,
      endTime,
      musicId: selectedMusic!.musicId,
    );
    update();
    isMusicShowInZeal.value = false;

    await onPause();

    debugPrint('[ZealMusic] confirmed start=${audioStartInMilliSec.value}ms end=$endTime reconfiguring camera…');
    if (isCameraInitialized.value) {
      await initializeCameraForVideo();
    }
    debugPrint('[ZealMusic] camera ready for music recording (no mic track)');
  }

  /// Clears all music state after a successful Zeal post. Use when leaving the flow.
  Future<void> clearMusicAfterPostSuccess() async {
    await clearConfirmedMusic();
  }

  Future<void> clearConfirmedMusic() async {
    _resetZealAudioWaveformState();
    _clearZealMusicModels();
    update();

    if (isCameraInitialized.value) {
      await initializeCameraForVideo();
    }
    debugPrint('[ZealMusic] cleared — camera back to default (mic as needed)');
  }

  /// Zeal header: clears library pick + confirmed segment without touching video/post data.
  Future<void> clearZealMusicSelection() async {
    await clearConfirmedMusic();
  }
}
