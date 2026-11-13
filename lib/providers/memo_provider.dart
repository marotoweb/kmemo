// lib/providers/memo_provider.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../models/home_sort.dart';
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

  // Preview cache: blocks grouped by memo uuid, warmed on every memo-list
  // change so cards can render synchronously instead of querying SQLite on
  // each build (which caused jank and height jumps while scrolling).
  final Map<String, List<Block>> _blocksByMemo = {};

  // Home ordering preferences (persisted in SharedPreferences).
  HomeSortMode _sortMode = HomeSortMode.updated;
  bool _sortAscending = false;

  /// Number of notes uploaded or downloaded during the last sync.
  int lastSyncNoteCount = 0;

  MemoProvider(this._db, {KDriveStorage? storage}) : _storage = storage {
    _loadSortPreferences();
    _listenToMemos();
  }

  List<Memo> get memos => _memos;

  HomeSortMode get sortMode => _sortMode;
  bool get sortAscending => _sortAscending;

  List<Memo> get activeMemos => _sortedActive(_memos);
  List<Memo> get archivedMemos =>
      _memos.where((m) => m.isArchived && !m.isDeleted).toList();
  List<Memo> get deletedMemos => _memos.where((m) => m.isDeleted).toList();

  bool get isLoading => _isLoading;

  List<Memo> _sortedActive(List<Memo> source) {
    final list = source
        .where((m) => !m.isArchived && !m.isDeleted)
        .toList(growable: false);
    final sorted = List<Memo>.from(list);
    sorted.sort((a, b) => compareMemosForSort(a, b, _sortMode, _sortAscending));
    return sorted;
  }

  Future<void> _loadSortPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sortMode = homeSortModeFromName(prefs.getString(kHomeSortModeKey));
      _sortAscending = prefs.getBool(kHomeSortAscendingKey) ?? false;
      notifyListeners();
      _updateWidgetData();
    } catch (_) {
      // Keep the defaults if preferences cannot be read.
    }
  }

  /// Changes the home sort mode and persists it. Switching to
  /// [HomeSortMode.custom] for the first time seeds [Memo.sortIndex] from the
  /// order currently on screen, so nothing jumps around.
  Future<void> setSortMode(HomeSortMode mode) async {
    if (mode == _sortMode) return;
    if (mode == HomeSortMode.custom) {
      await _ensureCustomOrderInitialized();
    }
    _sortMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kHomeSortModeKey, mode.name);
    _updateWidgetData();
  }

  Future<void> setSortAscending(bool value) async {
    if (value == _sortAscending) return;
    _sortAscending = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHomeSortAscendingKey, value);
    _updateWidgetData();
  }

  /// Seeds the manual order from the current display order, once.
  Future<void> _ensureCustomOrderInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    final initialized = prefs.getBool(kHomeCustomOrderInitializedKey) ?? false;
    if (initialized) return;

    // Order the notes the way they are displayed right now (previous mode).
    final ordered = _sortedActive(_memos).map((m) => m.uuid).toList();
    _applySortIndexes(ordered);
    await _writeSortIndexes(ordered);
    await prefs.setBool(kHomeCustomOrderInitializedKey, true);
  }

  /// Persists the manual order. [orderedUuids] must contain the full active
  /// list in its new display order (pinned notes first).
  Future<void> reorderActiveMemos(List<String> orderedUuids) async {
    // Optimistic in-memory update so the list does not snap back on drop.
    _applySortIndexes(orderedUuids);
    await _writeSortIndexes(orderedUuids);
  }

  void _applySortIndexes(List<String> orderedUuids) {
    final indexByUuid = <String, int>{};
    for (var i = 0; i < orderedUuids.length; i++) {
      indexByUuid[orderedUuids[i]] = i;
    }
    _memos = _memos
        .map(
          (m) => indexByUuid.containsKey(m.uuid)
              ? m.copyWith(sortIndex: indexByUuid[m.uuid])
              : m,
        )
        .toList();
    notifyListeners();
  }

  Future<void> _writeSortIndexes(List<String> orderedUuids) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedUuids.length; i++) {
        await (_db.update(_db.memos)
              ..where((t) => t.uuid.equals(orderedUuids[i])))
            .write(MemosCompanion(sortIndex: Value(i)));
      }
    });
  }

  /// Index that puts a new (or duplicated) note at the top of the non-pinned
  /// section.
  int nextTopSortIndex() {
    final active = _memos.where((m) => !m.isArchived && !m.isDeleted);
    final nonPinned = active.where((m) => !m.isPinned).toList();
    if (nonPinned.isNotEmpty) {
      var min = nonPinned.first.sortIndex;
      for (final memo in nonPinned) {
        if (memo.sortIndex < min) min = memo.sortIndex;
      }
      return min - 1;
    }
    final pinned = active.where((m) => m.isPinned).toList();
    if (pinned.isNotEmpty) {
      var max = pinned.first.sortIndex;
      for (final memo in pinned) {
        if (memo.sortIndex > max) max = memo.sortIndex;
      }
      return max + 1;
    }
    return 0;
  }

  /// Searches active notes by title and block content (case-insensitive).
  Future<List<Memo>> searchMemos(String query) async {
    final term = '%${query.toLowerCase()}%';
    final rows = await _db
        .customSelect(
          'SELECT * FROM memos WHERE is_archived = 0 AND is_deleted = 0 AND '
          '(LOWER(title) LIKE ?1 OR EXISTS ('
          'SELECT 1 FROM blocks WHERE blocks.memo_uuid = memos.uuid '
          'AND blocks.is_deleted = 0 AND LOWER(content) LIKE ?1))',
          variables: [Variable.withString(term)],
          readsFrom: {_db.memos, _db.blocks},
        )
        .get();
    final results = rows.map((row) => _db.memos.map(row.data)).toList();
    results.sort(
      (a, b) => compareMemosForSort(a, b, _sortMode, _sortAscending),
    );
    return results;
  }

  void _listenToMemos() {
    _db.watchAllMemos().listen(
      (listOfMemos) {
        _memos = listOfMemos;
        _isLoading = false;
        notifyListeners();
        _updateWidgetData();
        _refreshBlocksCache();
      },
      onError: (_) {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Rebuilds the block preview cache in a single query. Called whenever the
  /// memo list changes (add, edit, archive, delete, sync), never while the
  /// user is scrolling, so card builds stay synchronous.
  Future<void> _refreshBlocksCache() async {
    try {
      final blocks = await _db.getAllBlocks();
      final grouped = <String, List<Block>>{};
      for (final block in blocks) {
        grouped.putIfAbsent(block.memoUuid, () => []).add(block);
      }
      _blocksByMemo
        ..clear()
        ..addAll(grouped);
      notifyListeners();
    } catch (_) {
      // Keep the previous cache if the query fails.
    }
  }

  /// Blocks for [memoUuid] if already cached, or null when not loaded yet.
  List<Block>? cachedBlocksFor(String memoUuid) => _blocksByMemo[memoUuid];

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
      isPinned: false,
      sortIndex: nextTopSortIndex(),
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
    final cached = _blocksByMemo[memoUuid];
    if (cached != null) return cached;
    final blocks = await _db.getBlocksForMemo(memoUuid);
    _blocksByMemo[memoUuid] = blocks;
    return blocks;
  }

  Future<List<Block>> saveMemo(Memo memo, List<Block> blocks) async {
    // Local changes mark the note as not synced (needs upload)
    final List<Block> updatedBlocksList = List.from(blocks);

    await _db.transaction(() async {
      // The editor can hold a snapshot taken before the first upload finished
      // (a note created and edited while it was still syncing). Never drop the
      // remoteFileId already stored locally: without it the remote .json can
      // no longer be overwritten by id or deleted when the note is purged.
      var remoteFileId = memo.remoteFileId;
      if (remoteFileId == null || remoteFileId.isEmpty) {
        final stored = await (_db.select(
          _db.memos,
        )..where((t) => t.uuid.equals(memo.uuid))).getSingleOrNull();
        remoteFileId = stored?.remoteFileId;
      }
      final updatedMemo = memo.copyWith(
        updatedAt: DateTime.now(),
        isSynced: false,
        remoteFileId: Value(remoteFileId),
      );

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
    // Determine whether the dark theme is active
    bool isDark = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('theme_mode') ?? 0;
      if (themeIndex == 1) {
        isDark = false; // light
      } else if (themeIndex == 2) {
        isDark = true; // dark
      } else {
        // system - use the platform brightness
        isDark =
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
      }
    } catch (_) {
      isDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    await WidgetService.updateWidgetData(db: _db, isDark: isDark);
  }

  /// Refreshes the home screen widget after editor options change.
  Future<void> refreshWidget() async {
    await _updateWidgetData();
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
    void Function(int done, int total)? onProgress,
    Future<String?> Function(String remoteFileId)? requestPassphrase,
    Future<bool> Function(String remoteFileId)? confirmDeleteRemote,
  }) async {
    final storage = _storage;
    lastSyncNoteCount = 0;
    if (storage == null || !storage.isConfigured) return 0;

    // Encryption is configured but the passphrase is not loaded (secure
    // storage unreadable, wrong passphrase, or the app started before it was
    // loaded). Abort before the push: uploading now would write every note in
    // plain text. This used to be checked only before the pull, so a sync in
    // that state uploaded plain-text copies while blocking the download.
    if (storage.encryptionEnabled && !EncryptionService.instance.isEnabled) {
      throw StateError(
        'Encryption enabled but passphrase not configured. '
        'Enter the passphrase in sync settings before syncing.',
      );
    }

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
    int syncedCount = 0;

    debugPrint(
      '[MemoProvider] performSync(): ${localMemos.length} total notes, encryption=${storage.encryptionEnabled}',
    );
    for (var memo in localMemos) {
      debugPrint(
        '[MemoProvider] Memo: ${memo.uuid} isSynced=${memo.isSynced}, remoteFileId=${memo.remoteFileId}, colorIndex=${memo.colorIndex}, bgImageIndex=${memo.bgImageIndex}',
      );
    }

    // ---------------------------------------------------------------
    // Progress: total = notes to upload + remote notes to download.
    // Listing the remote folder first lets the UI show a determinate bar
    // even when every note is re-uploaded (e.g. after toggling encryption).
    // ---------------------------------------------------------------
    final unsynced = localMemos.where((m) => !m.isSynced).toList();
    List<RemoteMemoInfo> pendingRemote = [];
    try {
      final remoteMemos = await storage.listRemoteMemos();
      final localUuids = localMemos.map((m) => m.uuid).toSet();
      pendingRemote = remoteMemos
          .where((r) => !localUuids.contains(r.name.replaceAll('.json', '')))
          .toList();
    } catch (e) {
      debugPrint('[MemoProvider] error listing remotes: $e');
    }
    final total = unsynced.length + pendingRemote.length;
    int processed = 0;
    onProgress?.call(processed, total);

    // ---------------------------------------------------------------
    // PUSH: send unsynced local notes and associate remoteFileId
    // ---------------------------------------------------------------
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
        syncedCount++;
        if (remoteId != null) {
          debugPrint(
            '[MemoProvider] Push OK: ${memo.uuid} → kDrive id $remoteId',
          );
        }
      } catch (e) {
        debugPrint('[MemoProvider] Push failed for ${memo.uuid}: $e');
      }
      processed++;
      onProgress?.call(processed, total);
    }

    // ---------------------------------------------------------------
    // PULL: download remote notes not present locally
    // ---------------------------------------------------------------
    try {
      debugPrint(
        '[MemoProvider] performSync(): ${pendingRemote.length} remote notes to pull',
      );

      // The passphrase that successfully decrypted a note is reused for the
      // remaining notes, so the user is not asked once per encrypted note.
      String? userPassphrase;
      final generalPass = await storage.getEncryptionPassphrase();

      // New notes are placed at the top of the non-pinned section.
      var nextSortIndex = nextTopSortIndex();
      for (var remote in pendingRemote) {
        final memoUuid = remote.name.replaceAll('.json', '');
        processed++;
        onProgress?.call(processed, total);

        try {
          RemoteMemo? remoteMemo = await storage.downloadMemo(
            remote.remoteFileId,
          );

          // If decryption failed, try the passphrase that already worked for
          // a previous note before asking the user again.
          if (remoteMemo == null && requestPassphrase != null) {
            // Save general encryption state to restore later
            final wasEnabled = EncryptionService.instance.isEnabled;

            // 1. Reuse the passphrase validated for a previous note.
            if (userPassphrase != null && userPassphrase.isNotEmpty) {
              EncryptionService.instance.enable(userPassphrase);
              remoteMemo = await storage.downloadMemo(remote.remoteFileId);
            }

            // 2. Ask the user (up to two attempts) only if still undecrypted.
            int attempts = 0;
            while (remoteMemo == null && attempts < 2) {
              attempts++;
              final pass = await requestPassphrase(remote.remoteFileId);
              if (pass == null || pass.isEmpty) break; // ignore
              EncryptionService.instance.enable(pass);
              remoteMemo = await storage.downloadMemo(remote.remoteFileId);
              if (remoteMemo != null) {
                userPassphrase = pass;
              }
            }

            // Restore general encryption state
            if (wasEnabled) {
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
          final patched = remoteMemo.memo.copyWith(
            isSynced: false,
            sortIndex: nextSortIndex--,
          );
          await _db.saveMemoWithBlocks(patched, remoteMemo.blocks);
          syncedCount++;
          debugPrint(
            '[MemoProvider] Pull OK: $memoUuid downloaded from kDrive (colorIndex=${patched.colorIndex}, bgImageIndex=${patched.bgImageIndex})',
          );
        } catch (e) {
          debugPrint('[MemoProvider] error downloading memo $memoUuid: $e');
        }
      }
    } catch (e) {
      debugPrint('[MemoProvider] error pulling remotes: $e');
    }

    onProgress?.call(total, total);
    storage.markSyncedNow();
    lastSyncNoteCount = syncedCount;
    return decryptionFailures;
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
    debugPrint(
      '[MemoProvider] softDeleteMultiple: ${uuids.length} uuids: $uuids',
    );
    debugPrint('[MemoProvider] _memos count: ${_memos.length}');
    if (uuids.isEmpty) {
      debugPrint('[MemoProvider] softDeleteMultiple: nothing to delete');
      return;
    }
    for (var id in uuids) {
      final match = _memos.cast<Memo?>().firstWhere(
        (m) => m?.uuid == id,
        orElse: () => null,
      );
      if (match != null) {
        // Sending to the trash keeps the remote file: it is only deleted from
        // kDrive when the note is permanently removed (trash screen). The note
        // is marked as unsynced so the isDeleted flag is uploaded and other
        // devices pull it already flagged as being in the trash.
        final blocks = await _db.getBlocksForMemo(match.uuid);
        await _db.saveMemoWithBlocks(
          match.copyWith(isDeleted: true, isSynced: false),
          blocks,
        );
        debugPrint(
          '[MemoProvider] softDeleteMultiple: saved ${match.uuid} isDeleted=true',
        );
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
        // Restoring uploads the un-deleted state so the remote copy no longer
        // reports the note as being in the trash.
        final blocks = await _db.getBlocksForMemo(match.uuid);
        await _db.saveMemoWithBlocks(
          match.copyWith(isDeleted: false, isSynced: false),
          blocks,
        );
      }
    }
    _scheduleSync();
  }

  // Permanently delete from database
  Future<void> deleteMultiplePermanent(List<String> uuids) async {
    for (final id in uuids) {
      final cached = _memos.cast<Memo?>().firstWhere(
        (m) => m?.uuid == id,
        orElse: () => null,
      );
      // Fall back to the database so a note that is no longer in memory can
      // still be permanently removed instead of throwing.
      final memo =
          cached ??
          await (_db.select(_db.memos)..where((t) => t.uuid.equals(id)))
              .getSingleOrNull();
      // The kDrive file is deleted only here, when the note is permanently
      // removed from the trash.
      if (memo?.remoteFileId != null &&
          _storage != null &&
          _storage.isConfigured) {
        await _storage.deleteMemo(memo!.remoteFileId!);
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

  /// Rejects an empty note: permanently removes it from the database
  /// and shows feedback to the user. Used when a new note is created
  /// but left completely empty (no title, content, or attachments).
  Future<void> rejectEmptyMemo(String memoUuid) async {
    try {
      await deleteMultiplePermanent([memoUuid]);
    } catch (_) {
      // Memo may not be in _memos yet (stream not delivered); delete directly
      await _db.deleteMemoCascading(memoUuid);
    }
    _scheduleSync();
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
      // Selecting a color also clears any selected background image, matching
      // the editor: the color becomes visible and the image is removed.
      await _db.saveMemoWithBlocks(
        memo.copyWith(colorIndex: colorIndex, bgImageIndex: -1),
        blocks,
      );
    }
    _scheduleSync();
  }

  /// Applies a background image (asset index) to several notes at once.
  /// Mirrors [changeColorMultiple] for the background-image palette.
  Future<void> changeBgImageMultiple(
    List<String> uuids,
    int bgImageIndex,
  ) async {
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
        memo.copyWith(bgImageIndex: bgImageIndex),
        blocks,
      );
    }
    _scheduleSync();
  }

  /// Pins or unpins several notes. Pinning is synced across devices, so the
  /// note is marked as not synced and its [Memo.updatedAt] is refreshed.
  Future<void> setPinnedMultiple(List<String> uuids, bool pinned) async {
    final now = DateTime.now();
    for (final id in uuids) {
      var match = _memos.cast<Memo?>().firstWhere(
        (m) => m?.uuid == id,
        orElse: () => null,
      );
      // The note may not be in the stream yet (e.g. a brand-new note opened
      // from the editor); fall back to the database.
      match ??= await (_db.select(
        _db.memos,
      )..where((t) => t.uuid.equals(id))).getSingleOrNull();
      if (match == null) continue;
      final blocks = await _db.getBlocksForMemo(match.uuid);
      await _db.saveMemoWithBlocks(
        match.copyWith(isPinned: pinned, updatedAt: now, isSynced: false),
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
    var nextSortIndex = nextTopSortIndex();

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
        title: memo.title.isNotEmpty ? '${memo.title} $copySuffix' : '',
        createdAt: now,
        updatedAt: now,
        isSynced: false,
        isDeleted: false,
        isPinned: false,
        sortIndex: nextSortIndex--,
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
