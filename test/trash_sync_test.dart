// test/trash_sync_test.dart

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/services/kdrive_storage.dart';

/// Storage stub that only records the remote deletions.
class _FakeStorage extends KDriveStorage {
  int deleteCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<void> deleteMemo(String remoteFileId) async {
    deleteCalls++;
  }
}

Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('trash keeps the remote file until permanent deletion', (
    WidgetTester tester,
  ) async {
    late AppDatabase db;
    late _FakeStorage storage;
    late MemoProvider provider;
    late String uuid;

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      storage = _FakeStorage();
      provider = MemoProvider(db, storage: storage);

      final memo = await provider.createNewMemo();
      uuid = memo.uuid;
      await (db.update(db.memos)..where((t) => t.uuid.equals(uuid))).write(
        const MemosCompanion(
          remoteFileId: Value('remote-1'),
          isSynced: Value(true),
        ),
      );
      await _waitFor(() => provider.memos.isNotEmpty);
      await _waitFor(() => provider.memos.first.remoteFileId == 'remote-1');
    });

    // Sending to the trash is a soft delete: the kDrive file is kept and the
    // note is marked as unsynced so the isDeleted flag reaches the payload.
    await tester.runAsync(() async {
      await provider.softDeleteMultiple([uuid]);
      await _waitFor(() => provider.memos.first.isDeleted);
    });

    expect(storage.deleteCalls, 0);
    var stored = await tester.runAsync(
      () => (db.select(db.memos)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull(),
    );
    expect(stored!.isDeleted, isTrue);
    expect(stored.isSynced, isFalse);
    expect(stored.remoteFileId, 'remote-1');

    // Permanent deletion removes both the local row and the kDrive file.
    await tester.runAsync(() async {
      await provider.deleteMultiplePermanent([uuid]);
    });

    expect(storage.deleteCalls, 1);
    stored = await tester.runAsync(
      () => (db.select(db.memos)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull(),
    );
    expect(stored, isNull);
  });
}
