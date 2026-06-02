import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/exports.dart';

class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;
  final Future<bool> Function(Uri uri, String rawText)? onLinkTap;

  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 10,
    this.overflow = TextOverflow.clip,
    this.textAlign = TextAlign.start,
    this.onLinkTap,
  });

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  bool _isExpanded = false;
  bool _showReadMore = false;

  List<InlineSpan> _buildSpans() {
    final List<InlineSpan> spans = [];

    final regex = RegExp(
      r'((https?:\/\/|ftp:\/\/)[^\s]+)|(www\.[^\s]+)|([\w\.-]+@[\w\.-]+\.\w+)|(\+?\d{1,3}[- ]?\d{10})',
      caseSensitive: false,
    );

    int lastIndex = 0;

    for (final match in regex.allMatches(widget.text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: widget.text.substring(lastIndex, match.start),
          style: widget.style,
        ));
      }

      final matchText = match.group(0) ?? "";

      spans.add(
        TextSpan(
          text: matchText,
          style: widget.style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: widget.style.color,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              String url = matchText;

              if (url.startsWith('www')) {
                url = 'https://$url';
              } else if (RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$')
                  .hasMatch(url)) {
                url = 'mailto:$url';
              } else if (RegExp(r'^\+?\d').hasMatch(url)) {
                url = 'tel:$url';
              }

              final uri = Uri.parse(url);
              if (widget.onLinkTap != null) {
                final handled = await widget.onLinkTap!(uri, matchText);
                if (handled) return;
              }
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(lastIndex),
        style: widget.style,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return Text("", style: widget.style);
    }

    final spans = _buildSpans();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(children: spans, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(maxWidth: constraints.maxWidth);

        _showReadMore = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: spans, style: widget.style),
              maxLines: _isExpanded ? null : widget.maxLines,
              overflow:
              _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              textAlign: widget.textAlign,
            ),

            if (_showReadMore)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _isExpanded ? "Read less" : "Read more",
                    style: widget.style.copyWith(
                      color: widget.style.color, // customize
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}