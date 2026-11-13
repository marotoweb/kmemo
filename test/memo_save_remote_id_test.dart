// test/memo_save_remote_id_test.dart

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/providers/memo_provider.dart';

void main() {
  testWidgets('editing keeps the remoteFileId stored locally', (
    WidgetTester tester,
  ) async {
    late AppDatabase db;
    late MemoProvider provider;
    late Memo memo;

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      provider = MemoProvider(db);
      memo = await provider.createNewMemo();
      // Simulates the first upload finishing while the editor is still open.
      await (db.update(db.memos)..where((t) => t.uuid.equals(memo.uuid))).write(
        const MemosCompanion(
          remoteFileId: Value('395'),
          isSynced: Value(true),
        ),
      );
    });

    await tester.runAsync(() async {
      final stored = await (db.select(
        db.memos,
      )..where((t) => t.uuid.equals(memo.uuid))).getSingle();
      // The editor snapshot still has a null remoteFileId.
      final stale = stored.copyWith(remoteFileId: const Value<String?>(null));
      await provider.saveMemo(stale, []);
    });

    final saved = (await tester.runAsync(
      () => (db.select(db.memos)..where((t) => t.uuid.equals(memo.uuid)))
          .getSingle(),
    ))!;
    // Losing the id would leave the remote .json orphaned: the note would be
    // re-uploaded by name and the old file could never be deleted.
    expect(saved.remoteFileId, '395');
    expect(saved.isSynced, isFalse);
  });
}
