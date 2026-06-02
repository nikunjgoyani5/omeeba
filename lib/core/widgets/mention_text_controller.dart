import 'package:flutter/material.dart';
import 'package:omeeba_new/core/models/mention_user_model.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';

/// Custom TextEditingController that renders @username mentions in a different color (primary).
/// Use [getAvailableUsers] to supply the list of users that should be highlighted.
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
