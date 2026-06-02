import 'package:omeeba_new/core/models/music_library_item_model.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/presentation/main/post/controller/search_music_bottom_sheet_controller.dart';
import 'package:shimmer/shimmer.dart';

class SearchMusicBottomSheet extends GetView<SearchMusicBottomSheetController> {
  const SearchMusicBottomSheet({super.key, required this.onMusicSelect});

  final void Function(MusicTrack track) onMusicSelect;

  static void show({required void Function(MusicTrack track) onMusicSelect}) {
    Get.put(SearchMusicBottomSheetController());
    Get.bottomSheet(
      SearchMusicBottomSheet(onMusicSelect: onMusicSelect),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    ).whenComplete(() {
      if (Get.isRegistered<SearchMusicBottomSheetController>()) {
        Get.delete<SearchMusicBottomSheetController>(force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      height: Get.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12.h),
            height: 5.w,
            width: 55.w,
            decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
          ),
          Gap(16.h),
          _buildHeader(),
          Gap(16.h),
          CommonSearchTextField(
            hintText: 'Search audio',
            controller: controller.searchController,
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 10.w),
              child: Assets.icons.icSearch.svg(colorFilter: ColorFilter.mode(AppColors.gray707070, BlendMode.srcIn)),
            ),
          ),
          Gap(16.h),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const _MusicListShimmer();
      }
      final err = controller.errorMessage.value;
      if (err != null) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  err,
                  textAlign: TextAlign.center,
                  style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070),
                ),
                Gap(16.h),
                TextButton(
                  onPressed: controller.loadMusic,
                  child: Text('Retry', style: TextStyles.bold(16.sp, fontColor: AppColors.primaryColor)),
                ),
              ],
            ),
          ),
        );
      }
      final list = controller.visibleTracks;
      if (list.isEmpty) {
        return Center(
          child: Text(
            controller.allTracks.isEmpty ? 'No music available' : 'No results',
            style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070),
          ),
        );
      }
      // Reserve right gutter so the scrollbar thumb does not paint over row content.
      const scrollbarThickness = 4.0;
      const scrollbarGutter = 10.0;
      final listRightPad = scrollbarThickness + scrollbarGutter;

      return Scrollbar(
        controller: controller.scrollController,
        thumbVisibility: true,
        interactive: true,
        thickness: scrollbarThickness,
        radius: Radius.circular(8.r),
        child: ListView.builder(
          controller: controller.scrollController,
          padding: EdgeInsets.only(right: listRightPad.w),
          itemCount: list.length,
          itemBuilder: (context, index) {
            return _buildMusicItem(list[index]);
          },
        ),
      );
    });
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(onTap: () => Get.back(), child: Image.asset(Assets.icons.icArrowBack.path, scale: 3.5)),
        Text('Music', style: TextStyles.bold(20.sp, fontColor: AppColors.black2F3039)),
        Image.asset(Assets.icons.icArrowBack.path, scale: 3.5, color: AppColors.transparentColor),
      ],
    );
  }

  Widget _buildMusicItem(MusicTrack track) {
    return InkWell(
      onTap: () {
        onMusicSelect(track);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: track.albumArtUrl.isEmpty
                  ? Container(
                      width: 56.w,
                      height: 56.w,
                      color: AppColors.grayEDF1F4,
                      child: Icon(Icons.music_note, color: AppColors.gray707070, size: 24.sp),
                    )
                  : Image.network(
                      track.albumArtUrl,
                      width: 56.w,
                      height: 56.w,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 56.w,
                          height: 56.w,
                          color: AppColors.grayEDF1F4,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 56.w,
                        height: 56.w,
                        color: AppColors.grayEDF1F4,
                        child: Icon(Icons.music_note, color: AppColors.gray707070, size: 24.sp),
                      ),
                    ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyles.bold(16.sp, fontColor: AppColors.black2F3039),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Gap(4.h),
                  Text(
                    track.artist,
                    style: TextStyles.medium(12.sp, fontColor: AppColors.gray8C9499),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Gap(8.w),
            Image.asset(Assets.icons.icArrowNext.path, scale: 3),
          ],
        ),
      ),
    );
  }
}

/// Shimmer rows matching [MusicTrack] list layout.
class _MusicListShimmer extends StatelessWidget {
  const _MusicListShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grayEDF1F4,
      highlightColor: const Color(0xFFF8F9FA),
      period: const Duration(milliseconds: 1200),
      child: ListView.separated(
        padding: EdgeInsets.only(right: 14.w),
        itemCount: 8,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Row(
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: AppColors.grayEDF1F4,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16.h,
                        width: 180.w,
                        decoration: BoxDecoration(
                          color: AppColors.grayEDF1F4,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      Gap(8.h),
                      Container(
                        height: 12.h,
                        width: 120.w,
                        decoration: BoxDecoration(
                          color: AppColors.grayEDF1F4,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(8.w),
                Container(
                  width: 20.w,
                  height: 20.w,
                  decoration: BoxDecoration(
                    color: AppColors.grayEDF1F4,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
