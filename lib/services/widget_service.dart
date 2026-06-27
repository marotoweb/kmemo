// lib/services/widget_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:kmemo/database/database.dart';

class WidgetService {
  static const String _androidWidgetName = 'KMemoWidgetProvider';

  /// Atualiza os dados partilhados com o Widget nativo do Home Screen
  static Future<void> updateWidgetData({required AppDatabase db}) async {
    try {
      // 1. Ir buscar as últimas notas ordenadas por atualização
      final memos =
          await (db.select(db.memos)
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(5))
              .get();

      final List<String> titlesList = [];
      final List<String> idsList = [];
      final List<String> previewsList = [];

      for (var memo in memos) {
        idsList.add(memo.uuid);
        titlesList.add(memo.title.trim().isEmpty ? 'Sem título' : memo.title);

        // 2. Procurar os blocos desta nota para criar uma pré-visualização de texto limpa
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

      // 3. Gravar os dados como Strings JSON estáveis (evita falhas de tipagem no canal nativo)
      await HomeWidget.saveWidgetData<String>('notes_ids', jsonEncode(idsList));
      await HomeWidget.saveWidgetData<String>(
        'notes_titles',
        jsonEncode(titlesList),
      );
      await HomeWidget.saveWidgetData<String>(
        'notes_previews',
        jsonEncode(previewsList),
      );

      // 4. Notificar o sistema operativo para redesenhar o Widget de imediato
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _androidWidgetName,
      );

      debugPrint(
        '[WidgetService] Dados enviados para o ecrã principal com sucesso.',
      );
    } catch (e) {
      debugPrint('[WidgetService] Erro ao sincronizar dados com o Widget: $e');
    }
  }
}
