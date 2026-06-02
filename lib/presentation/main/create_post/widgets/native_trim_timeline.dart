import 'dart:math' as math;
import 'dart:typed_data';

import 'package:omeeba_new/core/utils/exports.dart';

/// Instagram-style trim strip: thumbnails, dimmed out-of-range, handles, blue playhead.
class NativeTrimTimeline extends StatefulWidget {
  const NativeTrimTimeline({
    super.key,
    required this.thumbnails,
    required this.totalDurationMs,
    required this.startMs,
    required this.endMs,
    required this.minTrimMs,
    required this.playheadMs,
    required this.onTrimChanged,
    required this.onPlayheadSeek,
  });

  final List<Uint8List?> thumbnails;
  final int totalDurationMs;
  final double startMs;
  final double endMs;
  final double minTrimMs;
  final double playheadMs;
  final ValueChanged<({double start, double end})> onTrimChanged;
  final ValueChanged<double> onPlayheadSeek;

  @override
  State<NativeTrimTimeline> createState() => _NativeTrimTimelineState();
}

class _NativeTrimTimelineState extends State<NativeTrimTimeline> {
  final GlobalKey _trackKey = GlobalKey();

  String _fmt(double ms) {
    final d = Duration(milliseconds: ms.round());
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(1, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalDurationMs <= 0 ? 1 : widget.totalDurationMs;
    final minSpan = math.min(widget.minTrimMs, total.toDouble());
    final startNorm = (widget.startMs / total).clamp(0.0, 1.0);
    final endNorm = (widget.endMs / total).clamp(0.0, 1.0);
    final playNorm = (widget.playheadMs / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            '${_fmt(widget.playheadMs)} / ${_fmt(total.toDouble())}',
            style: TextStyles.medium(
              14.sp,
              fontColor: AppColors.black141414,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const handleSize = 32.0;
            final stripH = 52.h;

            void commitStart(double localX) {
              final frac = (localX / w).clamp(0.0, 1.0);
              var s = frac * total;
              var e = widget.endMs;
              if (e - s < minSpan) {
                s = e - minSpan;
              }
              s = s.clamp(0.0, math.max(0.0, total - minSpan));
              if (e < s + minSpan) {
                e = (s + minSpan).clamp(minSpan, total.toDouble());
              }
              widget.onTrimChanged((start: s, end: e));
            }

            void commitEnd(double localX) {
              final frac = (localX / w).clamp(0.0, 1.0);
              var e = frac * total;
              var s = widget.startMs;
              if (e - s < minSpan) {
                e = s + minSpan;
              }
              e = e.clamp(minSpan, total.toDouble());
              s = s.clamp(0.0, e - minSpan);
              widget.onTrimChanged((start: s, end: e));
            }

            double trackLocalX(DragUpdateDetails details) {
              final box =
                  _trackKey.currentContext?.findRenderObject() as RenderBox?;
              if (box == null) return 0;
              return box.globalToLocal(details.globalPosition).dx;
            }

            // Vertically center handles on the strip: bottom offset = (stripH - handleHeight) / 2
            final handleBottom = (stripH - 32.w) / 2;

            return SizedBox(
              key: _trackKey,
              height: stripH + 14.h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: stripH,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _ThumbnailStrip(
                            height: stripH,
                            thumbnails: widget.thumbnails,
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: startNorm * w,
                            child: Container(
                              color: AppColors.black000000.withValues(alpha: 0.42),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: (1.0 - endNorm) * w,
                            child: Container(
                              color: AppColors.black000000.withValues(alpha: 0.42),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: playNorm * w - 12.w,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        final x = trackLocalX(details);
                        final ms = (x / w) * total;
                        widget.onPlayheadSeek(ms.clamp(0.0, total.toDouble()));
                      },
                      child: SizedBox(
                        width: 24.w,
                        height: stripH + 12.h,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            CustomPaint(
                              size: Size(12.w, 6.h),
                              painter: _PlayheadArrowPainter(
                                color: AppColors.blue3382FF,
                              ),
                            ),
                            Container(
                              width: 2.5.w,
                              height: stripH,
                              decoration: BoxDecoration(
                                color: AppColors.blue3382FF,
                                borderRadius: BorderRadius.circular(1.r),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: startNorm * w - handleSize / 2,
                    bottom: handleBottom,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        commitStart(trackLocalX(details));
                      },
                      child: _TrimHandle(isEnd: false),
                    ),
                  ),
                  Positioned(
                    left: endNorm * w - handleSize / 2,
                    bottom: handleBottom,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        commitEnd(trackLocalX(details));
                      },
                      child: _TrimHandle(isEnd: true),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.height,
    required this.thumbnails,
  });

  final double height;
  final List<Uint8List?> thumbnails;

  @override
  Widget build(BuildContext context) {
    if (thumbnails.isEmpty) {
      return Container(
        color: AppColors.grayEDF1F4,
        alignment: Alignment.center,
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.grayC4C4C4,
          ),
        ),
      );
    }
    return Row(
      children: List.generate(thumbnails.length, (i) {
        final bytes = thumbnails[i];
        return Expanded(
          child: SizedBox(
            height: height,
            child: bytes == null
                ? Container(color: AppColors.grayE7EBEE)
                : Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppColors.grayE7EBEE),
                  ),
          ),
        );
      }),
    );
  }
}

class _PlayheadArrowPainter extends CustomPainter {
  _PlayheadArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PlayheadArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TrimHandle extends StatelessWidget {
  const _TrimHandle({required this.isEnd});

  final bool isEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32.w,
      height: 32.w,
      decoration: BoxDecoration(
        color: AppColors.whiteFFFFFF,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.greyDDDDDD, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.black000000.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isEnd ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
        size: 18.sp,
        color: AppColors.gray8C9499,
      ),
    );
  }
}
