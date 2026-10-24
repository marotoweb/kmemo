// lib/services/widget_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:home_widget/home_widget.dart';
import 'package:kmemo/database/database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  static const String _androidWidgetName = 'KMemoWidgetProvider';

  // Shared JSON file between Dart and Kotlin (same location for both)
  static const String _widgetDataFile = 'widget_data.json';

  // Localized labels (saved by the UI) used when a note has no title or content
  static const String _labelUntitledKey = 'widget_label_untitled';
  static const String _labelEmptyKey = 'widget_label_empty';
  static const String _labelListItemKey = 'widget_label_list_item';

  static Future<void> saveLabels({
    required String untitled,
    required String empty,
    required String listItem,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_labelUntitledKey, untitled);
    await prefs.setString(_labelEmptyKey, empty);
    await prefs.setString(_labelListItemKey, listItem);
  }

  static const List<int> _lightColorsHex = [
    0xFFFFFFFF, // Branco
    0xFFFFCDD2, // Vermelho claro
    0xFFFFE0B2, // Laranja claro
    0xFFFFF9C4, // Amarelo claro
    0xFFC8E6C9, // Verde claro
    0xFFB2DFDB, // Teal claro
    0xFFBBDEFB, // Azul claro
    0xFFC5CAE9, // Light indigo
    0xFFE1BEE7, // Roxo claro
    0xFFF8BBD0, // Rosa claro
    0xFFD7CCC8, // Castanho claro
    0xFFCFD8DC, // Azul-acinzentado claro
    0xFFFFECB3, // Light amber
    0xFFDCEDC8, // Verde-lima claro
    0xFFB2EBF2, // Ciano claro
    0xFFF5F5F5, // Cinzento muito claro
  ];

  static const List<int> _darkColorsHex = [
    0xFF1E1E1E, // Preto
    0xFF3B1A1A, // Vermelho escuro
    0xFF3D2C1E, // Laranja escuro
    0xFF3D361E, // Amarelo escuro
    0xFF1E3322, // Verde escuro
    0xFF1E3331, // Teal escuro
    0xFF1E2A3B, // Azul escuro
    0xFF261E3B, // Indigo escuro
    0xFF331E3B, // Roxo escuro
    0xFF3B1E32, // Rosa escuro
    0xFF2E2621, // Castanho escuro
    0xFF252B2E, // Azul-acinzentado escuro
    0xFF3B2E1E, // Amber escuro
    0xFF27331E, // Verde-lima escuro
    0xFF1E3338, // Ciano escuro
    0xFF2C2C2C, // Cinzento escuro
  ];

  /// Syncs active notes with the JSON file shared with the native Android side
  /// [isDark] controls whether light or dark color palette is used for note cards
  static Future<void> updateWidgetData({required AppDatabase db, bool isDark = false}) async {
    try {
      final memos =
          await (db.select(db.memos)
                ..where((t) => t.isArchived.equals(false))
                ..where((t) => t.isDeleted.equals(false))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();

      debugPrint('[WidgetService] Memos activos encontrados: ${memos.length}');

      final prefs = await SharedPreferences.getInstance();
      final untitledLabel = prefs.getString(_labelUntitledKey) ?? 'Sem título';
      final emptyLabel = prefs.getString(_labelEmptyKey) ?? 'Nota vazia';
      final listItemLabel = prefs.getString(_labelListItemKey) ?? 'Item de lista';

      final List<String> idsList = [];
      final List<String> titlesList = [];
      final List<String> previewsList = [];
      final List<int> colorsList = [];

      for (var memo in memos) {
        idsList.add(memo.uuid);

        final rawTitle = memo.title;
        final displayTitle = rawTitle.trim().isEmpty
            ? untitledLabel
            : rawTitle.trim();
        titlesList.add(displayTitle);

        final colorIndex = memo.colorIndex;
        final palette = isDark ? _darkColorsHex : _lightColorsHex;
        final hexColor =
            (colorIndex >= 0 && colorIndex < palette.length)
            ? palette[colorIndex]
            : (isDark ? 0xFF1E1E1E : 0xFFFFFFFF);
        colorsList.add(hexColor);

        final blocks = await db.getBlocksForMemo(memo.uuid);
        String previewText = '';

        if (blocks.isNotEmpty) {
          final isChecklist = blocks.any((b) => b.type == BlockType.checklist);

          if (isChecklist) {
            // Shows up to 8 items with a checkbox, then "..."
            final sortedBlocks = List<Block>.from(blocks)
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            final hasMoreThanEight = sortedBlocks.length > 8;
            final visibleBlocks = sortedBlocks.take(8).toList();

            final lines = <String>[];
            for (var block in visibleBlocks) {
              final checked = block.content['checked'] as bool? ?? false;
              final text = block.content['text']?.toString() ?? '';
              final displayText = text.isEmpty ? listItemLabel : text;
              final styledText = checked
                  ? displayText.replaceAllMapped(
                      RegExp(r'.'),
                      (m) => '${m.group(0)!}\u0336',
                    )
                  : displayText;
              lines.add('${checked ? '☑' : '☐'} $styledText');
            }
            if (hasMoreThanEight) {
              lines.add('...');
            }
            previewText = lines.join('\n');
          } else {
            // text: shows up to 7 lines + "..." on line 8 (matches maxLines=8 of the preview)
            final contentText = blocks
                .map((b) => b.content['text']?.toString() ?? '')
                .join('\n');
            if (contentText.trim().isEmpty) {
              previewText = '';
            } else {
              final lines = contentText.split('\n');
              final hasMoreThanSeven = lines.length > 7;
              previewText = hasMoreThanSeven
                  ? '${lines.take(7).join('\n')}\n...'
                  : contentText;
            }
          }
        }

        final displayPreview = previewText.isEmpty ? emptyLabel : previewText;
        previewsList.add(displayPreview);

        debugPrint(
          '[WidgetService] Memo ${memo.uuid}: title="$displayTitle", preview="$displayPreview", color=0x${hexColor.toRadixString(16).padLeft(8, '0')}',
        );
      }

      // Writes JSON file to the application's documents directory
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_widgetDataFile');
      final widgetData = {
        'ids': idsList,
        'titles': titlesList,
        'previews': previewsList,
        'colors': colorsList,
        'labels': {'untitled': untitledLabel, 'empty': emptyLabel},
      };
      await file.writeAsString(jsonEncode(widgetData));

      debugPrint('[WidgetService] Widget data written to: ${file.path}');
      debugPrint('[WidgetService] Titles: $titlesList');

      // Notify the native widget to reload
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _androidWidgetName,
      );

      debugPrint(
        '[WidgetService] Widget data synced successfully (${memos.length} notes).',
      );
    } catch (e) {
      debugPrint('[WidgetService] error syncing widget: $e');
    }
  }
}
