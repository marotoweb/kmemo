// lib/services/widget_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:kmemo/database/database.dart';

class WidgetService {
  static const String _androidWidgetName = 'KMemoWidgetProvider';

  /// Sincroniza as notas ativas com o armazenamento partilhado do Android
  static Future<void> updateWidgetData({required AppDatabase db}) async {
    try {
      // Obtém todas as notas ativas diretamente da base de dados
      final memos = await (db.select(db.memos)).get();

      final List<String> idsList = [];
      final List<String> titlesList = [];
      final List<String> previewsList = [];
      final List<int> colorsList = [];
      final List<int> bgImagesList = [];

      for (var memo in memos) {
        idsList.add(memo.uuid);
        titlesList.add(memo.title.trim().isEmpty ? 'Sem título' : memo.title);
        colorsList.add(memo.colorIndex);
        bgImagesList.add(memo.bgImageIndex);

        // Extrai texto limpo dos blocos para a pré-visualização
        final blocks = await db.getBlocksForMemo(memo.uuid);
        String previewText = '';

        if (blocks.isNotEmpty) {
          final textBlocks = blocks
              .map((b) => b.content['text']?.toString() ?? '')
              .where((text) => text.isNotEmpty)
              .take(2);
          previewText = textBlocks.join(' / ');
        }

        previewsList.add(previewText.isEmpty ? 'Nota vazia' : previewText);
      }

      // Persiste os arrays em formato JSON nas preferências partilhadas
      await HomeWidget.saveWidgetData<String>('notes_ids', jsonEncode(idsList));
      await HomeWidget.saveWidgetData<String>(
        'notes_titles',
        jsonEncode(titlesList),
      );
      await HomeWidget.saveWidgetData<String>(
        'notes_previews',
        jsonEncode(previewsList),
      );
      await HomeWidget.saveWidgetData<String>(
        'notes_colors',
        jsonEncode(colorsList),
      );
      await HomeWidget.saveWidgetData<String>(
        'notes_bg_images',
        jsonEncode(bgImagesList),
      );

      // 4. Emite o sinal de broadcast para o gestor nativo de widgets
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _androidWidgetName,
      );

      debugPrint(
        '[WidgetService] Sincronização do widget concluída com sucesso.',
      );
    } catch (e) {
      debugPrint('[WidgetService] Falha ao sincronizar dados com o widget: $e');
    }
  }
}
