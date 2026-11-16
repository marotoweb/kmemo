// lib/providers/memo_provider.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../models/home_sort.dart';
import '../services/storage_repository.dart';
import '../services/sync_merge.dart';
import '../services/encryption_service.dart';
import '../services/widget_service.dart';
import '../services/sync_debug_log.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoProvider extends ChangeNotifier {
  final AppDatabase _db;
  StorageRepository? _storage;
  List<Memo> _memos = [];
  bool _isLoading = true;
  final _uuid = const Uuid();
  Timer? _syncDebounce;
  Timer? _widgetDebounce;

  /// Cycle in progress, if any. Concurrent calls join it instead of planning
  /// a second time from the same state (see [performSync]).
  Future<int>? _activeSync;

  /// Set when the last attempt was refused because encryption is on but the
  /// passphrase is not loaded. The automatic sync swallows the error, so
  /// without this the notes would stay local with no visible sign.
  bool _syncBlockedNoPassphrase = false;
  bool get syncBlockedNoPassphrase => _syncBlockedNoPassphrase;

  /// Logs to the console in debug builds and to `sync.log` in every build.
  void _syncLog(String message) {
    debugPrint(message);
    SyncDebugLog.log(message);
  }

  /// Editing a note writes to the database on every keystroke, and each write
  /// used to rebuild the whole widget payload. The widget is only visible when
  /// the app is in the background, so the rebuild waits for a short pause
  /// instead of running once per keystroke.
  static const Duration _widgetDebounceDelay = Duration(milliseconds: 300);

  // Preview cache: blocks grouped by memo uuid, warmed on every memo-list
  // change so cards can render synchronously instead of querying SQLite on
  // each build (which caused jank and height jumps while scrolling).
  final Map<String, List<Block>> _blocksByMemo = {};

  // Home ordering preferences (persisted in SharedPreferences).
  HomeSortMode _sortMode = HomeSortMode.updated;
  bool _sortAscending = false;

  /// Number of notes uploaded or downloaded during the last sync.
  int lastSyncNoteCount = 0;

  /// Remote notes the last sync could not read (missing passphrase, wrong
  /// passphrase or a corrupted file).
  ///
  /// A background sync cannot ask for the passphrase, so without this the note
  /// would stay out of sync without the user ever knowing. The home screen
  /// shows a warning while this is greater than zero.
  int _undecryptableNotes = 0;
  int get undecryptableNotes => _undecryptableNotes;

  MemoProvider(this._db, {StorageRepository? storage}) : _storage = storage {
    _loadSortPreferences();
    _listenToMemos();
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _widgetDebounce?.cancel();
    super.dispose();
  }

  List<Memo> get memos => _memos;

  /// Backend used by the next sync (kDrive or WebDAV).
  StorageRepository? get storage => _storage;

  /// Switches the sync backend at runtime, after the user configures it.
  void useStorage(StorageRepository? storage) {
    _storage = storage;
    debugPrint(
      '[MemoProvider] useStorage(): ${storage?.storageName ?? 'none'} '
      '(configured=${storage?.isConfigured})',
    );
  }

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
    final now = DateTime.now().toUtc();
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
    // Local changes mark the note as not synced (needs upload). The remote
    // bookkeeping is deliberately not written here: `saveMemoWithBlocks` keeps
    // the stored values, so an edit can never roll back what a sync cycle
    // recorded while the editor was open (that produced conflict copies of our
    // own uploads).
    final List<Block> updatedBlocksList = List.from(blocks);

    await _db.transaction(() async {
      final updatedMemo = memo.copyWith(
        updatedAt: DateTime.now().toUtc(),
        isSynced: false,
      );

      await _db.saveMemoRow(updatedMemo);

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

  /// Schedules a widget rebuild 300 ms after the last change (coalesced).
  void _updateWidgetData() {
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(_widgetDebounceDelay, () {
      _widgetDebounce = null;
      _writeWidgetData();
    });
  }

  /// Rebuilds the widget payload immediately: used when the app is resumed and
  /// when editor/theme options change, where the delay would be visible.
  Future<void> refreshWidget() async {
    _widgetDebounce?.cancel();
    _widgetDebounce = null;
    await _writeWidgetData();
  }

  Future<void> _writeWidgetData() async {
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

  /// Schedules remote sync with debounce (avoids calling the API on every keystroke).
  void _scheduleSync() {
    final storage = _storage;
    if (storage == null || !storage.isConfigured) return;
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
  ///
  /// A call that arrives while a cycle is running joins it instead of starting
  /// a second one: two cycles plan from the same state, so both see the same
  /// remote edit and each creates its own conflict copy (editing a note while
  /// a slow sync was running produced several copies of the same version).
  /// A manual call (`force`) is never dropped: it waits for the running cycle
  /// and then runs on its own.
  Future<int> performSync({
    bool force = false,
    void Function(int done, int total)? onProgress,
    Future<String?> Function(String remoteFileId)? requestPassphrase,
    Future<bool> Function(String remoteFileId)? confirmDeleteRemote,
  }) {
    final running = _activeSync;
    if (running != null) {
      // A manual "sync now" asks for a full pass and cannot be swallowed by a
      // cycle that is already planning from an older state, so it waits for
      // it and then runs on its own. An automatic call just joins: a second
      // plan from the same state is exactly what created duplicate copies.
      if (!force) {
        debugPrint(
          '[MemoProvider] performSync(): joining the cycle in progress',
        );
        return running;
      }
      debugPrint(
        '[MemoProvider] performSync(): queued after the cycle in progress',
      );
      return running.then(
        (_) => performSync(
          force: true,
          onProgress: onProgress,
          requestPassphrase: requestPassphrase,
          confirmDeleteRemote: confirmDeleteRemote,
        ),
      );
    }
    late final Future<int> cycle;
    cycle = _performSyncOnce(
      force: force,
      onProgress: onProgress,
      requestPassphrase: requestPassphrase,
      confirmDeleteRemote: confirmDeleteRemote,
    ).whenComplete(() {
      if (identical(_activeSync, cycle)) _activeSync = null;
    });
    _activeSync = cycle;
    return cycle;
  }

  Future<int> _performSyncOnce({
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
      _syncLog(
        '[MemoProvider] sync refused: encryption is on but no passphrase is '
        'loaded',
      );
      if (!_syncBlockedNoPassphrase) {
        _syncBlockedNoPassphrase = true;
        notifyListeners();
      }
      throw StateError(
        'Encryption enabled but passphrase not configured. '
        'Enter the passphrase in sync settings before syncing.',
      );
    }
    if (_syncBlockedNoPassphrase) {
      _syncBlockedNoPassphrase = false;
      notifyListeners();
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
    // Permanent deletions are remembered in their own table, because the memo
    // row is gone. If a row still exists for a tombstoned uuid (a restored
    // database, a backup copied back), it is dropped here instead of being
    // uploaded again: the user deleted it on purpose.
    final tombstones = await _db.getTombstones();
    final tombstonedUuids = tombstones.map((t) => t.uuid).toSet();
    for (final memo in _memos) {
      if (tombstonedUuids.contains(memo.uuid)) {
        await _db.deleteMemoCascading(memo.uuid);
      }
    }
    final localMemos = _memos
        .where((m) => !tombstonedUuids.contains(m.uuid))
        .toList();
    int decryptionFailures = 0;
    // Counts the notes this cycle touched, not the operations: a first sync
    // that downloads 56 notes and re-encodes them used to report 112, which
    // reads as if the library had doubled.
    final touched = <String>{};

    _syncLog(
      '[MemoProvider] sync start: ${localMemos.length} notes, '
      'encryption=${storage.encryptionEnabled}, '
      'passphrase=${EncryptionService.instance.isEnabled ? 'loaded' : 'missing'}',
    );
    for (var memo in localMemos) {
      debugPrint(
        '[MemoProvider] Memo: ${memo.uuid} isSynced=${memo.isSynced}, remoteFileId=${memo.remoteFileId}, colorIndex=${memo.colorIndex}, bgImageIndex=${memo.bgImageIndex}',
      );
    }

    // ---------------------------------------------------------------
    // PLAN: list the remote folder and decide, per note, what changed.
    //
    // The remote storage is a plain folder of JSON files, so the merge rule
    // lives on the client (see sync_merge.dart). A note is dirty when it was
    // edited locally since the last upload; the remote is dirty when its
    // payload timestamp differs from the one recorded at the last sync. The
    // remote file's modified time avoids downloading a note that did not
    // change.
    // ---------------------------------------------------------------
    final remoteByName = <String, RemoteMemoInfo>{};
    var listingOk = false;
    try {
      final remoteMemos = await storage.listRemoteMemos();
      for (final remote in remoteMemos) {
        remoteByName[remote.name.replaceAll('.json', '')] = remote;
      }
      listingOk = true;
    } catch (e) {
      _syncLog('[MemoProvider] error listing remotes: $e');
    }

    final localUuids = localMemos.map((m) => m.uuid).toSet();
    final remoteOnly = listingOk
        ? remoteByName.values
              .where(
                (r) =>
                    !localUuids.contains(r.name.replaceAll('.json', '')) &&
                    !tombstonedUuids.contains(r.name.replaceAll('.json', '')),
              )
              .toList()
        : <RemoteMemoInfo>[];

    // A permanent deletion is published as a tombstone in the note's own file.
    // It is written again when something put a note back at that path (an old
    // client re-uploading the version it still held), so the deletion wins
    // instead of the note coming back on every sync.
    final toPublish = <SyncTombstone>[];
    if (listingOk) {
      for (final tombstone in tombstones) {
        final remote = remoteByName[tombstone.uuid];
        if (remote == null) continue;
        if (!tombstone.isUploaded ||
            !sameRemoteInstant(tombstone.remoteRevision, remote.updatedAt)) {
          toPublish.add(tombstone);
        }
      }
    }

    final toUpload = <Memo>[];
    final toInspect = <Memo>[];
    for (final memo in localMemos) {
      final remote = remoteByName[memo.uuid];
      if (remote == null) {
        // No remote copy: the note was never uploaded, or another device
        // removed it. Uploading keeps the user's note in the backup.
        if (listingOk || !memo.isSynced) toUpload.add(memo);
        continue;
      }
      if (memo.remoteUpdatedAt == null) {
        // Unknown remote state (a newly selected backend, or a database that
        // predates the bookkeeping): the local library wins and replaces the
        // stale remote copy. No conflict copy is created, because the remote
        // side cannot be shown to be newer.
        toUpload.add(memo);
        continue;
      }
      if (memo.remoteRevision != null &&
          sameRemoteInstant(memo.remoteRevision, remote.updatedAt)) {
        // The remote file did not change since the last sync.
        if (!memo.isSynced) toUpload.add(memo);
        continue;
      }
      // The remote file changed, or its revision is still unknown (a note
      // migrated from an older database): the payload must be read to tell a
      // real edit from a re-upload of the same content.
      toInspect.add(memo);
    }

    final total =
        toUpload.length +
        toInspect.length +
        remoteOnly.length +
        toPublish.length;
    var processed = 0;
    void reportProgress() {
      onProgress?.call(processed > total ? total : processed, total);
    }

    reportProgress();

    // ---------------------------------------------------------------
    // DOWNLOAD / INSPECT: bring remote edits in and detect conflicts.
    // Downloads run before uploads so a conflict copy is uploaded in the
    // same cycle.
    // ---------------------------------------------------------------
    final session = _PassphraseSession(await storage.getEncryptionPassphrase());
    final justUploaded = <String>{};
    final publishedTombstones = <String>{};
    var nextSortIndex = nextTopSortIndex();

    for (final tombstone in toPublish) {
      processed++;
      reportProgress();
      try {
        final remoteId = await storage.uploadTombstone(
          tombstone.uuid,
          tombstone.deletedAt,
          remoteFileId: tombstone.remoteFileId,
        );
        await (_db.update(
          _db.syncTombstones,
        )..where((t) => t.uuid.equals(tombstone.uuid))).write(
          SyncTombstonesCompanion(
            isUploaded: const Value(true),
            remoteFileId: Value(remoteId ?? tombstone.remoteFileId),
            remoteRevision: const Value(null),
          ),
        );
        publishedTombstones.add(tombstone.uuid);
        touched.add(tombstone.uuid);
        _syncLog('[MemoProvider] Tombstone published: ${tombstone.uuid}');
      } catch (e) {
        _syncLog('[MemoProvider] Tombstone failed for ${tombstone.uuid}: $e');
      }
    }

    for (final memo in toInspect) {
      final remote = remoteByName[memo.uuid]!;
      processed++;
      reportProgress();
      try {
        final payload = await _downloadRemoteNote(
          storage,
          remote,
          session: session,
          requestPassphrase: requestPassphrase,
          confirmDeleteRemote: confirmDeleteRemote,
          onDecryptionFailure: () {
            decryptionFailures++;
            debugPrint(
              '[MemoProvider] Pull: failed to decrypt ${memo.uuid} '
              '(${remote.remoteFileId})',
            );
          },
        );
        if (payload == null) {
          // Never upload over a remote copy that could not be read: it may
          // hold an edit this device cannot see.
          continue;
        }

        if (payload.tombstone) {
          // Permanently deleted on another device: the note goes away here too,
          // and the tombstone is kept so that file is never downloaded again.
          await _db.recordTombstone(
            uuid: memo.uuid,
            deletedAt: payload.deletedAt ?? payload.memo.updatedAt,
            remoteFileId: remote.remoteFileId,
            remoteRevision: remote.updatedAt,
            isUploaded: true,
          );
          await _db.deleteMemoCascading(memo.uuid);
          touched.add(memo.uuid);
          _syncLog('[MemoProvider] Deleted on another device: ${memo.uuid}');
          continue;
        }

        final remoteDirty = !sameRemoteInstant(
          payload.memo.updatedAt,
          memo.remoteUpdatedAt,
        );
        final decision = decideSyncAction(
          localDirty: !memo.isSynced,
          remoteExists: true,
          remoteDirty: remoteDirty,
          localDeleted: memo.isDeleted,
          remoteDeleted: payload.memo.isDeleted,
        );

        switch (decision) {
          case SyncAction.none:
            await _setRemoteRevision(memo.uuid, remote.updatedAt);
            break;
          case SyncAction.upload:
            toUpload.add(memo);
            break;
          case SyncAction.download:
            final reupload = await _applyRemoteNote(
              storage,
              payload,
              remote: remote,
              sortIndex: memo.sortIndex,
            );
            if (reupload != null) toUpload.add(reupload);
            touched.add(memo.uuid);
            _syncLog(
              '[MemoProvider] Pull OK: ${memo.uuid} updated from '
              '${storage.storageName}',
            );
            break;
          case SyncAction.conflict:
            final copy = await _saveConflictCopy(
              payload,
              sortIndex: nextSortIndex--,
            );
            // The remote version is now stored as a separate note, so this
            // device has handled it: recording it prevents a second copy of
            // the same version if the upload below fails and a later cycle
            // inspects that payload again.
            await _setRemoteUpdatedAt(memo.uuid, payload.memo.updatedAt);
            // The local note stays canonical and is uploaded; the remote
            // version survives as a separate note.
            toUpload.add(memo);
            toUpload.add(copy);
            touched.add(memo.uuid);
            _syncLog(
              '[MemoProvider] Conflict on ${memo.uuid}: local kept, remote '
              'version saved as ${copy.uuid}',
            );
            break;
        }
      } catch (e) {
        debugPrint('[MemoProvider] error inspecting memo ${memo.uuid}: $e');
      }
    }

    // Remote notes this device has never seen.
    for (final remote in remoteOnly) {
      final memoUuid = remote.name.replaceAll('.json', '');
      processed++;
      reportProgress();
      try {
        final payload = await _downloadRemoteNote(
          storage,
          remote,
          session: session,
          requestPassphrase: requestPassphrase,
          confirmDeleteRemote: confirmDeleteRemote,
          onDecryptionFailure: () {
            decryptionFailures++;
            debugPrint(
              '[MemoProvider] Pull: failed to decrypt $memoUuid '
              '(${remote.remoteFileId})',
            );
          },
        );
        if (payload == null) continue;

        if (payload.tombstone) {
          // A note this device never had was deleted for good elsewhere. The
          // tombstone is stored so the file is not downloaded if it reappears.
          await _db.recordTombstone(
            uuid: memoUuid,
            deletedAt: payload.deletedAt ?? payload.memo.updatedAt,
            remoteFileId: remote.remoteFileId,
            remoteRevision: remote.updatedAt,
            isUploaded: true,
          );
          _syncLog('[MemoProvider] Tombstone noted: $memoUuid');
          continue;
        }

        final reupload = await _applyRemoteNote(
          storage,
          payload,
          remote: remote,
          sortIndex: nextSortIndex--,
        );
        if (reupload != null) toUpload.add(reupload);
        touched.add(memoUuid);
        _syncLog(
          '[MemoProvider] Pull OK: $memoUuid downloaded from '
          '${storage.storageName}',
        );
      } catch (e) {
        _syncLog('[MemoProvider] error downloading memo $memoUuid: $e');
      }
    }

    // ---------------------------------------------------------------
    // PUSH: upload local changes and the conflict copies.
    // ---------------------------------------------------------------
    _syncLog(
      '[MemoProvider] plan: ${toUpload.length} upload, '
      '${toInspect.length} inspect, ${remoteOnly.length} remote-only, '
      '${toPublish.length} tombstones',
    );
    for (final memo in toUpload) {
      processed++;
      reportProgress();
      try {
        debugPrint(
          '[MemoProvider] Push: ${memo.uuid} (isSynced=${memo.isSynced}, '
          'remoteFileId=${memo.remoteFileId}, '
          'encryption=${storage.encryptionEnabled})',
        );
        final blocks = await _db.getBlocksForMemo(memo.uuid);
        final remoteId = await storage.uploadMemo(memo, blocks);

        // Record the payload that was just written even if the note changed
        // during the upload, so the next sync does not mistake our own upload
        // for a remote edit.
        await (_db.update(
          _db.memos,
        )..where((t) => t.uuid.equals(memo.uuid))).write(
          MemosCompanion(
            remoteFileId: Value(remoteId ?? memo.remoteFileId),
            remoteUpdatedAt: Value(memo.updatedAt),
            remoteRevision: const Value(null),
          ),
        );
        // Clear the dirty flag only when the note did not change while it was
        // uploading; otherwise the newer edit would never be uploaded.
        await (_db.update(_db.memos)..where(
              (t) =>
                  t.uuid.equals(memo.uuid) &
                  t.updatedAt.equals(memo.updatedAt) &
                  t.isSynced.equals(false),
            ))
            .write(const MemosCompanion(isSynced: Value(true)));
        justUploaded.add(memo.uuid);
        touched.add(memo.uuid);
      } catch (e) {
        _syncLog('[MemoProvider] Push failed for ${memo.uuid}: $e');
      }
    }

    // The upload changed the remote file's modified time, which the server
    // reports only in a listing. One extra listing records it, so the next
    // sync does not re-download our own upload.
    if (justUploaded.isNotEmpty || publishedTombstones.isNotEmpty) {
      try {
        final after = await storage.listRemoteMemos();
        final byUuid = {
          for (final remote in after)
            remote.name.replaceAll('.json', ''): remote,
        };
        await _db.batch((batch) {
          for (final uuid in justUploaded) {
            final remote = byUuid[uuid];
            if (remote == null) continue;
            batch.update(
              _db.memos,
              MemosCompanion(remoteRevision: Value(remote.updatedAt)),
              where: (t) => t.uuid.equals(uuid),
            );
          }
          for (final uuid in publishedTombstones) {
            final remote = byUuid[uuid];
            if (remote == null) continue;
            batch.update(
              _db.syncTombstones,
              SyncTombstonesCompanion(remoteRevision: Value(remote.updatedAt)),
              where: (t) => t.uuid.equals(uuid),
            );
          }
        });
      } catch (e) {
        _syncLog('[MemoProvider] error refreshing remote revisions: $e');
      }
    }

    // Remember the failures so the home screen can warn the user: an automatic
    // sync cannot ask for the passphrase, and until it is fixed those notes
    // stay out of sync without any visible sign.
    if (_undecryptableNotes != decryptionFailures) {
      _undecryptableNotes = decryptionFailures;
      notifyListeners();
    }

    onProgress?.call(total, total);
    storage.markSyncedNow();
    lastSyncNoteCount = touched.length;
    _syncLog(
      '[MemoProvider] sync done: ${touched.length} notes touched, '
      '$decryptionFailures unreadable',
    );
    return decryptionFailures;
  }

  /// Downloads [remote], asking for a passphrase when the note cannot be read.
  ///
  /// Returns null when the note could not be decrypted, after offering to
  /// delete the remote file. [onDecryptionFailure] is called once per failure.
  Future<RemoteMemo?> _downloadRemoteNote(
    StorageRepository storage,
    RemoteMemoInfo remote, {
    required _PassphraseSession session,
    required Future<String?> Function(String remoteFileId)? requestPassphrase,
    required Future<bool> Function(String remoteFileId)? confirmDeleteRemote,
    required void Function() onDecryptionFailure,
  }) async {
    RemoteMemo? remoteMemo = await storage.downloadMemo(remote.remoteFileId);

    // If decryption failed, try the passphrase that already worked for a
    // previous note before asking the user again.
    if (remoteMemo == null && requestPassphrase != null) {
      final wasEnabled = EncryptionService.instance.isEnabled;

      if (session.userPassphrase != null &&
          session.userPassphrase!.isNotEmpty) {
        EncryptionService.instance.enable(session.userPassphrase!);
        remoteMemo = await storage.downloadMemo(remote.remoteFileId);
      }

      var attempts = 0;
      while (remoteMemo == null && attempts < 2) {
        attempts++;
        final pass = await requestPassphrase(remote.remoteFileId);
        if (pass == null || pass.isEmpty) break; // ignore
        EncryptionService.instance.enable(pass);
        remoteMemo = await storage.downloadMemo(remote.remoteFileId);
        if (remoteMemo != null && pass != session.userPassphrase) {
          session.userPassphrase = pass;
          await _adoptRemoteEncryption(storage, pass);
        }
      }

      // Restore the state the cycle had before the prompt, but keep the
      // passphrase that just decrypted a note when this backend writes
      // encrypted notes: dropping it (the old behaviour) made the push below
      // impossible, so the note stayed on this device forever.
      if (storage.encryptionEnabled && session.userPassphrase != null) {
        EncryptionService.instance.enable(session.userPassphrase!);
      } else if (wasEnabled) {
        final generalPass = session.generalPass;
        if (generalPass != null && generalPass.isNotEmpty) {
          EncryptionService.instance.enable(generalPass);
        }
      } else {
        EncryptionService.instance.disable();
      }
    }

    if (remoteMemo == null) {
      onDecryptionFailure();
      if (confirmDeleteRemote != null) {
        final delete = await confirmDeleteRemote(remote.remoteFileId);
        if (delete) {
          await storage.deleteMemo(remote.remoteFileId);
          debugPrint('[MemoProvider] Pull: remote note ${remote.name} deleted');
        }
      }
    }
    return remoteMemo;
  }

  /// Saves a downloaded note locally, replacing the local content.
  ///
  /// Returns the note when it must be uploaded again, because the remote copy
  /// was written with a different encryption setting; returns null otherwise.
  /// Without this check a plain download would create a new version of the
  /// same note on every sync.
  Future<Memo?> _applyRemoteNote(
    StorageRepository storage,
    RemoteMemo payload, {
    required RemoteMemoInfo remote,
    required int sortIndex,
  }) async {
    // Only a plain remote copy is rewritten, when encryption is on now (the
    // user enabled it after the notes were uploaded). The opposite case — an
    // encrypted remote copy while this device has encryption off — is not a
    // re-encode: it is an encrypted folder that this device just met, and
    // rewriting it would publish every note in plain text. _adoptRemoteEncryption
    // turns encryption on instead, so that case no longer reaches this line.
    final needsReencode = storage.encryptionEnabled && !payload.wasEncrypted;
    final patched = payload.memo.copyWith(
      isSynced: !needsReencode,
      sortIndex: sortIndex,
      remoteFileId: Value(remote.remoteFileId),
      remoteUpdatedAt: Value(payload.memo.updatedAt),
      remoteRevision: Value(remote.updatedAt),
    );
    await _db.saveMemoWithBlocks(
      patched,
      payload.blocks,
      replaceBlocks: true,
      writeSyncBookkeeping: true,
    );
    return needsReencode ? patched : null;
  }

  /// Turns encryption on because the remote folder holds encrypted notes.
  ///
  /// Rewriting those notes with the encryption off would publish the user's
  /// notes in plain text; the passphrase that just decrypted one of them is the
  /// folder's, so it becomes this backend's passphrase and the remote files are
  /// left as they are.
  Future<void> _adoptRemoteEncryption(
    StorageRepository storage,
    String passphrase,
  ) async {
    if (storage.encryptionEnabled) return;
    final stored = await storage.adoptEncryption(passphrase);
    _syncLog(
      '[MemoProvider] encryption adopted: the remote notes are encrypted '
      '(passphrase ${stored ? 'stored' : 'NOT stored'})',
    );
  }

  /// Stores the remote version of a conflicting note as a separate note.
  ///
  /// The local note stays canonical (same uuid, same remote file); the copy
  /// gets a new uuid, no remote id and no sync bookkeeping, so it is uploaded
  /// as a new note and can never delete the original remote file.
  Future<Memo> _saveConflictCopy(
    RemoteMemo payload, {
    required int sortIndex,
  }) async {
    final now = DateTime.now().toUtc();
    final suffix = await _localizedConflictSuffix();
    final title = payload.memo.title.trim();
    final copy = payload.memo.copyWith(
      uuid: _uuid.v4(),
      title: title.isEmpty ? suffix : '$title $suffix',
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      // The copy is a new note: it must not inherit the remote file of the
      // original (deleting the copy would delete the original's remote file),
      // the sync bookkeeping, or the pinned state (it lands at the top of the
      // non-pinned section instead of reordering the pinned ones).
      isPinned: false,
      sortIndex: sortIndex,
      remoteFileId: const Value(null),
      remoteUpdatedAt: const Value(null),
      remoteRevision: const Value(null),
    );
    final blocks = payload.blocks
        .map(
          (b) => Block(
            id: 0,
            uuid: _uuid.v4(),
            memoUuid: copy.uuid,
            type: b.type,
            content: b.content,
            sortOrder: b.sortOrder,
            isDeleted: b.isDeleted,
          ),
        )
        .toList();
    await _db.saveMemoWithBlocks(copy, blocks);
    return copy;
  }

  /// Records the remote file's modified time for [uuid], so the next sync can
  /// skip a note that did not change without downloading it.
  Future<void> _setRemoteRevision(String uuid, DateTime revision) async {
    await (_db.update(_db.memos)..where((t) => t.uuid.equals(uuid))).write(
      MemosCompanion(remoteRevision: Value(revision)),
    );
  }

  /// Records the remote payload timestamp this device last handled for [uuid].
  ///
  /// Set right after a conflict copy is stored: the remote version has been
  /// accounted for, so a later cycle that inspects the same payload must not
  /// save another copy of it.
  Future<void> _setRemoteUpdatedAt(String uuid, DateTime value) async {
    await (_db.update(_db.memos)..where((t) => t.uuid.equals(uuid))).write(
      MemosCompanion(remoteUpdatedAt: Value(value)),
    );
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
    final deletedAt = DateTime.now().toUtc();
    for (final id in uuids) {
      final cached = _memos.cast<Memo?>().firstWhere(
        (m) => m?.uuid == id,
        orElse: () => null,
      );
      // Fall back to the database so a note that is no longer in memory can
      // still be permanently removed instead of throwing.
      final memo =
          cached ??
          await (_db.select(
            _db.memos,
          )..where((t) => t.uuid.equals(id))).getSingleOrNull();
      // Removing the remote file would be invisible to every other device,
      // which would then see "no remote copy" and upload the note back. The
      // deletion is published as a tombstone under the same file name instead
      // (see SyncTombstones), so every device can delete the note too.
      if (memo?.remoteFileId != null) {
        await _db.recordTombstone(
          uuid: id,
          deletedAt: deletedAt,
          remoteFileId: memo!.remoteFileId,
        );
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

  /// Disables sync: marks all notes as not synced in all states (Drift,
  /// memory) and forgets the remote bookkeeping.
  ///
  /// Called when sync is turned off and when the user switches to a different
  /// backend. The new backend has no copies yet (or may have stale ones), so
  /// every note must be uploaded again. `remoteUpdatedAt` and `remoteRevision`
  /// describe the previous backend and must never be compared with the new
  /// one: clearing them makes the next sync treat the remote state as unknown
  /// and let the local library win.
  Future<void> disableSync() async {
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE memos SET is_synced = 0, remote_file_id = NULL, '
        'remote_updated_at = NULL, remote_revision = NULL',
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

    // The colour is part of the remote payload: mark the note as not synced and
    // refresh `updatedAt`, which is how the other device learns the payload
    // changed (see setPinnedMultiple).
    final now = DateTime.now().toUtc();
    for (var memo in targets) {
      final blocks = await _db.getBlocksForMemo(memo.uuid);
      // Selecting a color also clears any selected background image, matching
      // the editor: the color becomes visible and the image is removed.
      await _db.saveMemoWithBlocks(
        memo.copyWith(
          colorIndex: colorIndex,
          bgImageIndex: -1,
          updatedAt: now,
          isSynced: false,
        ),
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

    final now = DateTime.now().toUtc();
    for (var memo in targets) {
      final blocks = await _db.getBlocksForMemo(memo.uuid);
      await _db.saveMemoWithBlocks(
        memo.copyWith(
          bgImageIndex: bgImageIndex,
          updatedAt: now,
          isSynced: false,
        ),
        blocks,
      );
    }
    _scheduleSync();
  }

  /// Pins or unpins several notes. Pinning is synced across devices, so the
  /// note is marked as not synced and its [Memo.updatedAt] is refreshed.
  Future<void> setPinnedMultiple(List<String> uuids, bool pinned) async {
    final now = DateTime.now().toUtc();
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

  /// Suffix used when duplicating a note or when saving a conflict copy,
  /// localized by the saved language preference (the provider has no context).
  static const Map<String, String> _copySuffixes = {
    'pt': '(Cópia)',
    'en': '(Copy)',
    'fr': '(Copie)',
    'de': '(Kopie)',
    'it': '(Copia)',
    'es': '(Copia)',
  };

  static const Map<String, String> _conflictSuffixes = {
    'pt': '(Conflito)',
    'en': '(Conflict)',
    'fr': '(Conflit)',
    'de': '(Konflikt)',
    'it': '(Conflitto)',
    'es': '(Conflicto)',
  };

  Future<String> _localizedSuffix(Map<String, String> suffixes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('language_code');
      if (code != null && code.isNotEmpty) {
        return suffixes[code] ?? suffixes['en']!;
      }
    } catch (_) {
      // Fall through to the system language.
    }
    // No language was chosen, so the app follows the system language: the
    // suffix must follow it too. It used to fall back to English, which gave a
    // Portuguese screen notes titled "(Conflict)".
    final system = WidgetsBinding.instance.platformDispatcher.locale;
    return suffixes[system.languageCode] ?? suffixes['en']!;
  }

  Future<String> _localizedCopySuffix() => _localizedSuffix(_copySuffixes);

  Future<String> _localizedConflictSuffix() =>
      _localizedSuffix(_conflictSuffixes);

  Future<void> duplicateMultiple(List<String> uuids) async {
    final now = DateTime.now().toUtc();
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
        // The copy is a new note: it must not inherit the remote file of the
        // original (deleting the copy would delete the original's remote
        // file) nor the sync bookkeeping.
        remoteFileId: const Value(null),
        remoteUpdatedAt: const Value(null),
        remoteRevision: const Value(null),
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

/// Passphrase that worked during one sync, reused for the remaining notes so
/// the user is not asked once per encrypted note.
class _PassphraseSession {
  final String? generalPass;
  String? userPassphrase;

  _PassphraseSession(this.generalPass);
}
