// lib/services/sync_merge.dart

/// What a sync must do with a note that exists on both sides.
enum SyncAction {
  /// Both sides already agree: nothing to do.
  none,

  /// The local note is ahead (or the remote copy is missing): upload it.
  upload,

  /// The remote note is ahead and the local one is clean: download it.
  download,

  /// Both sides changed since the last sync: keep the local note and save the
  /// remote version as a separate conflict copy, so no text is lost.
  conflict,
}

/// Decides what a sync must do with a note, given what changed on each side.
///
/// This is the whole merge rule, kept free of IO so it can be tested in
/// isolation and reused by another client (the remote storage is a plain
/// folder of JSON files, so every client must reach the same verdict).
///
/// [localDirty] is `!memo.isSynced`: the note changed since the last upload.
/// [remoteExists] is false when the remote folder has no file for the note.
/// [remoteDirty] is true when the remote payload timestamp differs from the
/// one this device recorded at the last sync.
/// [localDeleted] / [remoteDeleted] are the trash flags of each copy.
SyncAction decideSyncAction({
  required bool localDirty,
  required bool remoteExists,
  required bool remoteDirty,
  required bool localDeleted,
  required bool remoteDeleted,
}) {
  if (!remoteExists) {
    // Never uploaded, or removed on another device. Uploading keeps the
    // user's note in the backup instead of leaving it local-only.
    return SyncAction.upload;
  }
  if (!localDirty && !remoteDirty) return SyncAction.none;
  if (localDirty && !remoteDirty) return SyncAction.upload;
  if (!localDirty && remoteDirty) return SyncAction.download;

  // Both sides changed. Restoring a note that another device sent to the
  // trash is not a conflict: the restore is the newer intent.
  if (remoteDeleted && !localDeleted) return SyncAction.upload;

  return SyncAction.conflict;
}

/// Compares two remote timestamps at second precision.
///
/// The local database stores `DateTime` as unix seconds, so sub-second digits
/// never survive a save. Comparing the raw values would report a change after
/// every upload and turn each sync into a conflict.
bool sameRemoteInstant(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.millisecondsSinceEpoch ~/ 1000 == b.millisecondsSinceEpoch ~/ 1000;
}
