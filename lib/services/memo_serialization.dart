// lib/services/memo_serialization.dart

import 'dart:convert';

import '../database/database.dart';
import 'encryption_service.dart';
import 'storage_repository.dart';

/// Serialises a timestamp as an unambiguous UTC instant.
///
/// `DateTime.toIso8601String()` omits the offset for a local `DateTime`, so a
/// device in UTC+1 and a server in UTC used to write values that could not be
/// compared. New payloads always end with `Z`; the reader still accepts the
/// legacy offset-less form (interpreted as local time by `DateTime.parse`).
String _isoUtc(DateTime value) => value.toUtc().toIso8601String();

/// Parses a timestamp from a remote payload and normalises it to UTC.
DateTime _parseUtc(Object? value) => DateTime.parse(value as String).toUtc();

/// Remote payload shared by every storage backend.
///
/// kDrive and WebDAV must write exactly the same format, so a note exported to
/// one backend can be pulled back by the other one (and the pull path, which
/// derives the note uuid from the file name, keeps working).
Map<String, dynamic> buildRemoteMemoPayload(Memo memo, List<Block> blocks) {
  return {
    'memo': {
      'uuid': memo.uuid,
      'title': memo.title,
      'createdAt': _isoUtc(memo.createdAt),
      'updatedAt': _isoUtc(memo.updatedAt),
      'colorIndex': memo.colorIndex,
      'bgImageIndex': memo.bgImageIndex,
      'imageAttachments': memo.imageAttachments,
      'audioAttachments': memo.audioAttachments,
      'linkAttachments': memo.linkAttachments,
      'isArchived': memo.isArchived,
      'isDeleted': memo.isDeleted,
      'isPinned': memo.isPinned,
    },
    'blocks': blocks.map((b) {
      return {
        'uuid': b.uuid,
        'type': b.type.name,
        'content': b.content,
        'sortOrder': b.sortOrder,
        'isDeleted': b.isDeleted,
      };
    }).toList(),
    'syncedAt': _isoUtc(DateTime.now()),
  };
}

/// Builds the payload that replaces a permanently deleted note.
///
/// The folder is the only channel between devices, so a deletion has to be
/// published as content: removing the file would be invisible to every device
/// that still holds the note, and the first one to sync would upload it back.
///
/// The payload keeps a `memo` object (flagged as deleted, with the deletion
/// time as its timestamp), so a client that does not know about tombstones
/// reads it as a note sitting in the trash instead of failing. `tombstone` and
/// `deletedAt` are what the current client reads to delete the note for good.
Map<String, dynamic> buildTombstonePayload(String uuid, DateTime deletedAt) {
  final moment = deletedAt.toUtc();
  final memo = Memo(
    uuid: uuid,
    title: '',
    createdAt: moment,
    updatedAt: moment,
    isSynced: true,
    colorIndex: 0,
    bgImageIndex: -1,
    imageAttachments: '[]',
    audioAttachments: '[]',
    linkAttachments: '[]',
    isArchived: false,
    isDeleted: true,
    isPinned: false,
    sortIndex: 0,
  );
  final payload = buildRemoteMemoPayload(memo, const []);
  payload['tombstone'] = true;
  payload['deletedAt'] = _isoUtc(moment);
  return payload;
}

/// Serialises a note for the remote storage, encrypted when the service has a
/// passphrase loaded.
///
/// Throws [StateError] when [encryptionRequired] is true but the passphrase is
/// not loaded: writing the JSON in plain text would leak the note. This is the
/// single place that decides whether a remote copy is encrypted.
List<int> encodeRemoteMemo(
  Memo memo,
  List<Block> blocks, {
  required bool encryptionRequired,
}) {
  return _encode(
    buildRemoteMemoPayload(memo, blocks),
    uuid: memo.uuid,
    encryptionRequired: encryptionRequired,
  );
}

