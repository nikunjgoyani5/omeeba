
import 'package:flutter_test/flutter_test.dart';

/// Integration scenarios for Zeal / Create Post (manual QA checklist).
///
/// Automated coverage: [camera serial ordering] — ensures queued async ops run one-by-one
/// (mirrors [CreatePostController._runCameraSerial] behavior).
///
/// Manual / device tests (run on real hardware):
/// 1. Record without music → stop → preview duration matches.
/// 2. Select music → wait for camera to settle → record → long-press stop → preview merges.
/// 3. Select music → tap record immediately after — should not double-start (controller guard).
/// 4. Record with music → pause (if supported) → resume → stop.
/// 5. Gallery pick → preview → back → record new clip; old thumbnail cleared after reset.
/// 6. Open Create Post → Zeal → leave → open again; no stale music/video.
/// 7. Re-record: first clip discarded, music reset per [CreatePostController._prepareZealRecordingSession].
void main() {
  group('Zeal Create Post — camera serial (ordering)', () {
    test('queued futures execute strictly in order', () async {
      final log = <int>[];
      Future<void> chain = Future<void>.value();

      void run(Future<void> Function() op) {
        chain = chain.then((_) => op());
      }

      run(() async {
        log.add(1);
        await Future<void>.delayed(Duration.zero);
      });
      run(() async => log.add(2));
      run(() async => log.add(3));

      await chain;
      expect(log, [1, 2, 3]);
    });
  });
}
