// test/last_sync_hint_test.dart

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

/// Backend with a known last sync, so the card text is predictable and no
/// request leaves the test.
class _FakeStorage extends StorageRepository {
  _FakeStorage({this.isConfigured = true});

  @override
  final bool isConfigured;

  @override
  String get backendId => kSyncBackendKDrive;

  @override
  String get storageName => 'kDrive';

  @override
  DateTime? get lastSync => DateTime(2026, 11, 22, 14, 32);

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
  Future<List<RemoteMemoInfo>> listRemoteMemos() async => [];

  @override
  Future<RemoteMemo?> downloadMemo(String remoteFileId) async => null;
}

Future<ThemeProvider> _pumpHome(
  WidgetTester tester, {
  StorageRepository? storage,
}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final provider = MemoProvider(database, storage: storage ?? _FakeStorage());
  final themeProvider = ThemeProvider();
  final kdrive = KDriveStorage();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<MemoProvider>.value(value: provider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        Provider<KDriveStorage>.value(value: kdrive),
      ],
      child: const KMemoApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return themeProvider;
}

/// Starts the pull gesture and holds it, so the hint can be inspected before
/// the finger is released.
Future<TestGesture> _startPull(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(RefreshIndicator)),
  );
  await gesture.moveBy(const Offset(0, 200));
  await tester.pump();
  return gesture;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the last sync card shows while pulling and goes on release', (
    WidgetTester tester,
  ) async {
    await _pumpHome(tester);

    final gesture = await _startPull(tester);
    expect(find.textContaining('Last sync:'), findsOneWidget);
    expect(find.textContaining('22/11/2026 14:32'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(find.textContaining('Last sync:'), findsNothing);

    // Let the pull cycle finish against the fake backend.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  });

  testWidgets('the pull does not show the card when the option is off', (
    WidgetTester tester,
  ) async {
    final themeProvider = await _pumpHome(tester);
    await themeProvider.setShowLastSyncHint(false);
    await tester.pump();

    final gesture = await _startPull(tester);
    expect(find.textContaining('Last sync:'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the pull does not show the card without a backend', (
    WidgetTester tester,
  ) async {
    await _pumpHome(tester, storage: _FakeStorage(isConfigured: false));

    final gesture = await _startPull(tester);
    expect(find.textContaining('Last sync:'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