/// Serialises the tombstone of a permanently deleted note.
///
/// Goes through the same encoder as a note, so a folder with encryption on
/// never receives the note's uuid and deletion time in plain text.
List<int> encodeTombstone(
  String uuid,
  DateTime deletedAt, {
  required bool encryptionRequired,
}) {
  return _encode(
    buildTombstonePayload(uuid, deletedAt),
    uuid: uuid,
    encryptionRequired: encryptionRequired,
  );
}

List<int> _encode(
  Map<String, dynamic> payload, {
  required String uuid,
  required bool encryptionRequired,
}) {
  if (encryptionRequired && !EncryptionService.instance.isEnabled) {
    throw StateError(
      'Encryption is enabled but the passphrase is not loaded; '
      'refusing to upload $uuid in plain text',
    );
  }
  return utf8.encode(EncryptionService.instance.encrypt(jsonEncode(payload)));
}

/// Decrypts and parses a downloaded note.
///
/// Returns null when the payload cannot be decrypted (wrong passphrase or
/// corrupted file) or is not valid JSON.
RemoteMemo? decodeRemoteMemo(List<int> bytes) {
  if (bytes.isEmpty) return null;
  final raw = utf8.decode(bytes);
  // Remember whether the file was encrypted before trying to read it: the
  // caller re-uploads a downloaded note only when this differs from the
  // backend's current setting.
  final wasEncrypted = EncryptionService.looksEncrypted(raw);
  final decrypted = EncryptionService.instance.tryDecrypt(raw);
  if (decrypted == null) return null;

  try {
    final payload = jsonDecode(decrypted) as Map<String, dynamic>;
    final memoMap = payload['memo'] as Map<String, dynamic>;
    final remoteUpdatedAt = _parseUtc(memoMap['updatedAt']);
    final memo = Memo(
      uuid: memoMap['uuid'] as String,
      title: memoMap['title'] as String? ?? '',
      createdAt: _parseUtc(memoMap['createdAt']),
      updatedAt: remoteUpdatedAt,
      isSynced: memoMap['isSynced'] as bool? ?? false,
      colorIndex: memoMap['colorIndex'] as int? ?? 0,
      bgImageIndex: memoMap['bgImageIndex'] as int? ?? -1,
      isArchived: memoMap['isArchived'] as bool? ?? false,
      isDeleted: memoMap['isDeleted'] as bool? ?? false,
      isPinned: memoMap['isPinned'] as bool? ?? false,
      sortIndex: 0, // manual order is local to the device
      remoteFileId: memoMap['remoteFileId'] as String?,
      // The downloaded payload is the remote revision this device now knows.
      // The caller fills in the file's modified time after saving.
      remoteUpdatedAt: remoteUpdatedAt,
      imageAttachments: memoMap['imageAttachments'] as String? ?? '[]',
      audioAttachments: memoMap['audioAttachments'] as String? ?? '[]',
      linkAttachments: memoMap['linkAttachments'] as String? ?? '[]',
    );

    final blocksList = (payload['blocks'] as List<dynamic>?) ?? [];
    final blocks = blocksList.map((b) {
      final bm = b as Map<String, dynamic>;
      return Block(
        id: 0,
        uuid: bm['uuid'] as String,
        memoUuid: memo.uuid,
        type: blockTypeFromName(bm['type'] as String?),
        content: Map<String, dynamic>.from(bm['content'] as Map? ?? {}),
        sortOrder: bm['sortOrder'] as int? ?? 0,
        isDeleted: bm['isDeleted'] as bool? ?? false,
      );
    }).toList();

    return RemoteMemo(
      memo: memo,
      blocks: blocks,
      wasEncrypted: wasEncrypted,
      tombstone: payload['tombstone'] == true,
      deletedAt: payload['deletedAt'] == null
          ? null
          : _parseUtc(payload['deletedAt']),
    );
  } catch (_) {
    return null;
  }
}

/// Parses the block type stored in the remote payload.
BlockType blockTypeFromName(String? name) {
  return BlockType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => BlockType.text,
  );
}
