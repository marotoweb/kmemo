// test/sync_merge_flow_test.dart

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/services/encryption_service.dart';
import 'package:kmemo/services/memo_serialization.dart';
import 'package:kmemo/services/storage_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory remote folder of JSON notes, with a modified time that changes on
/// every write (as a real server does).
class _FakeRemote extends StorageRepository {
  final Map<String, List<int>> files = {};
  final Map<String, RemoteMemoInfo> infos = {};
  int _clock = 0;
  int uploads = 0;
  int downloads = 0;
  bool _encryptionEnabled = false;

  void enableEncryption() => _encryptionEnabled = true;

  /// Simulates a device configured without encryption that points at a folder
  /// which already holds encrypted notes.
  void disableEncryptionForWrites() => _encryptionEnabled = false;

  /// Passphrase stored by the backend (what adoptEncryption persists).
  String? storedPassphrase;

  @override
  Future<String?> getEncryptionPassphrase() async => storedPassphrase;

  @override
  Future<bool> adoptEncryption(String passphrase) async {
    _encryptionEnabled = true;
    storedPassphrase = passphrase;
    EncryptionService.instance.enable(passphrase);
    return true;
  }

  @override
  bool get isConfigured => true;

  @override
  String get backendId => kSyncBackendWebDav;

  @override
  String get storageName => 'WebDAV';

  @override
  bool get encryptionEnabled => _encryptionEnabled;

  @override
  Future<void> init() async {}

  @override
  Future<void> clearConfiguration() async {}

  String _path(String uuid) => 'kmemo/notes/$uuid.json';

  DateTime _nextRevision() =>
      DateTime.utc(2026, 1, 1).add(Duration(seconds: ++_clock));

  void _write(Memo memo, List<Block> blocks) {
    files[memo.uuid] = encodeRemoteMemo(
      memo,
      blocks,
      encryptionRequired: _encryptionEnabled,
    );
    infos[memo.uuid] = RemoteMemoInfo(
      remoteFileId: _path(memo.uuid),
      name: '${memo.uuid}.json',
      updatedAt: _nextRevision(),
    );
  }

  /// Writes a note the way another device would: new payload timestamp and a
  /// new file modified time.
  void writeAsOtherDevice(Memo memo, List<Block> blocks) =>
      _write(memo, blocks);

  /// Replaces the remote file with bytes that cannot be decoded, the way a
  /// wrong passphrase or a damaged upload looks to the sync.
  void corrupt(String uuid) {
    files[uuid] = [0x7b, 0x00, 0x01];
    infos[uuid] = RemoteMemoInfo(
      remoteFileId: _path(uuid),
      name: '$uuid.json',
      updatedAt: _nextRevision(),
    );
  }

  /// Fails the next upload of this uuid, the way a network error does.
  String? failUploadOnce;

  /// How many tombstones this backend accepted.
  int tombstonesPublished = 0;

  /// Writes a tombstone, replacing the note's file as the real backends do.
  void writeTombstone(String uuid, DateTime deletedAt) {
    files[uuid] = encodeTombstone(
      uuid,
      deletedAt,
      encryptionRequired: _encryptionEnabled,
    );
    infos[uuid] = RemoteMemoInfo(
      remoteFileId: _path(uuid),
      name: '$uuid.json',
      updatedAt: _nextRevision(),
    );
  }

  @override
  Future<String?> uploadTombstone(
    String uuid,
    DateTime deletedAt, {
    String? remoteFileId,
  }) async {
    tombstonesPublished++;
    writeTombstone(uuid, deletedAt);
    return _path(uuid);
  }

  /// When set, uploads wait for it: lets a test hold a cycle open.
  Completer<void>? uploadGate;

  @override
  Future<String?> uploadMemo(Memo memo, List<Block> blocks) async {
    final gate = uploadGate;
    if (gate != null) await gate.future;
    if (failUploadOnce == memo.uuid) {
      failUploadOnce = null;
      throw Exception('upload failed');
    }
    uploads++;
    _write(memo, blocks);
    return _path(memo.uuid);
  }

