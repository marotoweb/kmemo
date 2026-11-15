// lib/services/storage_repository.dart

import '../database/database.dart';

/// SharedPreferences key holding the active sync backend ("kdrive" or
/// "webdav"). Read by main() to pick the storage injected into MemoProvider.
const String kSyncBackendKey = 'sync_backend';

/// Backend names accepted by [kSyncBackendKey].
const String kSyncBackendKDrive = 'kdrive';
const String kSyncBackendWebDav = 'webdav';

/// HTTP failure returned by a remote backend.
///
/// The status code is kept so callers can tell a transient failure from one
/// that cannot succeed on a retry: a 403/405 means the credentials or the
/// destination folder are wrong, and repeating the request three times only
/// makes a misconfigured sync look slow (it was retrying every note).
class RemoteHttpException implements Exception {
  final int statusCode;
  final String body;

  RemoteHttpException(this.statusCode, this.body);

  /// Timeout, rate limit and server errors are worth another attempt.
  bool get isRetryable =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;

  @override
  String toString() => 'HTTP $statusCode: $body';
}

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

  /// Whether the remote file was encrypted when it was read.
  ///
  /// The sync compares this with the backend's current setting, so a
  /// downloaded note is only re-uploaded when the two differ (for example
  /// after encryption was enabled).
  final bool wasEncrypted;

  /// Whether this file is the tombstone of a permanently deleted note.
  ///
  /// A tombstone carries no content: it only says the note must be deleted on
  /// every device, so nobody re-uploads the version it still holds.
  final bool tombstone;

  /// When the note was permanently deleted, for a tombstone payload.
  final DateTime? deletedAt;

  RemoteMemo({
    required this.memo,
    required this.blocks,
    this.wasEncrypted = false,
    this.tombstone = false,
    this.deletedAt,
  });
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

  /// Removes the stored configuration and every secret of this backend, so it
  /// can be configured again from scratch (the symmetric pair of configure()).
  Future<void> clearConfiguration();

  /// Human-readable name of the storage type (e.g. "kDrive", "WebDAV").
  String get storageName;

  /// Stable identifier of the backend, one of the [kSyncBackendKey] values.
  ///
  /// The UI uses it to pick the right label; never match on [storageName],
  /// which is display text and may be translated.
  String get backendId;

  /// Whether the notes must be encrypted before leaving the device.
  ///
  /// When this is true and [EncryptionService] has no passphrase loaded, the
  /// caller aborts the sync and every upload throws instead of writing a note
  /// in plain text.
  bool get encryptionEnabled => false;

  /// Passphrase stored by the backend, used to retry a note that failed to
  /// decrypt with the passphrase loaded at startup.
  Future<String?> getEncryptionPassphrase() async => null;

  /// Publishes the tombstone of a permanently deleted note.
  ///
  /// Unlike [deleteMemo], which removes the file and is invisible to every
  /// other device, this writes a tombstone payload under the note's file name,
  /// so the deletion reaches the devices that still hold the note. Returns the
  /// remote id of the written file, or null when the backend is not configured.
  Future<String?> uploadTombstone(
    String uuid,
    DateTime deletedAt, {
    String? remoteFileId,
  }) {
    // A backend that does not implement this cannot publish a deletion, and
    // reporting success would mark the tombstone as sent while the note stays
    // in the folder. Fail so the sync logs it and retries next cycle.
    throw UnimplementedError(
      '$storageName cannot publish tombstones; the note would come back on the '
      'next sync of another device',
    );
  }

  /// Turns encryption on for this backend with [passphrase], without going
  /// through `configure()` (which needs the whole form).
  ///
  /// Used when the remote folder is found to hold encrypted notes while this
  /// device was configured without encryption: the passphrase the user typed to
  /// read them is the backend's, so the only consistent state is encryption on.
  /// The alternative — rewriting those files with the encryption off — would
  /// publish every note in plain text.
  ///
  /// Returns false when the passphrase could not be persisted (keychain
  /// unavailable); encryption is still on for this session.
  Future<bool> adoptEncryption(String passphrase) async => false;

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

  /// Uploads an arbitrary file (for example the .docx built by the export
  /// action) to the same remote folder the notes use.
  ///
  /// This does not go through the note payload, so the file is **not**
  /// encrypted even when [encryptionEnabled] is true: it is a user-requested
  /// export of the note content. Callers that can upload sensitive data
  /// should tell the user about it.
  ///
  /// Returns the remote id when the backend reports one.
  Future<String?> uploadFile({
    required String fileName,
    required List<int> bytes,
  });

  /// Removes a note from remote storage.
  Future<void> deleteMemo(String remoteFileId);

  /// Lists the notes available in remote storage.
  Future<List<RemoteMemoInfo>> listRemoteMemos();

  /// Downloads a complete note from remote storage.
  /// Returns null if the note cannot be decrypted (wrong passphrase or corrupted data).
  Future<RemoteMemo?> downloadMemo(String remoteFileId);
}
