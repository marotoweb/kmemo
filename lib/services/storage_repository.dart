// lib/services/storage_repository.dart

import '../database/database.dart';

/// Result of remote note listing.
class RemoteMemoInfo {
  final String remoteFileId;
  final String name;
  final DateTime updatedAt;

  RemoteMemoInfo({
    required this.remoteFileId,
    required this.name,
    required this.updatedAt,
  });
}

/// Complete note downloaded from remote storage.
class RemoteMemo {
  final Memo memo;
  final List<Block> blocks;

  RemoteMemo({required this.memo, required this.blocks});
}

/// Abstraction of remote note storage.
///
/// kMemo remains offline-first: the local SQLite is the source of truth.
/// The remote storage is used only for backup and sync, and may be unavailable.
/// This layer only mirrors changes to the remote destination (kDrive,
/// WebDAV, etc.) asynchronously, without blocking the UI.
abstract class StorageRepository {
  /// Initialize the repository (load saved configuration, etc.).
  Future<void> init();

  /// Indicate if the repository is configured and ready for sync.
  bool get isConfigured;

  /// Human-readable name of the storage type (e.g. "kDrive", "WebDAV").
  String get storageName;

  /// Guards used by the caller (MemoProvider) to throttle sync frequency.
  bool get syncAllowed => true;

  /// Marks the completed sync cycle (used for rate-limit throttling).
  void markSyncedNow() {}

  /// Uploads a note to remote storage and returns the remote id
  /// created (or null if unavailable).
  Future<String?> uploadMemo(Memo memo, List<Block> blocks);

  /// Removes a note from remote storage.
  Future<void> deleteMemo(String remoteFileId);

  /// Lists the notes available in remote storage.
  Future<List<RemoteMemoInfo>> listRemoteMemos();

  /// Downloads a complete note from remote storage.
  /// Returns null if the note cannot be decrypted (wrong passphrase or corrupted data).
  Future<RemoteMemo?> downloadMemo(String remoteFileId);

  /// Executes full sync (push + pull). Subclasses may override or ignore.
  Future<void> sync();
}
