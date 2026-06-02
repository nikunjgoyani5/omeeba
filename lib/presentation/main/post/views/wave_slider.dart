import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/presentation/main/post/views/selected_music_sheet_controller.dart';

/// Horizontal waveform for music trim: scrollable bars bounded by track length so
/// the clip window cannot move past the end of the audio.
class WaveSlider extends StatelessWidget {
  final SelectedMusicSheetController controller;

  const WaveSlider({super.key, required this.controller});

  static String _fmtMs(int ms) {
    final s = (ms / 1000).floor();
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final halfPad = (MediaQuery.of(context).size.width / 2) - (controller.boxWidth / 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() {
          final total = controller.durationInMilliSec.value ?? 0;
          if (total <= 0) return const SizedBox.shrink();
          final start = controller.audioStartInMilliSec.value.clamp(0, total);
          final clipEnd = (start + controller.videoDurationInMs).clamp(0, total);
          final maxStart = controller.maxSelectableStartMs;
          final atEnd = controller.scrollOffset.value >= controller.maxScrollOffsetPx - 1.5;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.music_note_rounded, size: 16.sp, color: AppColors.primaryColor),
                    Gap(4.w),
                    Expanded(
                      child: Text(
                        'Drag to choose where your clip starts',
                        style: TextStyles.medium(11.sp, fontColor: AppColors.gray8C9499),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Gap(6.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Start ${_fmtMs(start)}', style: TextStyles.bold(12.sp, fontColor: AppColors.black2F3039)),
                    Text('End ${_fmtMs(clipEnd)}', style: TextStyles.bold(12.sp, fontColor: AppColors.black2F3039)),
                  ],
                ),
                Gap(6.h),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final sf = start / total;
                    final ef = clipEnd / total;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 5.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: AppColors.grayE7EBEE,
                          ),
                        ),
                        Positioned(
                          left: sf * w,
                          width: math.max(4.0, (ef - sf) * w),
                          height: 5.h,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                colors: [AppColors.primaryDark, AppColors.primaryColor],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Gap(4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0:00', style: TextStyles.medium(10.sp, fontColor: AppColors.gray8C9499)),
                    Text('${_fmtMs(total)} · max start ${_fmtMs(maxStart)}', style: TextStyles.medium(10.sp, fontColor: AppColors.gray8C9499)),
                  ],
                ),
                if (atEnd && maxStart > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      'End of track — slide back to pick an earlier start',
                      style: TextStyles.medium(10.sp, fontColor: AppColors.primaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }),
        Gap(10.h),
        SizedBox(
          width: double.infinity,
          height: 50.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  Container(
                    width: controller.boxWidth,
                    height: 50.h,
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(10.r)),
                      gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryColor]),
                    ),
                  ),
                  SizedBox(
                    width: controller.boxWidth,
                    height: 50.h,
                    child: FittedBox(
                      fit: BoxFit.none,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.r),
                        child: Container(
                          alignment: Alignment.centerRight,
                          width: (controller.boxWidth - controller.borderWidth),
                          height: (50.h - controller.borderWidth),
                          child: FittedBox(
                            fit: BoxFit.none,
                            child: Obx(() {
                              return AnimatedContainer(
                                duration: Duration(
                                  milliseconds: controller.currentProgress.value == 0.0 ? 0 : 1,
                                ),
                                curve: Curves.easeInOut,
                                width: math.max(
                                  0,
                                  (controller.boxWidth - controller.borderWidth) * (1 - controller.currentProgress.value),
                                ),
                                height: (50.h - controller.borderWidth),
                                color: Colors.white.withValues(alpha: 0.92),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SingleChildScrollView(
                controller: controller.scrollController,
                dragStartBehavior: DragStartBehavior.down,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(width: halfPad, height: 10),
                    Obx(() {
                      final trackW = controller.waveTrackWidthPx;
                      if (trackW <= 0) {
                        return const SizedBox.shrink();
                      }
                      final n = controller.waves.length;
                      final barRowW = n * controller.barTotalWidth;
                      final tail = math.max(0.0, trackW - barRowW);
                      return SizedBox(
                        width: trackW,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(
                              n,
                              (index) {
                                return Container(
                                  height: index % 2 == 0 ? 20.h : 12.h,
                                  margin: EdgeInsets.symmetric(horizontal: controller.barHorizontalMargin),
                                  width: controller.barWidth,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: AppColors.grayE7EBEE,
                                  ),
                                );
                              },
                            ),
                            if (tail > 0) SizedBox(width: tail),
                          ],
                        ),
                      );
                    }),
                    SizedBox(width: halfPad),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