  @override
  Future<String?> uploadFile({
    required String fileName,
    required List<int> bytes,
  }) async => fileName;

  @override
  Future<void> deleteMemo(String remoteFileId) async {
    final uuid = remoteFileId.split('/').last.replaceAll('.json', '');
    files.remove(uuid);
    infos.remove(uuid);
  }

  @override
  Future<List<RemoteMemoInfo>> listRemoteMemos() async => infos.values.toList();

  @override
  Future<RemoteMemo?> downloadMemo(String remoteFileId) async {
    downloads++;
    final uuid = remoteFileId.split('/').last.replaceAll('.json', '');
    final bytes = files[uuid];
    return bytes == null ? null : decodeRemoteMemo(bytes);
  }
}

Memo _memo(String uuid, String title) => Memo(
  uuid: uuid,
  title: title,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  isSynced: false,
  colorIndex: 0,
  bgImageIndex: -1,
  imageAttachments: '[]',
  audioAttachments: '[]',
  linkAttachments: '[]',
  isArchived: false,
  isDeleted: false,
  isPinned: false,
  sortIndex: 0,
);

List<Block> _blocks(String memoUuid, String text) => [
  Block(
    id: 0,
    uuid: '$memoUuid-block',
    memoUuid: memoUuid,
    type: BlockType.text,
    content: {'text': text},
    sortOrder: 0,
    isDeleted: false,
  ),
];

