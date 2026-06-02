import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/exceptions/app_exception.dart';
import 'package:omeeba_new/core/models/music_library_item_model.dart';
import 'package:omeeba_new/core/repository/zeals_repository.dart';

/// State for [SearchMusicBottomSheet]: API load, errors, search filter.
class SearchMusicBottomSheetController extends GetxController {
  SearchMusicBottomSheetController({ZealsRepository? repo})
    : _repo = repo ?? (Get.isRegistered<ZealsRepository>() ? Get.find<ZealsRepository>() : ZealsRepository());

  final ZealsRepository _repo;

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final RxList<MusicTrack> allTracks = <MusicTrack>[].obs;
  final RxList<MusicTrack> visibleTracks = <MusicTrack>[].obs;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_onSearchChanged);
    loadMusic();
  }

  @override
  void onClose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void _onSearchChanged() {
    _filterVisible();
  }

  void _filterVisible() {
    final q = searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      visibleTracks.assignAll(allTracks);
    } else {
      visibleTracks.assignAll(
        allTracks.where((t) {
          return t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q);
        }),
      );
    }
  }

  Future<void> loadMusic() async {
    isLoading.value = true;
    errorMessage.value = null;

    await _repo.getMusicLibrary(
      onSuccess: (items) {
        allTracks.assignAll(
          items.where((e) => e.audioUrl.isNotEmpty).map(MusicTrack.fromLibraryItem),
        );
        _filterVisible();
        isLoading.value = false;
      },
      onError: (AppException e) {
        isLoading.value = false;
        errorMessage.value = e.message.isNotEmpty ? e.message : 'Something went wrong';
      },
    );
  }
}
