// lib/providers/memo_provider.dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../services/widget_service.dart';
import 'package:drift/drift.dart';

class MemoProvider extends ChangeNotifier {
  final AppDatabase _db;
  List<Memo> _memos = [];
  bool _isLoading = true;
  final _uuid = const Uuid();

  MemoProvider(this._db) {
    _listenToMemos();
  }

  List<Memo> get memos => _memos;

  List<Memo> get activeMemos =>
      _memos.where((m) => !m.isArchived && !m.isDeleted).toList();
  List<Memo> get archivedMemos =>
      _memos.where((m) => m.isArchived && !m.isDeleted).toList();
  List<Memo> get deletedMemos => _memos.where((m) => m.isDeleted).toList();

  bool get isLoading => _isLoading;

  void _listenToMemos() {
    _db.watchAllMemos().listen(
      (listOfMemos) {
        _memos = listOfMemos;
        _isLoading = false;
        notifyListeners();
        _updateWidgetData();
      },
      onError: (_) {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<Memo> createNewMemo() async {
    final now = DateTime.now();
    final memo = Memo(
      uuid: _uuid.v4(),
      title: '',
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      colorIndex: 0,
      bgImageIndex: -1,
      imageAttachments: '[]',
      audioAttachments: '[]',
      linkAttachments: '[]',
      isArchived: false,
      isDeleted: false,
    );

    await _db.transaction(() async {
      await _db.into(_db.memos).insert(memo, mode: InsertMode.insertOrReplace);

      await _db
          .into(_db.blocks)
          .insert(
            BlocksCompanion.insert(
              uuid: _uuid.v4(),
              memoUuid: memo.uuid,
              type: BlockType.text,
              content: const Value({'text': ''}),
              sortOrder: const Value(0),
              isDeleted: const Value(false),
            ),
          );
    });

    return memo;
  }

  Future<List<Block>> loadBlocks(String memoUuid) async {
    return await _db.getBlocksForMemo(memoUuid);
  }

  Future<List<Block>> saveMemo(Memo memo, List<Block> blocks) async {
    final updatedMemo = memo.copyWith(updatedAt: DateTime.now());
    final List<Block> updatedBlocksList = List.from(blocks);

    await _db.transaction(() async {
      await _db
          .into(_db.memos)
          .insert(updatedMemo, mode: InsertMode.insertOrReplace);

      final existingBlocks = await (_db.select(
        _db.blocks,
      )..where((t) => t.memoUuid.equals(memo.uuid))).get();

      final activeUuids = blocks.map((b) => b.uuid).toSet();

      final blocksToDelete = existingBlocks
          .where((b) => !activeUuids.contains(b.uuid))
          .toList();

      if (blocksToDelete.isNotEmpty) {
        final idsToDelete = blocksToDelete.map((b) => b.uuid).toList();
        await (_db.delete(_db.blocks)..where(
              (t) => t.memoUuid.equals(memo.uuid) & t.uuid.isIn(idsToDelete),
            ))
            .go();
      }

      for (int i = 0; i < updatedBlocksList.length; i++) {
        final block = updatedBlocksList[i];
        if (block.id == 0) {
          final generatedId = await _db
              .into(_db.blocks)
              .insert(
                BlocksCompanion.insert(
                  uuid: block.uuid,
                  memoUuid: block.memoUuid,
                  type: block.type,
                  content: Value(block.content),
                  sortOrder: Value(block.sortOrder),
                  isDeleted: Value(block.isDeleted),
                ),
                mode: InsertMode.insertOrReplace,
              );
          updatedBlocksList[i] = block.copyWith(id: generatedId);
        } else {
          await _db
              .into(_db.blocks)
              .insert(block, mode: InsertMode.insertOrReplace);
        }
      }
    });

    return updatedBlocksList;
  }

  Future<void> _updateWidgetData() async {
    await WidgetService.updateWidgetData(db: _db);
  }

  Future<void> archiveMemo(String memoUuid) async {
    await _db.updateMemoArchiveStatus(memoUuid, true);
  }

  Future<void> archiveMultiple(List<String> uuids) async {
    for (var id in uuids) {
      await _db.updateMemoArchiveStatus(id, true);
    }
  }

  Future<void> archiveMemoStatus(String memoUuid, bool isArchived) async {
    await _db.updateMemoArchiveStatus(memoUuid, isArchived);
  }

  // Marcar como eliminado (Enviar para a Lixeira)
  Future<void> softDeleteMultiple(List<String> uuids) async {
    for (var id in uuids) {
      final match = _memos.cast<Memo?>().firstWhere(
        (m) => m?.uuid == id,
        orElse: () => null,
      );
      if (match != null) {
        final blocks = await _db.getBlocksForMemo(match.uuid);
        await _db.saveMemoWithBlocks(match.copyWith(isDeleted: true), blocks);
      }
    }
  }

  // Restaurar da Lixeira
  Future<void> restoreMultiple(List<String> uuids) async {
    for (var id in uuids) {
      final match = _memos.cast<Memo?>().firstWhere(
        (m) => m?.uuid == id,
        orElse: () => null,
      );
      if (match != null) {
        final blocks = await _db.getBlocksForMemo(match.uuid);
        await _db.saveMemoWithBlocks(match.copyWith(isDeleted: false), blocks);
      }
    }
  }

  // Eliminar permanentemente da base de dados
  Future<void> deleteMultiplePermanent(List<String> uuids) async {
    for (var id in uuids) {
      await _db.deleteMemoCascading(id);
    }
  }

  Future<void> deleteMultiple(List<String> uuids) async {
    await softDeleteMultiple(uuids);
  }

  Future<void> deleteMemo(String memoUuid) async {
    await softDeleteMultiple([memoUuid]);
  }

  Future<void> changeColorMultiple(List<String> uuids, int colorIndex) async {
    final List<Memo> targets = [];
    for (var id in uuids) {
      final match = _memos.cast<Memo?>().firstWhere(
        (m) => m?.uuid == id,
        orElse: () => null,
      );
      if (match != null) {
        targets.add(match);
      }
    }

    for (var memo in targets) {
      final blocks = await _db.getBlocksForMemo(memo.uuid);
      await _db.saveMemoWithBlocks(
        memo.copyWith(colorIndex: colorIndex),
        blocks,
      );
    }
  }

  Future<void> duplicateMultiple(List<String> uuids) async {
    final now = DateTime.now();
    final List<Memo> targets = [];

    for (var id in uuids) {
      final match = _memos.cast<Memo?>().firstWhere(
        (m) => m?.uuid == id,
        orElse: () => null,
      );
      if (match != null) {
        targets.add(match);
      }
    }

    for (var memo in targets) {
      final blocks = await _db.getBlocksForMemo(memo.uuid);
      final newUuid = _uuid.v4();

      final duplicatedMemo = memo.copyWith(
        uuid: newUuid,
        title: memo.title.isNotEmpty ? '${memo.title} (Cópia)' : '',
        createdAt: now,
        updatedAt: now,
        isSynced: false,
        isDeleted: false,
      );

      final duplicatedBlocks = blocks
          .map(
            (b) => Block(
              id: 0,
              uuid: _uuid.v4(),
              memoUuid: newUuid,
              type: b.type,
              content: b.content,
              sortOrder: b.sortOrder,
              isDeleted: b.isDeleted,
            ),
          )
          .toList();

      await _db.saveMemoWithBlocks(duplicatedMemo, duplicatedBlocks);
    }
  }
}
