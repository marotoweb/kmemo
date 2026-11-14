// lib/services/memo_serialization.dart

import 'dart:convert';

import '../database/database.dart';
import 'encryption_service.dart';
import 'storage_repository.dart';

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
      'createdAt': memo.createdAt.toIso8601String(),
      'updatedAt': memo.updatedAt.toIso8601String(),
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
    'syncedAt': DateTime.now().toIso8601String(),
  };
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
  if (encryptionRequired && !EncryptionService.instance.isEnabled) {
    throw StateError(
      'Encryption is enabled but the passphrase is not loaded; '
      'refusing to upload ${memo.uuid} in plain text',
    );
  }
  final json = jsonEncode(buildRemoteMemoPayload(memo, blocks));
  return utf8.encode(EncryptionService.instance.encrypt(json));
}

/// Decrypts and parses a downloaded note.
///
/// Returns null when the payload cannot be decrypted (wrong passphrase or
/// corrupted file) or is not valid JSON.
RemoteMemo? decodeRemoteMemo(List<int> bytes) {
  if (bytes.isEmpty) return null;
  final decrypted = EncryptionService.instance.tryDecrypt(utf8.decode(bytes));
  if (decrypted == null) return null;

  try {
    final payload = jsonDecode(decrypted) as Map<String, dynamic>;
    final memoMap = payload['memo'] as Map<String, dynamic>;
    final memo = Memo(
      uuid: memoMap['uuid'] as String,
      title: memoMap['title'] as String? ?? '',
      createdAt: DateTime.parse(memoMap['createdAt'] as String),
      updatedAt: DateTime.parse(memoMap['updatedAt'] as String),
      isSynced: memoMap['isSynced'] as bool? ?? false,
      colorIndex: memoMap['colorIndex'] as int? ?? 0,
      bgImageIndex: memoMap['bgImageIndex'] as int? ?? -1,
      isArchived: memoMap['isArchived'] as bool? ?? false,
      isDeleted: memoMap['isDeleted'] as bool? ?? false,
      isPinned: memoMap['isPinned'] as bool? ?? false,
      sortIndex: 0, // manual order is local to the device
      remoteFileId: memoMap['remoteFileId'] as String?,
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

    return RemoteMemo(memo: memo, blocks: blocks);
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
