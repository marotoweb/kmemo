// lib/ui/widgets/simple_markdown.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders the small subset of Markdown used by the GitHub release notes.
///
/// The update dialog used to print the body of the release as it arrived, so
/// headings, bold text and links kept their markers (`###`, `**`, `[...](...)`).
/// The app does not need a full Markdown engine for this: the notes are the
/// section of `CHANGELOG.md` published with the release, which only uses
/// headings, bullets, bold, inline code and links.
class SimpleMarkdown extends StatefulWidget {
  const SimpleMarkdown(this.data, {super.key, this.baseStyle, this.onLinkTap});

  final String data;

  /// Used for body text; headings and links derive their style from it.
  final TextStyle? baseStyle;

  /// Called when a link is tapped. Defaults to opening it in the browser.
  ///
  /// Tests use it to check the parsed URL without launching anything.
  final void Function(Uri uri)? onLinkTap;

  @override
  State<SimpleMarkdown> createState() => _SimpleMarkdownState();
}

class _SimpleMarkdownState extends State<SimpleMarkdown> {
  /// Tap recognizers are created per build because a [TextSpan] cannot be
  /// reused; the previous ones are disposed before the next build.
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  static final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^\s*[-*+]\s+(.*)$');
  static final RegExp _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
  static final RegExp _rule = RegExp(r'^\s*([-*_])\1{2,}\s*$');
  static final RegExp _inlinePattern = RegExp(
    r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\(([^)]+)\)|\*(?!\*)(.+?)\*',
  );

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final theme = Theme.of(context);
    final base =
        widget.baseStyle ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final blocks = <Widget>[];

    for (final raw in widget.data.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 8));
        continue;
      }

      if (_rule.hasMatch(line)) {
        blocks.add(const Divider(height: 16));
        continue;
      }

      final heading = _heading.firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final style = switch (level) {
          1 => theme.textTheme.titleLarge,
          2 => theme.textTheme.titleMedium,
          _ => theme.textTheme.titleSmall,
        };
        blocks.add(
          Padding(
            padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 10, bottom: 2),
            child: Text.rich(_inline(context, heading.group(2)!, style, base)),
          ),
        );
        continue;
      }

      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        blocks.add(
          _listItem(
            marker: '•',
            text: _inline(context, bullet.group(1)!, base, base),
            style: base,
          ),
        );
        continue;
      }

      final numbered = _numbered.firstMatch(line);
      if (numbered != null) {
        blocks.add(
          _listItem(
            marker: '${numbered.group(1)}.',
            text: _inline(context, numbered.group(2)!, base, base),
            style: base,
          ),
        );
        continue;
      }

      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text.rich(_inline(context, line.trim(), base, base)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  Widget _listItem({
    required String marker,
    required TextSpan text,
    required TextStyle style,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 20, child: Text(marker, style: style)),
          Expanded(child: Text.rich(text)),
        ],
      ),
    );
  }

  /// Turns one line into spans, handling bold, inline code, links and italics.
  TextSpan _inline(
    BuildContext context,
    String text,
    TextStyle? style,
    TextStyle base,
  ) {
    final spans = <InlineSpan>[];
    var index = 0;

    for (final match in _inlinePattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }

      final bold = match.group(1);
      final code = match.group(2);
      final label = match.group(3);
      final url = match.group(4);
      final italic = match.group(5);

      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (code != null) {
        spans.add(
          TextSpan(
            text: code,
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      } else if (label != null && url != null) {
        final uri = Uri.tryParse(url);
        if (uri == null) {
          spans.add(TextSpan(text: label));
        } else {
          final recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
          _recognizers.add(recognizer);
          spans.add(
            TextSpan(
              text: label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              recognizer: recognizer,
            ),
          );
        }
      } else if (italic != null) {
        spans.add(
          TextSpan(
            text: italic,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }

      index = match.end;
    }

    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }

    return TextSpan(style: style ?? base, children: spans);
  }

  void _open(Uri uri) {
    final handler = widget.onLinkTap;
    if (handler != null) {
      handler(uri);
      return;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
