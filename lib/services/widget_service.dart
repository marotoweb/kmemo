// lib/services/widget_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:home_widget/home_widget.dart';
import 'package:kmemo/database/database.dart';
import 'package:path_provider/path_provider.dart';

class WidgetService {
  static const String _androidWidgetName = 'KMemoWidgetProvider';

  // Shared JSON file between Dart and Kotlin (same location for both)
  static const String _widgetDataFile = 'widget_data.json';

  static const List<int> _lightColorsHex = [
    0xFFFFFFFF, // Branco
    0xFFFFCDD2, // Vermelho claro
    0xFFFFE0B2, // Laranja claro
    0xFFFFF9C4, // Amarelo claro
    0xFFC8E6C9, // Verde claro
    0xFFB2DFDB, // Teal claro
    0xFFBBDEFB, // Azul claro
    0xFFC5CAE9, // Índigo claro
    0xFFE1BEE7, // Roxo claro
    0xFFF8BBD0, // Rosa claro
    0xFFD7CCC8, // Castanho claro
    0xFFCFD8DC, // Azul-acinzentado claro
    0xFFFFECB3, // Âmbar claro
    0xFFDCEDC8, // Verde-lima claro
    0xFFB2EBF2, // Ciano claro
    0xFFF5F5F5, // Cinzento muito claro
  ];

  /// Syncs active notes with the JSON file shared with the native Android side
  static Future<void> updateWidgetData({required AppDatabase db}) async {
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

      final List<String> idsList = [];
      final List<String> titlesList = [];
      final List<String> previewsList = [];
      final List<int> colorsList = [];

      for (var memo in memos) {
        idsList.add(memo.uuid);

        final rawTitle = memo.title;
        final displayTitle = rawTitle.trim().isEmpty
            ? 'Sem título'
            : rawTitle.trim();
        titlesList.add(displayTitle);

        final colorIndex = memo.colorIndex;
        final hexColor =
            (colorIndex >= 0 && colorIndex < _lightColorsHex.length)
            ? _lightColorsHex[colorIndex]
            : 0xFFFFFFFF;
        colorsList.add(hexColor);

        final blocks = await db.getBlocksForMemo(memo.uuid);
        String previewText = '';

        if (blocks.isNotEmpty) {
          final isChecklist = blocks.any((b) => b.type == BlockType.checklist);

          if (isChecklist) {
            // Shoes up to 8 items with checkbox, then "..."
            final sortedBlocks = List<Block>.from(blocks)
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            final hasMoreThanEight = sortedBlocks.length > 8;
            final visibleBlocks = sortedBlocks.take(8).toList();

            final lines = <String>[];
            for (var block in visibleBlocks) {
              final checked = block.content['checked'] as bool? ?? false;
              final text = block.content['text']?.toString() ?? '';
              final displayText = text.isEmpty ? 'Item de lista' : text;
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

        final displayPreview = previewText.isEmpty ? 'Nota vazia' : previewText;
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
      };
      await file.writeAsString(jsonEncode(widgetData));

      debugPrint('[WidgetService] Widget date written to: ${file.path}');
      debugPrint('[WidgetService] Titles: $titlesList');

      // Notifica the widget nativo for recarregar
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
