// lib/providers/memo_provider.dart
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:kmemo/database/database.dart';
import 'package:kmemo/services/widget_service.dart';

class MemoProvider extends ChangeNotifier {
  final AppDatabase _db;
  List<Memo> _memos = [];
  bool _isLoading = false;

  MemoProvider(this._db) {
    _loadMemos();
  }

  List<Memo> get memos => _memos;
  bool get isLoading => _isLoading;

  /// Carrega as notas da base de dados ordenadas pela data de atualização decrescente
  Future<void> _loadMemos() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Usando o método nativo ou a query fluida baseada em updatedAt
      _memos =
          await (_db.select(_db.memos)..orderBy([
                (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
              .get();
    } catch (e) {
      debugPrint('[MemoProvider] Erro ao carregar notas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recupera os blocos ativos de uma nota específica usando o método nativo da tua BD
  Future<List<Block>> getBlocksForMemo(String memoUuid) async {
    try {
      return await _db.getBlocksForMemo(memoUuid);
    } catch (e) {
      debugPrint('[MemoProvider] Erro ao carregar blocos: $e');
      return [];
    }
  }

  /// Cria uma nova nota com um bloco de texto inicial vazio
  Future<Memo> createMemo({required String title}) async {
    final now = DateTime.now();
    final generatedUuid = UniqueKey().toString();

    final memo = Memo(
      uuid: generatedUuid,
      title: title,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    );

    final initialBlock = Block(
      id: 0, // O autoIncrement do Drift trata disto no insert
      uuid: UniqueKey().toString(),
      memoUuid: generatedUuid,
      type: BlockType.text, // Usando o teu Enum nativo
      content: const {'text': ''}, // Usando o teu MapConverter nativo
      sortOrder: 0, // Usando a tua coluna real sortOrder
      isDeleted: false,
    );

    // Invoca a transação atómica que escreveste na BD
    await _db.saveMemoWithBlocks(memo, [initialBlock]);

    await _loadMemos();
    await WidgetService.updateWidgetData(db: _db);

    return _memos.firstWhere((m) => m.uuid == generatedUuid);
  }

  /// Atualiza o título e sincroniza o estado dos blocos utilizando a transação nativa
  Future<void> saveMemoContent({
    required String memoUuid,
    required String title,
    required List<Block> updatedBlocks,
  }) async {
    final now = DateTime.now();

    final memo = Memo(
      uuid: memoUuid,
      title: title,
      createdAt:
          now, // Será ignorado se for apenas atualização ou tratado pelo insertOrReplace
      updatedAt: now,
      isSynced: false,
    );

    // Primeiro, marcamos os blocos antigos desta nota como removidos ou limpamos
    // Para simplificar a reordenação, limpamos os blocos não marcados e reinserimos com o sortOrder atualizado
    await (_db.delete(
      _db.blocks,
    )..where((t) => t.memoUuid.equals(memoUuid))).go();

    final List<Block> blocksToSave = [];
    for (int i = 0; i < updatedBlocks.length; i++) {
      final b = updatedBlocks[i];
      blocksToSave.add(
        Block(
          id: 0,
          uuid: b.uuid.isEmpty ? UniqueKey().toString() : b.uuid,
          memoUuid: memoUuid,
          type: b.type,
          content: b.content,
          sortOrder: i, // Aplica o índice sequencial na coluna sortOrder
          isDeleted: b.isDeleted,
        ),
      );
    }

    await _db.saveMemoWithBlocks(memo, blocksToSave);
    await _loadMemos();
    await WidgetService.updateWidgetData(db: _db);
  }

  /// Remove permanentemente a nota (A tua FK com onDelete: KeyAction.cascade trata dos blocos)
  Future<void> deleteMemo(String uuid) async {
    await _db.deleteMemoCascading(uuid);
    await _loadMemos();
    await WidgetService.updateWidgetData(db: _db);
  }
}
