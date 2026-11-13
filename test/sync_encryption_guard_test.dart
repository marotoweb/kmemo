// test/sync_encryption_guard_test.dart

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/services/encryption_service.dart';
import 'package:kmemo/services/kdrive_storage.dart';
import 'package:kmemo/services/storage_repository.dart';

/// Storage with encryption configured but the passphrase not loaded, which is
/// what happens when secure storage cannot be read or the app starts before
/// the passphrase is available.
class _EncryptedStorage extends KDriveStorage {
  int uploads = 0;

  @override
  bool get isConfigured => true;

  @override
  bool get encryptionEnabled => true;

  @override
  Future<List<RemoteMemoInfo>> listRemoteMemos() async => [];

  @override
  Future<String?> uploadMemo(Memo memo, List<Block> blocks) async {
    uploads++;
    return '1';
  }
}

/// Storage that would upload if the guard did not exist.
class _PlainTextGuardStorage extends KDriveStorage {
  @override
  bool get isConfigured => true;

  @override
  bool get encryptionEnabled => true;
}

void main() {
  setUp(EncryptionService.instance.disable);
  tearDown(EncryptionService.instance.disable);

  testWidgets('a sync without the passphrase uploads nothing', (
    WidgetTester tester,
  ) async {
    late AppDatabase db;
    late _EncryptedStorage storage;
    late MemoProvider provider;

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      storage = _EncryptedStorage();
      provider = MemoProvider(db, storage: storage);
      // A new note is marked as not synced and would be pushed.
      await provider.createNewMemo();
    });

    await tester.runAsync(() async {
      await expectLater(
        provider.performSync(force: true),
        throwsA(isA<StateError>()),
      );
    });

    // Uploading here would write the note in plain text: the passphrase is
    // configured but the encryption service is not enabled.
    expect(storage.uploads, 0);
  });

  test('an empty passphrase never enables encryption', () {
    EncryptionService.instance.enable('');
    expect(EncryptionService.instance.isEnabled, isFalse);
    expect(
      EncryptionService.instance.encrypt('segredo'),
      'segredo',
      reason: 'an empty key must not be treated as encryption',
    );
  });

  testWidgets('uploadMemo refuses to write a note in plain text', (
    WidgetTester tester,
  ) async {
    late Memo memo;

    await tester.runAsync(() async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final provider = MemoProvider(db);
      memo = await provider.createNewMemo();
    });

    final storage = _PlainTextGuardStorage();
    await tester.runAsync(() async {
      await expectLater(
        storage.uploadMemo(memo, const []),
        throwsA(isA<StateError>()),
      );
    });
  });
}
