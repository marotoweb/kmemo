// test/home_sync_button_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/main.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/providers/theme_provider.dart';
import 'package:kmemo/services/kdrive_storage.dart';
import 'package:kmemo/services/storage_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend that counts the listing calls, which is where a cycle starts.
class _CountingStorage extends StorageRepository {
  int listCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  String get backendId => kSyncBackendKDrive;

  @override
  String get storageName => 'kDrive';

  @override
  DateTime? get lastSync => null;

  @override
  Future<void> init() async {}

  @override
  Future<void> clearConfiguration() async {}

  @override
  Future<String?> uploadMemo(Memo memo, List<Block> blocks) async => null;

  @override
  Future<String?> uploadFile({
    required String fileName,
    required List<int> bytes,
  }) async => null;

  @override
  Future<void> deleteMemo(String remoteFileId) async {}

  @override
  Future<List<RemoteMemoInfo>> listRemoteMemos() async {
    listCalls++;
    return [];
  }

  @override
  Future<RemoteMemo?> downloadMemo(String remoteFileId) async => null;
}

Future<_CountingStorage> _pumpHome(WidgetTester tester) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final storage = _CountingStorage();
  final provider = MemoProvider(database, storage: storage);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<MemoProvider>.value(value: provider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<KDriveStorage>.value(value: KDriveStorage()),
      ],
      child: const KMemoApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return storage;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the sync button runs a manual cycle', (
    WidgetTester tester,
  ) async {
    final storage = await _pumpHome(tester);
    expect(storage.listCalls, 0);

    await tester.tap(find.byIcon(Icons.cloud_sync_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // The cycle listed the remote folder, which is its first step.
    expect(storage.listCalls, 1);
  });

  testWidgets('the sync button sits before the sort icon', (
    WidgetTester tester,
  ) async {
    await _pumpHome(tester);

    final sync = tester.getCenter(find.byIcon(Icons.cloud_sync_outlined));
    final sort = tester.getCenter(find.byIcon(Icons.sort));
    expect(sync.dx, lessThan(sort.dx));

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    // Opening the search must not move the sort icon, which stays last.
    expect(tester.getCenter(find.byIcon(Icons.sort)).dx, sort.dx);
    expect(
      tester.getCenter(find.byIcon(Icons.cloud_sync_outlined)).dx,
      sync.dx,
    );
  });

  testWidgets('the sync button answers when there is no backend', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final provider = MemoProvider(database, storage: KDriveStorage());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          ChangeNotifierProvider<MemoProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          Provider<KDriveStorage>.value(value: KDriveStorage()),
        ],
        child: const KMemoApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.cloud_sync_outlined));
    await tester.pump();

    expect(find.text('No remote storage is configured'), findsOneWidget);
  });
}
