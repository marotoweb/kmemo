// Parsing of text shared from other apps into note blocks.

/// Kind of block produced while parsing shared text.
enum SharedTextBlockType { text, checklist }

/// A block spec produced by [parseSharedText], before it is persisted.
class SharedTextBlock {
  const SharedTextBlock({
    required this.type,
    required this.text,
    this.checked = false,
  });

  final SharedTextBlockType type;
  final String text;
  final bool checked;
}

/// Parsed representation of a shared text: the note title and its blocks.
class SharedTextNote {
  const SharedTextNote({required this.title, required this.blocks});

  final String title;
  final List<SharedTextBlock> blocks;
}

/// Matches checklist lines such as `[ ] task`, `[x] task`, `- [ ] task`
/// or `* [X] task`. Plain brackets with other content (`[foo]`) never match.
final RegExp _checklistLine = RegExp(r'^\s*[-*]?\s*\[([xX ]?)\]\s*(.*)$');

/// Converts shared text into a note title plus blocks.
///
/// The text is only treated as a checklist when it contains real checklist
/// markers (`[ ]`, `[x]`). Text without markers stays plain text, where
/// consecutive lines are grouped into one block per paragraph.
///
/// In checklist mode, a line without a marker continues the previous block
/// (instead of becoming a new checkbox), so wrapped or indented descriptions
/// stay attached to their item.
SharedTextNote parseSharedText(String input, {required String fallbackTitle}) {
  final sanitized = input.trim();
  if (sanitized.isEmpty) {
    return SharedTextNote(title: fallbackTitle, blocks: const []);
  }

  final lines = sanitized.split('\n');
  final firstLine = lines.first.trim();
  final firstLineIsChecklist = _checklistLine.hasMatch(firstLine);
  final hasChecklistMarkers = lines.any(_checklistLine.hasMatch);

  final title = firstLineIsChecklist
      ? fallbackTitle
      : (firstLine.isNotEmpty ? firstLine : fallbackTitle);
  final bodyLines = firstLineIsChecklist
      ? lines
      : (lines.length > 1 ? lines.sublist(1) : const <String>[]);

  final blocks = <SharedTextBlock>[];

  if (!hasChecklistMarkers) {
    final buffer = <String>[];
    void flushText() {
      if (buffer.isEmpty) return;
      blocks.add(
        SharedTextBlock(
          type: SharedTextBlockType.text,
          text: buffer.join('\n'),
        ),
      );
      buffer.clear();
    }

    for (final line in bodyLines) {
      if (line.trim().isEmpty) {
        flushText();
      } else {
        buffer.add(line.trimRight());
      }
    }
    flushText();
  } else {
    for (final line in bodyLines) {
      if (line.trim().isEmpty) continue;
      final match = _checklistLine.firstMatch(line);
      if (match != null) {
        final text = (match.group(2) ?? '').trim();
        // Ignore bare markers ([ ], [x]) that would create empty items.
        if (text.isEmpty) continue;
        blocks.add(
          SharedTextBlock(
            type: SharedTextBlockType.checklist,
            text: text,
            checked: (match.group(1) ?? '').toLowerCase() == 'x',
          ),
        );
      } else {
        final text = line.trim();
        if (blocks.isEmpty) {
          blocks.add(
            SharedTextBlock(type: SharedTextBlockType.text, text: text),
          );
        } else {
          final last = blocks.removeLast();
          blocks.add(
            SharedTextBlock(
              type: last.type,
              text: '${last.text}\n$text',
              checked: last.checked,
            ),
          );
        }
      }
    }
  }

  // A note without any body keeps the full shared text as a single text block.
  if (blocks.isEmpty) {
    blocks.add(
      SharedTextBlock(
        type: SharedTextBlockType.text,
        text: bodyLines.join('\n').trim(),
      ),
    );
  }

  return SharedTextNote(title: title, blocks: blocks);
}
