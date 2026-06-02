import 'dart:ui';
import 'package:omeeba_new/core/repository/like_repository.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/utils/app_functions.dart';

import '../exceptions/app_exception.dart';
import '../models/api_response.dart';

class LikeHelper {
  static bool _inProgress = false;
  static final repository = LikeRepository();


  static Future<void> toggleLike({
    required String contentId,
    required String contentType,

    /// current values
    required bool isLiked,
    required int likeCount,

    /// setters (to update UI model)
    required void Function(bool isLiked, int likeCount) onLocalUpdate,

    /// optional callback if parent wants to react
    VoidCallback? onComplete,
  }) async {
    // 🚫 prevent spam taps
    if (_inProgress) return;
    _inProgress = true;

    // save old state
    final oldLiked = isLiked;
    final oldCount = likeCount;

    // ⚡ optimistic update
    final newLiked = !oldLiked;
    final newCount = newLiked ? oldCount + 1 : oldCount - 1;
    onLocalUpdate(newLiked, newCount);

    try {
      await repository.likeUnlikeContent(
        body: {
          'contentId': contentId,
          'contentType': contentType,
        },
        onSuccess: (ApiResponse response) {
          final data = response.data;

          // ✅ backend truth
          onLocalUpdate(
            data['isLiked'] ?? newLiked,
            data['likeCount'] ?? newCount,
          );
        },
        onError: (AppException error) {
          // ⛔ rollback silently
          onLocalUpdate(oldLiked, oldCount);

          AppFunctions().showToast(
            error.message,
            bgColor: AppColors.red,
          );
        },
      );
    } catch (_) {
      // ⛔ rollback on crash
      onLocalUpdate(oldLiked, oldCount);
    } finally {
      _inProgress = false;
      onComplete?.call();
    }
  }
}