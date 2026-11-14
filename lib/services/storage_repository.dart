// lib/services/storage_repository.dart

import '../database/database.dart';

/// SharedPreferences key holding the active sync backend ("kdrive" or
/// "webdav"). Read by main() to pick the storage injected into MemoProvider.
const String kSyncBackendKey = 'sync_backend';

/// Backend names accepted by [kSyncBackendKey].
const String kSyncBackendKDrive = 'kdrive';
const String kSyncBackendWebDav = 'webdav';

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

  /// Whether the notes must be encrypted before leaving the device.
  ///
  /// When this is true and [EncryptionService] has no passphrase loaded, the
  /// caller aborts the sync and every upload throws instead of writing a note
  /// in plain text.
  bool get encryptionEnabled => false;

  /// Passphrase stored by the backend, used to retry a note that failed to
  /// decrypt with the passphrase loaded at startup.
  Future<String?> getEncryptionPassphrase() async => null;

  /// Whether the backend keeps a version history that can be cleared.
  /// kDrive versions every upload; WebDAV simply overwrites the file.
  bool get supportsVersionHistory => false;

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
}
