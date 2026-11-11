// lib/services/widget_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/models/home_sort.dart';
import 'package:kmemo/models/note_palette.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_debug_log.dart';

class WidgetService {
  static const String _androidWidgetName = 'KMemoWidgetProvider';

  // Shared JSON file between Dart and Kotlin (same location for both)
  static const String _widgetDataFile = 'widget_data.json';

  // Localized labels (saved by the UI) used when a note has no title or content
  static const String _labelUntitledKey = 'widget_label_untitled';
  static const String _labelEmptyKey = 'widget_label_empty';
  static const String _labelListItemKey = 'widget_label_list_item';

  /// Set when the widget payload changed while the app was in the background.
  /// The native reload is deferred until the app is resumed so the list is not
  /// replaced while the user is scrolling the home-screen widget.
  static bool _reloadPending = false;

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

  /// Dark palette shared with the Flutter UI (editor, home cards) so the
  /// native widget stays in sync with the in-app colors.
  static final List<int> _darkColorsHex = kDarkNotePalette
      .map((color) => color.toARGB32())
      .toList(growable: false);

  /// Deterministic 32-bit FNV-1a hash used as the widget payload version.
  /// `String.hashCode` is not guaranteed to be stable across processes, and
  /// the native side compares this value across app restarts.
  static int _payloadVersion(String payload) {
    var hash = 0x811c9dc5;
    for (final codeUnit in payload.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Syncs active notes with the JSON file shared with the native Android side
  /// [isDark] controls whether light or dark color palette is used for note cards
  static Future<void> updateWidgetData({
    required AppDatabase db,
    bool isDark = false,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_widgetDataFile');
      final isResumed =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      final fileExists = await file.exists();
      await WidgetDebugLog.log(
        'updateWidgetData lifecycle=${WidgetsBinding.instance.lifecycleState?.name} '
        'fileExists=$fileExists',
      );

      // Freeze the widget payload while the app is in the background. The user
      // may be scrolling the home-screen widget; changing the data (or even
      // letting the launcher re-query the service) makes the list jump. The
      // latest data is written and applied when the app is resumed.
      if (!isResumed && fileExists) {
        _reloadPending = true;
        debugPrint('[WidgetService] App not resumed; widget update deferred.');
        await WidgetDebugLog.log('deferred: app not resumed');
        return;
      }

      final memos =
          await (db.select(db.memos)
                ..where((t) => t.isArchived.equals(false))
                ..where((t) => t.isDeleted.equals(false)))
              .get();

      debugPrint('[WidgetService] Active memos found: ${memos.length}');

      final prefs = await SharedPreferences.getInstance();
      // Use the same ordering rule as the home screen (pinned notes first).
      final sortMode = homeSortModeFromName(prefs.getString(kHomeSortModeKey));
      final sortAscending = prefs.getBool(kHomeSortAscendingKey) ?? false;
      memos.sort((a, b) => compareMemosForSort(a, b, sortMode, sortAscending));

      final untitledLabel = prefs.getString(_labelUntitledKey) ?? 'Untitled';
      final emptyLabel = prefs.getString(_labelEmptyKey) ?? 'Empty note';
      final listItemLabel =
          prefs.getString(_labelListItemKey) ?? 'Item de lista';
      final strikethroughChecked =
          prefs.getBool('strikethrough_checked') ?? true;
      final autoWrap = prefs.getBool('auto_wrap') ?? false;
      final widgetBgOpacity =
          prefs.getDouble('widget_bg_opacity') ?? 1.0;
      final widgetCardOpacity =
          prefs.getDouble('widget_card_opacity') ?? 1.0;

      final List<String> idsList = [];
      final List<String> titlesList = [];
      final List<String> previewsList = [];
      final List<int> colorsList = [];

      for (var memo in memos) {
        idsList.add(memo.uuid);

        final rawTitle = memo.title;
        final baseTitle = rawTitle.trim().isEmpty
            ? untitledLabel
            : rawTitle.trim();
        // Pinned notes are listed first and marked with a pin.
        titlesList.add(memo.isPinned ? '📌 $baseTitle' : baseTitle);

        final colorIndex = memo.colorIndex;
        final palette = isDark ? _darkColorsHex : _lightColorsHex;
        final hexColor = (colorIndex >= 0 && colorIndex < palette.length)
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
              final styledText = (checked && strikethroughChecked)
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
          '[WidgetService] Memo ${memo.uuid}: title="$baseTitle", preview="$displayPreview", color=0x${hexColor.toRadixString(16).padLeft(8, '0')}',
        );
      }

      // Writes JSON file to the application's documents directory
      final widgetPayload = {
        'ids': idsList,
        'titles': titlesList,
        'previews': previewsList,
        'colors': colorsList,
        'labels': {'untitled': untitledLabel, 'empty': emptyLabel},
        'settings': {
          'autoWrap': autoWrap,
          'strikethroughChecked': strikethroughChecked,
          'dark': isDark,
          'widgetBgOpacity': widgetBgOpacity,
          'widgetCardOpacity': widgetCardOpacity,
        },
      };
      // The version is a deterministic hash of the payload. The native side
      // only reloads the collection when this value changes, so launcher-
      // initiated onUpdate calls with identical data keep the scroll position.
      final payloadJson = jsonEncode(widgetPayload);
      final version = _payloadVersion(payloadJson);
      final json = jsonEncode({...widgetPayload, 'version': version});
      final unchanged = fileExists && await file.readAsString() == json;

      if (!unchanged) {
        await file.writeAsString(json);
        debugPrint('[WidgetService] Widget data written to: ${file.path}');
        debugPrint('[WidgetService] Titles: $titlesList');
        await WidgetDebugLog.log(
          'payload written notes=${memos.length} version=$version',
        );
      }

      // Skip the native reload when nothing changed. Every reload can reset
      // the user's scroll position.
      if (unchanged && !_reloadPending) {
        debugPrint('[WidgetService] Widget data unchanged; skipping reload.');
        await WidgetDebugLog.log('skip: payload unchanged');
        return;
      }

      // Notify the native widget to reload
      await WidgetDebugLog.log(
        'notify widget notes=${memos.length} reloadPending=$_reloadPending',
      );
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _androidWidgetName,
      );
      _reloadPending = false;

      debugPrint(
        '[WidgetService] Widget data synced successfully (${memos.length} notes).',
      );
    } catch (e) {
      debugPrint('[WidgetService] error syncing widget: $e');
      await WidgetDebugLog.log('error: $e');
    }
  }
}