Future<Memo?> _stored(AppDatabase db, String uuid) =>
    (db.select(db.memos)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

typedef _Harness = ({
  AppDatabase db,
  _FakeRemote remote,
  MemoProvider provider,
});

Future<_Harness> _start(WidgetTester tester) async {
  late AppDatabase db;
  late _FakeRemote remote;
  late MemoProvider provider;
  await tester.runAsync(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _FakeRemote();
    provider = MemoProvider(db, storage: remote);
  });
  addTearDown(() async {
    provider.dispose();
    await db.close();
  });
  return (db: db, remote: remote, provider: provider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EncryptionService.instance.disable();
  });
  tearDown(EncryptionService.instance.disable);

  testWidgets('a local note is uploaded once and then left alone', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
    });

    expect(h.remote.uploads, 1);
    expect(h.remote.downloads, 0);
    final stored = await tester.runAsync(() => _stored(h.db, uuid));
    expect(stored!.isSynced, isTrue);
    expect(stored.remoteUpdatedAt, isNotNull);
    expect(stored.remoteRevision, isNotNull);

    // Nothing changed: the second sync must not download or re-upload it.
    await tester.runAsync(() => h.provider.performSync(force: true));
    expect(h.remote.uploads, 1);
    expect(h.remote.downloads, 0);
  });

  testWidgets('a remote edit reaches a clean local note', (tester) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
    });

    await tester.runAsync(() async {
      final synced = await _stored(h.db, uuid);
      h.remote.writeAsOtherDevice(
        synced!.copyWith(
          title: 'Do telemóvel',
          updatedAt: synced.updatedAt.add(const Duration(hours: 1)),
        ),
        _blocks(uuid, 'texto novo'),
      );
      await h.provider.performSync(force: true);
    });

    final stored = await tester.runAsync(() => _stored(h.db, uuid));
    expect(stored!.title, 'Do telemóvel');
    expect(stored.isSynced, isTrue);
    expect(h.remote.downloads, 1);
    // The remote payload replaces the blocks: a second copy of the body would
    // make the note text appear twice.
    final blocks = await tester.runAsync(() => h.db.getBlocksForMemo(uuid));
    expect(blocks!.length, 1);
    expect(blocks.single.content['text'], 'texto novo');
  });

  testWidgets(
    'both sides changed: the remote version becomes a conflict copy',
    (tester) async {
      final h = await _start(tester);
      late String uuid;

      await tester.runAsync(() async {
        final memo = await h.provider.createNewMemo();
        uuid = memo.uuid;
        await h.provider.performSync(force: true);
      });

      await tester.runAsync(() async {
        final synced = await _stored(h.db, uuid);
        final blocks = await h.provider.loadBlocks(uuid);

        await h.provider.saveMemo(
          synced!.copyWith(title: 'Versão local'),
          blocks,
        );
        h.remote.writeAsOtherDevice(
          synced.copyWith(
            title: 'Versão remota',
            updatedAt: synced.updatedAt.add(const Duration(hours: 2)),
          ),
          _blocks(uuid, 'texto remoto'),
        );
        await h.provider.performSync(force: true);
      });

      final rows = await tester.runAsync(() => h.db.select(h.db.memos).get());
      expect(rows!.length, 2);
      final canonical = rows.firstWhere((m) => m.uuid == uuid);
      final copy = rows.firstWhere((m) => m.uuid != uuid);
      // The local note stays canonical; the remote version survives as a copy.
      expect(canonical.title, 'Versão local');
      expect(copy.title, 'Versão remota (Conflict)');
      // The copy has its own remote file; deleting it can never remove the
      // original note from the server.
      expect(copy.remoteFileId, isNotNull);
      expect(copy.remoteFileId, isNot(canonical.remoteFileId));
      expect(copy.remoteUpdatedAt, isNotNull);
      // Both were uploaded in the same cycle, under different uuids.
      expect(h.remote.infos.length, 2);
    },
  );

  testWidgets('a conflict copy follows the system language', (tester) async {
    // No language was chosen, so the app follows the system language: the
    // copy title must too (it used to fall back to English, which titled a
    // Portuguese screen's copy "(Conflict)").
    tester.binding.platformDispatcher.localeTestValue = const Locale('pt', 'PT');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
    });

    await tester.runAsync(() async {
      final synced = await _stored(h.db, uuid);
      final blocks = await h.provider.loadBlocks(uuid);
      await h.provider.saveMemo(synced!.copyWith(title: 'Local'), blocks);
      h.remote.writeAsOtherDevice(
        synced.copyWith(
          title: 'Remoto',
          updatedAt: synced.updatedAt.add(const Duration(hours: 1)),
        ),
        _blocks(uuid, 'remoto'),
      );
      await h.provider.performSync(force: true);
    });

    final rows = await tester.runAsync(() => h.db.select(h.db.memos).get());
    final copy = rows!.firstWhere((m) => m.uuid != uuid);
    expect(copy.title, 'Remoto (Conflito)');
  });

  testWidgets('a stale remote copy after switching backends is replaced', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
    });

    await tester.runAsync(() async {
      final synced = await _stored(h.db, uuid);
      // The newly selected backend already holds an older copy of the note.
      h.remote.writeAsOtherDevice(
        synced!.copyWith(
          title: 'Cópia antiga',
          updatedAt: synced.updatedAt.subtract(const Duration(days: 3)),
        ),
        _blocks(uuid, 'antigo'),
      );
      // Switching backends resets the remote bookkeeping.
      await h.provider.disableSync();
      await h.provider.performSync(force: true);
    });

    final rows = await tester.runAsync(() => h.db.select(h.db.memos).get());
    // The local library wins: no conflict copy, no stale content.
    expect(rows!.length, 1);
    expect(rows.single.uuid, uuid);
    expect(rows.single.title, isNot('Cópia antiga'));
    expect(h.remote.infos.length, 1);
  });

  testWidgets('a note from another device is downloaded and not re-uploaded', (
    tester,
  ) async {
    final h = await _start(tester);
    const uuid = 'remote-only';

    await tester.runAsync(() async {
      h.remote.writeAsOtherDevice(
        _memo(uuid, 'Do portátil'),
        _blocks(uuid, 'olá'),
      );
      await h.provider.performSync(force: true);
    });

    final stored = await tester.runAsync(() => _stored(h.db, uuid));
    expect(stored!.title, 'Do portátil');
    // The encryption setting matches, so there is nothing to re-upload.
    expect(stored.isSynced, isTrue);
    expect(h.remote.uploads, 0);
    expect(h.remote.downloads, 1);

    await tester.runAsync(() => h.provider.performSync(force: true));
    expect(h.remote.uploads, 0);
    expect(h.remote.downloads, 1);
  });

  testWidgets('a manual sync is not swallowed by the running cycle', (
    tester,
  ) async {
    final h = await _start(tester);

    await tester.runAsync(() async {
      await h.provider.createNewMemo();
      h.remote.uploadGate = Completer<void>();

      // The automatic cycle is held open in its upload.
      final auto = h.provider.performSync();
      // "Sync now" asks for a full pass: it must run, not join a cycle that
      // already planned from the older state.
      final manual = h.provider.performSync(force: true);
      expect(identical(auto, manual), isFalse);

      var manualDone = false;
      manual.then((_) => manualDone = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(manualDone, isFalse);

      h.remote.uploadGate!.complete();
      h.remote.uploadGate = null;
      await Future.wait([auto, manual]);
      expect(manualDone, isTrue);
    });
  });

  testWidgets('two syncs started together create a single conflict copy', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
    });

    await tester.runAsync(() async {
      final synced = await _stored(h.db, uuid);
      final blocks = await h.provider.loadBlocks(uuid);
      await h.provider.saveMemo(synced!.copyWith(title: 'Local'), blocks);
      h.remote.writeAsOtherDevice(
        synced.copyWith(
          title: 'Remoto',
          updatedAt: synced.updatedAt.add(const Duration(hours: 1)),
        ),
        _blocks(uuid, 'remoto'),
      );

      // Two automatic cycles can overlap: the debounced sync fires while a
      // slow one is still pushing. Both would plan from the same state and
      // each would save its own copy.
      final first = h.provider.performSync();
      final second = h.provider.performSync();
      expect(identical(first, second), isTrue);
      await Future.wait([first, second]);
    });

    final rows = await tester.runAsync(() => h.db.select(h.db.memos).get());
    expect(rows!.length, 2);
  });

  testWidgets('a conflict is not copied twice when the upload fails', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
    });

    await tester.runAsync(() async {
      final synced = await _stored(h.db, uuid);
      final blocks = await h.provider.loadBlocks(uuid);
      await h.provider.saveMemo(synced!.copyWith(title: 'Local'), blocks);
      h.remote.writeAsOtherDevice(
        synced.copyWith(
          title: 'Remoto',
          updatedAt: synced.updatedAt.add(const Duration(hours: 1)),
        ),
        _blocks(uuid, 'remoto'),
      );

      // The canonical note cannot be uploaded, so the remote keeps the version
      // that was already saved as a copy. The revision refresh is also lost,
      // so the next cycle inspects the same payload again.
      h.remote.failUploadOnce = uuid;
      await h.provider.performSync(force: true);
      await (h.db.update(h.db.memos)..where((t) => t.uuid.equals(uuid)))
          .write(const MemosCompanion(remoteRevision: Value(null)));
      await h.provider.performSync(force: true);
    });

    // The remote version was already saved: a second copy would be a duplicate.
    final rows = await tester.runAsync(() => h.db.select(h.db.memos).get());
    expect(rows!.length, 2);
  });

  testWidgets('an edit made while a cycle records the upload makes no copy', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
    });

    await tester.runAsync(() async {
      // The editor loads the note (this snapshot is what a checklist saves on
      // every tap).
      final snapshot = (await _stored(h.db, uuid))!;

      // Meanwhile the sync finishes an upload and records the payload it wrote:
      // a new remote file and its timestamp in the bookkeeping.
      final uploadedAt = DateTime.utc(2026, 1, 2, 10);
      h.remote.writeAsOtherDevice(
        snapshot.copyWith(updatedAt: uploadedAt),
        _blocks(uuid, 'do servidor'),
      );
      await (h.db.update(h.db.memos)..where((t) => t.uuid.equals(uuid))).write(
        MemosCompanion(remoteUpdatedAt: Value(uploadedAt)),
      );

      // The editor then saves its older snapshot, as a checklist tap does.
      await h.provider.saveMemo(
        snapshot.copyWith(title: 'Lista'),
        _blocks(uuid, 'editado'),
      );
    });

    // The edit must not roll the bookkeeping back. Before the fix the editor
    // wrote its snapshot's value and the next cycle read the remote payload as
    // a different version while the note was still dirty, took both sides as
    // changed and saved a conflict copy of our own upload.
    final afterEdit = await tester.runAsync(() => _stored(h.db, uuid));
    // Drift hands the value back as a local DateTime, so compare the instant.
    expect(
      afterEdit!.remoteUpdatedAt!.millisecondsSinceEpoch,
      DateTime.utc(2026, 1, 2, 10).millisecondsSinceEpoch,
    );
    expect(afterEdit.isSynced, isFalse);

    await tester.runAsync(() => h.provider.performSync(force: true));

    final stored = await tester.runAsync(() => _stored(h.db, uuid));
    expect(stored!.title, 'Lista');
    expect(stored.isSynced, isTrue);
    final all = await tester.runAsync(() => h.db.select(h.db.memos).get());
    expect(all!.length, 1, reason: 'no conflict copy of our own upload');
  });

  testWidgets('colour, background and archive changes reach the server', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;
    late DateTime before;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
      // Backdate the note: the database stores whole seconds, so a change made
      // in the same second as the upload would look identical either way.
      before = DateTime.utc(2026, 1, 1);
      await (h.db.update(h.db.memos)..where((t) => t.uuid.equals(uuid))).write(
        MemosCompanion(updatedAt: Value(before)),
      );
      await h.provider.changeColorMultiple([uuid], 3);
      await h.provider.performSync(force: true);
    });

    var payload = decodeRemoteMemo(h.remote.files[uuid]!)!;
    expect(payload.memo.colorIndex, 3);
    // The payload timestamp has to move: the other device compares it with the
    // one it recorded and would answer "nothing to do" otherwise, so a colour
    // change would only arrive the next time the note was edited.
    expect(payload.memo.updatedAt.isAfter(before), isTrue);
    var stored = await tester.runAsync(() => _stored(h.db, uuid));
    expect(stored!.isSynced, isTrue);

    await tester.runAsync(() async {
      await h.provider.changeBgImageMultiple([uuid], 2);
      await h.provider.performSync(force: true);
    });
    payload = decodeRemoteMemo(h.remote.files[uuid]!)!;
    expect(payload.memo.bgImageIndex, 2);

    await tester.runAsync(() async {
      await h.provider.archiveMemoStatus(uuid, true);
      await h.provider.performSync(force: true);
    });
    payload = decodeRemoteMemo(h.remote.files[uuid]!)!;
    expect(payload.memo.isArchived, isTrue);

    stored = await tester.runAsync(() => _stored(h.db, uuid));
    expect(stored!.isSynced, isTrue);
  });

  testWidgets('a permanent deletion is published, not erased', (tester) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
      await h.provider.deleteMultiplePermanent([uuid]);
      await h.provider.performSync(force: true);
    });

    // The note is gone from this device...
    expect(await tester.runAsync(() => _stored(h.db, uuid)), isNull);
    // ...but its file still exists, carrying the tombstone. Deleting the file
    // was the bug: the other device saw "no remote copy" and re-uploaded it.
    expect(h.remote.files.containsKey(uuid), isTrue);
    final payload = decodeRemoteMemo(h.remote.files[uuid]!)!;
    expect(payload.tombstone, isTrue);
    expect(h.remote.tombstonesPublished, 1);
    expect(h.remote.uploads, 1);

    // A second sync must not publish it again.
    await tester.runAsync(() => h.provider.performSync(force: true));
    expect(h.remote.tombstonesPublished, 1);
  });

  testWidgets('a note deleted on another device is deleted here', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
      // The other device permanently deleted it: the file is a tombstone now.
      h.remote.writeTombstone(uuid, DateTime.now().toUtc());
      await h.provider.performSync(force: true);
    });

    expect(await tester.runAsync(() => _stored(h.db, uuid)), isNull);
    // The tombstone is not a note: no upload, and it is never downloaded again.
    expect(h.remote.uploads, 1);
    expect(h.remote.tombstonesPublished, 0);

    await tester.runAsync(() => h.provider.performSync(force: true));
    expect(await tester.runAsync(() => _stored(h.db, uuid)), isNull);
    expect(h.remote.uploads, 1);
  });

  testWidgets('an old client re-uploading a deleted note does not revive it', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;
    late Memo before;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
      before = (await _stored(h.db, uuid))!;
      await h.provider.deleteMultiplePermanent([uuid]);
      await h.provider.performSync(force: true);
    });

    await tester.runAsync(() async {
      // A device that does not know about tombstones still holds the note and
      // uploads it back over the tombstone.
      h.remote.writeAsOtherDevice(before, _blocks(uuid, 'texto antigo'));
      await h.provider.performSync(force: true);
    });

    // The deletion wins: no note here, and the file is a tombstone again.
    expect(await tester.runAsync(() => _stored(h.db, uuid)), isNull);
    expect(decodeRemoteMemo(h.remote.files[uuid]!)!.tombstone, isTrue);
    expect(h.remote.tombstonesPublished, 2);
  });

  testWidgets('an encrypted folder is not rewritten in plain text', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;
    const passphrase = 'segredo-do-servidor';

    await tester.runAsync(() async {
      // Another device uploaded the note encrypted.
      EncryptionService.instance.enable(passphrase);
      final memo = _memo('nota-cifrada', 'Nota remota');
      h.remote.enableEncryption();
      h.remote.writeAsOtherDevice(memo, _blocks(memo.uuid, 'conteudo'));
      uuid = memo.uuid;
      // This device was configured with encryption off and has no passphrase.
      h.remote.disableEncryptionForWrites();
      EncryptionService.instance.disable();

      await h.provider.performSync(
        force: true,
        requestPassphrase: (_) async => passphrase,
      );
    });

    // The note came down.
    final stored = await tester.runAsync(() => _stored(h.db, uuid));
    expect(stored, isNotNull);

    // ...and the remote file was left alone. Before this, the feature that
    // re-encodes a note to match the backend rewrote it in plain text, which
    // published the library.
    expect(h.remote.uploads, 0);
    expect(h.remote.encryptionEnabled, isTrue);
    expect(h.remote.storedPassphrase, passphrase);
    final payload = decodeRemoteMemo(h.remote.files[uuid]!)!;
    expect(payload.wasEncrypted, isTrue);
  });

  testWidgets('the passphrase that decrypted a note is kept for later uploads', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;
    const passphrase = 'segredo-do-servidor';

    await tester.runAsync(() async {
      EncryptionService.instance.enable(passphrase);
      final memo = _memo('nota-cifrada', 'Nota remota');
      h.remote.enableEncryption();
      h.remote.writeAsOtherDevice(memo, _blocks(memo.uuid, 'conteudo'));
      uuid = memo.uuid;
      h.remote.disableEncryptionForWrites();
      EncryptionService.instance.disable();

      await h.provider.performSync(
        force: true,
        requestPassphrase: (_) async => passphrase,
      );

      // A later edit must upload without asking again: the passphrase is now
      // the backend's, so the push is not refused.
      final stored = await _stored(h.db, uuid);
      final blocks = await h.provider.loadBlocks(uuid);
      await h.provider.saveMemo(stored!.copyWith(title: 'Editada'), blocks);
      await h.provider.performSync(force: true);
    });

    expect(h.remote.uploads, 1);
    final payload = decodeRemoteMemo(h.remote.files[uuid]!)!;
    expect(payload.memo.title, 'Editada');
    expect(payload.wasEncrypted, isTrue);
  });

  testWidgets('a note the sync cannot read is reported to the UI', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
    });
    expect(h.provider.undecryptableNotes, 0);

    await tester.runAsync(() async {
      h.remote.corrupt(uuid);
      // The revision is unknown, so the note is inspected on the next sync.
      await (h.db.update(h.db.memos)..where((t) => t.uuid.equals(uuid))).write(
        const MemosCompanion(remoteRevision: Value(null)),
      );
      await h.provider.performSync(force: true);
    });

    // An automatic sync cannot ask for the passphrase: the count is what the
    // home screen uses to warn the user instead of failing silently.
    expect(h.provider.undecryptableNotes, 1);

    await tester.runAsync(() async {
      final stored = await _stored(h.db, uuid);
      final blocks = await h.provider.loadBlocks(uuid);
      h.remote.writeAsOtherDevice(stored!, blocks);
      await h.provider.performSync(force: true);
    });
    expect(h.provider.undecryptableNotes, 0);
  });

  testWidgets('a note migrated from an older database is inspected once', (
    tester,
  ) async {
    final h = await _start(tester);
    late String uuid;

    await tester.runAsync(() async {
      final memo = await h.provider.createNewMemo();
      uuid = memo.uuid;
      await h.provider.performSync(force: true);
      // The v6 migration seeds remoteUpdatedAt but leaves the revision
      // unknown: the next sync must read the note instead of trusting it.
      await (h.db.update(h.db.memos)..where((t) => t.uuid.equals(uuid))).write(
        const MemosCompanion(remoteRevision: Value(null)),
      );
    });

    await tester.runAsync(() async {
      final synced = await _stored(h.db, uuid);
      h.remote.writeAsOtherDevice(
        synced!.copyWith(
          title: 'Editada antes da atualização',
          updatedAt: synced.updatedAt.add(const Duration(hours: 5)),
        ),
        _blocks(uuid, 'novo'),
      );
      await h.provider.performSync(force: true);
    });

    final stored = await tester.runAsync(() => _stored(h.db, uuid));
    expect(stored!.title, 'Editada antes da atualização');
    expect(h.remote.downloads, 1);

    // The revision is now known: the next sync does not download again.
    await tester.runAsync(() => h.provider.performSync(force: true));
    expect(h.remote.downloads, 1);
  });

  testWidgets('a plain remote note is re-uploaded when encryption is enabled', (
    tester,
  ) async {
    final h = await _start(tester);
    const uuid = 'plain-remote';

    await tester.runAsync(() async {
      h.remote.writeAsOtherDevice(
        _memo(uuid, 'Nota antiga'),
        _blocks(uuid, 'em claro'),
      );
      // Encryption is enabled after the remote copy was written in plain text.
      EncryptionService.instance.enable('correct horse battery staple');
      h.remote.enableEncryption();
      await h.provider.performSync(force: true);
    });

    final stored = await tester.runAsync(() => _stored(h.db, uuid));
    expect(stored!.title, 'Nota antiga');
    expect(stored.isSynced, isTrue);
    expect(h.remote.uploads, 1);
    // The remote file was rewritten encrypted, not left in plain text.
    final raw = utf8.decode(h.remote.files[uuid]!);
    expect(EncryptionService.looksEncrypted(raw), isTrue);
  });
}
