// lib/providers/memo_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../services/kdrive_storage.dart';
import '../services/storage_repository.dart';
import '../services/encryption_service.dart';
import '../services/widget_service.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoProvider extends ChangeNotifier {
  final AppDatabase _db;
  final KDriveStorage? _storage;
  List<Memo> _memos = [];
  bool _isLoading = true;
  final _uuid = const Uuid();
  Timer? _syncDebounce;

  MemoProvider(this._db, {KDriveStorage? storage}) : _storage = storage {
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
    // Local changes mark the note as not synced (needs upload)
    final updatedMemo = memo.copyWith(
      updatedAt: DateTime.now(),
      isSynced: false,
    );
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

    _scheduleSync();
    return updatedBlocksList;
  }

  Future<void> _updateWidgetData() async {
    await WidgetService.updateWidgetData(db: _db);
  }

  /// Schedules remote sync with debounce (avoids calling the API on every keystroke).
  void _scheduleSync() {
    if (_storage == null || !_storage.isConfigured) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 3), () async {
      try {
        await performSync();
      } catch (_) {
        // Sync failures do not block the UI
      }
    });
  }

  /// Performs full sync: push (upload of unsynced local notes)
  /// and pull (download of remote notes not present locally).
  /// Returns the number of files that failed to decrypt (0 if none).
  /// If [force] is true, ignores the rate-limit guard.
  /// [requestPassphrase] is called when a remote note cannot be
  /// decrypted; should return the passphrase to try or null to ignore.
  /// [confirmDeleteRemote] is called after two failures; returns true to
  /// delete the remote file.
  Future<int> performSync({
    bool force = false,
    Future<String?> Function(String remoteFileId)? requestPassphrase,
    Future<bool> Function(String remoteFileId)? confirmDeleteRemote,
  }) async {
    final storage = _storage;
    if (storage == null || !storage.isConfigured) return 0;

    // Rate-limit guard (ignored if force=true)
    if (!force && !storage.syncAllowed) return 0;

    // Reload memo list from DB to ensure we have the latest data
    // (including notes marked as not synced via UPDATE)
    // Use a direct query to ensure we get the latest data
    _memos =
        await (_db.select(_db.memos)..orderBy([
              (t) => OrderingTerm(
                expression: t.updatedAt,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();
    final localMemos = List<Memo>.from(_memos);
    int decryptionFailures = 0;

    debugPrint(
      '[MemoProvider] performSync(): ${localMemos.length} total notes, encryption=${storage.encryptionEnabled}',
    );
    for (var memo in localMemos) {
      debugPrint(
        '[MemoProvider] Memo: ${memo.uuid} isSynced=${memo.isSynced}, remoteFileId=${memo.remoteFileId}, colorIndex=${memo.colorIndex}, bgImageIndex=${memo.bgImageIndex}',
      );
    }

    // ---------------------------------------------------------------
    // PUSH: send unsynced local notes and associate remoteFileId
    // ---------------------------------------------------------------
    final unsynced = localMemos.where((m) => !m.isSynced).toList();
    debugPrint(
      '[MemoProvider] performSync(): ${unsynced.length} unsynced notes for upload',
    );
    for (var memo in unsynced) {
      try {
        debugPrint(
          '[MemoProvider] Push: ${memo.uuid} (isSynced=${memo.isSynced}, remoteFileId=${memo.remoteFileId}, colorIndex=${memo.colorIndex}, encryption=${storage.encryptionEnabled})',
        );
        final blocks = await _db.getBlocksForMemo(memo.uuid);
        final remoteId = await storage.uploadMemo(memo, blocks);
        final updated = memo.copyWith(
          isSynced: true,
          remoteFileId: Value(remoteId ?? memo.remoteFileId),
        );
        await _db.saveMemoWithBlocks(updated, blocks);
        if (remoteId != null) {
          debugPrint(
            '[MemoProvider] Push OK: ${memo.uuid} → kDrive id $remoteId',
          );
        }
      } catch (e) {
        debugPrint('[MemoProvider] Push failed for ${memo.uuid}: $e');
      }
    }

    // ---------------------------------------------------------------
    // PULL: download remote notes not present locally
    // ---------------------------------------------------------------
    // If encryption is enabled in storage but the passphrase was not loaded into EncryptionService,
    // we need to ask the user before attempting decryption
    if (storage.encryptionEnabled && !EncryptionService.instance.isEnabled) {
      throw Exception(
        'Encryption enabled but passphrase not configured. '
        'Enter the passphrase in sync settings before restoring notes.',
      );
    }

    try {
      final remoteMemos = await storage.listRemoteMemos();
      final localUuids = localMemos.map((m) => m.uuid).toSet();

      debugPrint(
        '[MemoProvider] performSync(): ${remoteMemos.length} remote notes found',
      );

      for (var remote in remoteMemos) {
        final memoUuid = remote.name.replaceAll('.json', '');
        if (localUuids.contains(memoUuid)) continue;

        try {
          RemoteMemo? remoteMemo = await storage.downloadMemo(
            remote.remoteFileId,
          );

          // If decryption failed, try with a passphrase requested from the user
          if (remoteMemo == null && requestPassphrase != null) {
            // Save general encryption state to restore later
            final wasEnabled = EncryptionService.instance.isEnabled;
            int attempts = 0;
            while (remoteMemo == null && attempts < 2) {
              attempts++;
              final pass = await requestPassphrase(remote.remoteFileId);
              if (pass == null || pass.isEmpty) break; // ignore
              EncryptionService.instance.enable(pass);
              remoteMemo = await storage.downloadMemo(remote.remoteFileId);
            }
            // Restore general encryption state
            if (wasEnabled) {
              final generalPass = await storage.getEncryptionPassphrase();
              if (generalPass != null && generalPass.isNotEmpty) {
                EncryptionService.instance.enable(generalPass);
              }
            } else {
              EncryptionService.instance.disable();
            }
          }

          if (remoteMemo == null) {
            // Two failures: ask whether to ignore or delete remote
            if (confirmDeleteRemote != null) {
              final delete = await confirmDeleteRemote(remote.remoteFileId);
              if (delete) {
                await storage.deleteMemo(remote.remoteFileId);
                debugPrint(
                  '[MemoProvider] Pull: remote note $memoUuid deleted',
                );
              }
            }
            decryptionFailures++;
            debugPrint(
              '[MemoProvider] Pull: failed to decrypt $memoUuid (${remote.remoteFileId})',
            );
            continue;
          }

          // Re-save according to general encryption configuration:
          // mark as not synced to re-upload with current configuration
          final patched = remoteMemo.memo.copyWith(isSynced: false);
          await _db.saveMemoWithBlocks(patched, remoteMemo.blocks);
          debugPrint(
            '[MemoProvider] Pull OK: $memoUuid downloaded from kDrive (colorIndex=${patched.colorIndex}, bgImageIndex=${patched.bgImageIndex})',
          );
        } catch (e) {
          debugPrint('[MemoProvider] error downloading memo $memoUuid: $e');
        }
      }
    } catch (e) {
      debugPrint('[MemoProvider] error listing remotes: $e');
    }

    storage.markSyncedNow();
    return decryptionFailures;
  }

  /// Forces sync of all notes (ignores isSynced state).
  /// Useful to re-upload all notes after changing passphrase or disabling encryption.
  Future<int> syncAll() async {
    final storage = _storage;
    if (storage == null || !storage.isConfigured) return 0;

    debugPrint(
      '[MemoProvider] syncAll(): starting re-sincronização of all the notes',
    );

    // Mark all notes as not synced using an explicit transaction
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE memos SET is_synced = 0, remote_file_id = NULL',
      );
    });
    debugPrint(
      '[MemoProvider] syncAll(): all notes marked as not synced and remoteFileId cleared',
    );

    // Reload memo list from DB to ensure we have the latest data
    _memos = await _db.watchAllMemos().first;
    final localMemos = List<Memo>.from(_memos);

    debugPrint(
      '[MemoProvider] syncAll(): ${localMemos.length} total notes for re-sync',
    );
    for (var memo in localMemos) {
      debugPrint(
        '[MemoProvider] syncAll(): note ${memo.uuid} isSynced=${memo.isSynced}, remoteFileId=${memo.remoteFileId}, colorIndex=${memo.colorIndex}',
      );
    }

    // Force performSync with force=true
    return await performSync(force: true);
  }

  Future<void> archiveMemo(String memoUuid) async {
    await _db.updateMemoArchiveStatus(memoUuid, true);
  }

  Future<void> archiveMultiple(List<String> uuids) async {
    for (var id in uuids) {
      await _db.updateMemoArchiveStatus(id, true);
    }
    _scheduleSync();
  }

  Future<void> archiveMemoStatus(String memoUuid, bool isArchived) async {
    await _db.updateMemoArchiveStatus(memoUuid, isArchived);
    _scheduleSync();
  }

  // Mark as deleted (send to trash)
  Future<void> softDeleteMultiple(List<String> uuids) async {
    for (var id in uuids) {
      final match = _memos.cast<Memo?>().firstWhere(
        (m) => m?.uuid == id,
        orElse: () => null,
      );
      if (match != null) {
        // Remove remotely if exists in kDrive
        if (match.remoteFileId != null &&
            _storage != null &&
            _storage.isConfigured) {
          try {
            await _storage.deleteMemo(match.remoteFileId!);
          } catch (_) {
            // Remote delete failure does not block local soft delete
          }
        }
        final blocks = await _db.getBlocksForMemo(match.uuid);
        await _db.saveMemoWithBlocks(match.copyWith(isDeleted: true), blocks);
      }
    }
    _scheduleSync();
  }

  // Restore from trash
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
    _scheduleSync();
  }

  // Permanently delete from database
  Future<void> deleteMultiplePermanent(List<String> uuids) async {
    for (var id in uuids) {
      final memo = _memos.firstWhere(
        (m) => m.uuid == id,
        orElse: () => throw StateError('Memo not found'),
      );
      if (memo.remoteFileId != null &&
          _storage != null &&
          _storage.isConfigured) {
        try {
          await _storage.deleteMemo(memo.remoteFileId!);
        } catch (_) {
          // Remote delete failure does not block local delete
        }
      }
      await _db.deleteMemoCascading(id);
    }
    _scheduleSync();
  }

  Future<void> deleteMultiple(List<String> uuids) async {
    await softDeleteMultiple(uuids);
  }

  Future<void> deleteMemo(String memoUuid) async {
    await softDeleteMultiple([memoUuid]);
  }

  /// Disables sync: marks all notes as not synced
  /// in all states (Drift, memory).
  Future<void> disableSync() async {
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE memos SET is_synced = 0, remote_file_id = NULL',
      );
    });
    // Reload memo list from DB to ensure we have the latest data
    _memos = await _db.watchAllMemos().first;
    debugPrint('[MemoProvider] disableSync(): all notes marked as not synced');
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
    _scheduleSync();
  }

  Future<String> _localizedCopySuffix() async {
    // Suffix used when duplicating a note, localized by saved language preference.
    const suffixes = <String, String>{
      'pt': '(Cópia)',
      'en': '(Copy)',
      'fr': '(Copie)',
      'de': '(Kopie)',
      'it': '(Copia)',
      'es': '(Copia)',
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('language_code') ?? 'en';
      return suffixes[code] ?? '(Copy)';
    } catch (_) {
      return '(Copy)';
    }
  }

  Future<void> duplicateMultiple(List<String> uuids) async {
    final now = DateTime.now();
    final copySuffix = await _localizedCopySuffix();
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
        title: memo.title.isNotEmpty
            ? '${memo.title} $copySuffix'
            : '',
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
    _scheduleSync();
  }
}
