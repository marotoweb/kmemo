// lib/ui/widgets/highlighted_text.dart

import 'package:flutter/material.dart';

import '../../models/search_highlight.dart';

/// A [Text] built from [buildHighlightedSpans], so occurrences of [query]
/// are visually highlighted.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const HighlightedText({
    super.key,
    required this.text,
    this.query = '',
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: buildHighlightedSpans(
          text: text,
          query: query,
          baseStyle: style,
        ),
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
