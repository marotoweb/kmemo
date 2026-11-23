// test/danger_zone_test.dart

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/l10n/app_localizations.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/providers/theme_provider.dart';
import 'package:kmemo/ui/screens/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settleDatabase(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

Widget _settingsApp(
  AppDatabase db,
  MemoProvider provider, {
  ThemeProvider? themeProvider,
}) {
  return MultiProvider(
    providers: [
      Provider<AppDatabase>.value(value: db),
      ChangeNotifierProvider<MemoProvider>.value(value: provider),
      ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider ?? ThemeProvider(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The settings screen reads the version on start.
    PackageInfo.setMockInitialValues(
      appName: 'kMemo',
      packageName: 'com.marotoweb.kmemo',
      version: '0.3.2',
      buildNumber: '25',
      buildSignature: '',
    );
  });

  test('wipeAllData removes notes, blocks and tombstones', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now().toUtc();
    final memo = Memo(
      uuid: 'memo-1',
      title: 'Note',
      createdAt: now,
      updatedAt: now,
      isSynced: true,
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
    await db.saveMemoWithBlocks(memo, [
      Block(
        id: 0,
        uuid: 'block-1',
        memoUuid: memo.uuid,
        type: BlockType.text,
        content: const {'text': 'body'},
        sortOrder: 0,
        isDeleted: false,
      ),
    ], writeSyncBookkeeping: true);
    await db.recordTombstone(
      uuid: 'deleted-1',
      deletedAt: now,
      remoteFileId: 'kmemo/notes/deleted-1.json',
    );

    await db.wipeAllData();

    expect(await db.select(db.memos).get(), isEmpty);
    expect(await db.select(db.blocks).get(), isEmpty);
    expect(await db.getTombstones(), isEmpty);
  });

  testWidgets('the danger zone deletes every note after confirmation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late AppDatabase db;
    late MemoProvider provider;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      provider = MemoProvider(db);
      await provider.createNewMemo();
      await provider.createNewMemo();
      // One of them pretends to have a remote copy already.
      final rows = await db.select(db.memos).get();
      await db.saveMemoWithBlocks(
        rows.first.copyWith(
          remoteFileId: const Value('kmemo/notes/remote-1.json'),
          isSynced: true,
        ),
        const [],
        writeSyncBookkeeping: true,
      );
    });
    addTearDown(db.close);

    await tester.pumpWidget(_settingsApp(db, provider));
    await _settleDatabase(tester);

    // The section is the last one on the page.
    await tester.scrollUntilVisible(find.text('Delete all notes'), 400);
    await tester.pump();
    expect(find.text('DANGER ZONE'), findsOneWidget);
    expect(find.text('Delete all app data'), findsOneWidget);

    // Both actions are marked in red.
    expect(
      tester.widget<Text>(find.text('Delete all notes')).style?.color,
      Colors.red,
    );
    expect(
      tester.widget<Text>(find.text('Delete all app data')).style?.color,
      Colors.red,
    );

    // Opening the dialog explains the consequence and does nothing until the
    // red action is confirmed.
    await tester.tap(find.text('Delete all notes'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all notes?'), findsOneWidget);
    expect(
      find.textContaining('Nothing is sent to the server'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(provider.memos.length, 2);

    await tester.tap(find.text('Delete all notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    await _settleDatabase(tester);
    final remaining = await tester.runAsync(() => db.select(db.memos).get());
    expect(remaining, isEmpty);
    // The remote copies are not marked: no tombstone is recorded for the note
    // that had one.
    final tombstones = await tester.runAsync(() => db.getTombstones());
    expect(tombstones, isEmpty);
  });

  testWidgets('deleting all app data empties the database and the settings', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 2,
      'home_sort_mode': 'custom',
    });
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The logs live in the app directories: point path_provider at a temporary
    // folder so the reset can be checked without touching the real ones.
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory logsDir;
    await tester.runAsync(() async {
      logsDir = await Directory.systemTemp.createTemp('kmemo_danger_zone');
      await File('${logsDir.path}/sync.log').writeAsString('sync');
      await File('${logsDir.path}/widget_debug.log').writeAsString('widget');
    });
    addTearDown(() => logsDir.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => logsDir.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null),
    );

    late AppDatabase db;
    late MemoProvider provider;
    late ThemeProvider themeProvider;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      provider = MemoProvider(db);
      themeProvider = ThemeProvider();
      await provider.createNewMemo();
    });
    addTearDown(db.close);
    // Start from a non-default setting so the reset is visible.
    await themeProvider.setAutoWrap(false);

    await tester.pumpWidget(
      _settingsApp(db, provider, themeProvider: themeProvider),
    );
    await _settleDatabase(tester);

    await tester.scrollUntilVisible(find.text('Delete all app data'), 400);
    await tester.pump();
    await tester.tap(find.text('Delete all app data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all app data?'), findsOneWidget);
    expect(
      find.textContaining('the sync configuration (token and passphrase)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();
    await _settleDatabase(tester);

    final remaining = await tester.runAsync(() => db.select(db.memos).get());
    expect(remaining, isEmpty);
    // The settings go back to a fresh install, in memory and on disk: nothing
    // is written back.
    expect(themeProvider.autoWrap, isTrue);
    expect(themeProvider.strikethroughChecked, isTrue);
    expect(themeProvider.showLinkPreviews, isTrue);
    expect(themeProvider.widgetBgOpacity, 1.0);
    expect(themeProvider.widgetCardOpacity, 1.0);
    expect(themeProvider.themeMode, ThemeMode.system);
    expect(themeProvider.locale, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);

    // A fresh install has no diagnostics either.
    final logsExist = await tester.runAsync(
      () async => [
        await File('${logsDir.path}/sync.log').exists(),
        await File('${logsDir.path}/widget_debug.log').exists(),
      ],
    );
    expect(logsExist, [false, false]);
  });
}
