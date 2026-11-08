// lib/models/search_highlight.dart

import 'package:flutter/material.dart';

/// Returns a list of [TextSpan]s for [text] where every case-insensitive
/// occurrence of [query] is highlighted with [highlightStyle].
///
/// When [query] is empty (or only whitespace) the result is a single span
/// containing the whole text, so callers can always use `Text.rich`.
List<TextSpan> buildHighlightedSpans({
  required String text,
  required String query,
  required TextStyle baseStyle,
  TextStyle? highlightStyle,
}) {
  final effectiveQuery = query.trim();
  if (effectiveQuery.isEmpty) {
    return <TextSpan>[TextSpan(text: text, style: baseStyle)];
  }

  final resolvedHighlight = (highlightStyle ?? const TextStyle()).merge(
    const TextStyle(
      backgroundColor: Color(0x99FFC107),
      color: Color(0xFF1A1A1A),
      fontWeight: FontWeight.w600,
    ),
  );

  final lowerText = text.toLowerCase();
  final lowerQuery = effectiveQuery.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;

  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) {
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      }
      break;
    }
    if (index > start) {
      spans.add(
        TextSpan(text: text.substring(start, index), style: baseStyle),
      );
    }
    final end = index + effectiveQuery.length;
    spans.add(
      TextSpan(
        text: text.substring(index, end),
        style: resolvedHighlight.merge(baseStyle),
      ),
    );
    start = end;
  }

  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: baseStyle));
  }
  return spans;
}
