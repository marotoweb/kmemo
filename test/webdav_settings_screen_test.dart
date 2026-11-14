// test/webdav_settings_screen_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/l10n/app_localizations.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/services/kdrive_storage.dart';
import 'package:kmemo/services/webdav_storage.dart';
import 'package:kmemo/ui/screens/sync_settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('selecting WebDAV shows its configuration form', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    late AppDatabase db;
    late KDriveStorage kdrive;
    late WebDAVStorage webdav;

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      kdrive = KDriveStorage();
      webdav = WebDAVStorage();
      // Both storages start unconfigured; only the UI is under test here.
      await kdrive.init(applyEncryption: false);
      await webdav.init(applyEncryption: false);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider(
            create: (_) => MemoProvider(db, storage: kdrive),
          ),
          Provider<KDriveStorage>.value(value: kdrive),
          Provider<WebDAVStorage>.value(value: webdav),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SyncSettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    // kDrive is the first protocol.
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.text('Server URL'), findsNothing);

    await tester.tap(find.text('WebDAV').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Destination folder'), findsOneWidget);

    // The action buttons live below the fold: the ListView builds children
    // lazily, so scroll to them before asserting.
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();

    expect(find.text('Test connection'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.runAsync(db.close);
  });

  testWidgets('a configured WebDAV shows the same status card as kDrive', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    late AppDatabase db;
    late KDriveStorage kdrive;
    late WebDAVStorage webdav;

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      kdrive = KDriveStorage();
      webdav = WebDAVStorage();
      await kdrive.init(applyEncryption: false);
      await webdav.init(applyEncryption: false);
      await webdav.configure(
        baseUrl: 'https://cloud.example.com/dav/',
        username: 'maria',
        password: 'secret',
        folder: 'kmemo/notes',
        encryptionEnabled: false,
      );
    });

    Widget buildApp() => MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider(
          create: (_) => MemoProvider(db, storage: webdav),
        ),
        Provider<KDriveStorage>.value(value: kdrive),
        Provider<WebDAVStorage>.value(value: webdav),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SyncSettingsScreen(),
      ),
    );
    await tester.pumpWidget(buildApp());
    await tester.pump();

    // The screen opens on the active backend (WebDAV).
    expect(find.text('Sync active'), findsOneWidget);
    expect(find.textContaining('Server URL: https://cloud.example.com/dav/'),
        findsOneWidget);
    expect(find.textContaining('Destination folder: kmemo/notes'),
        findsOneWidget);
    expect(find.textContaining('Last sync: Never'), findsOneWidget);

    // The status card reflects a completed sync. Re-pumping the same tree
    // rebuilds the card the way the screen's setState does after a sync.
    await tester.runAsync(() async {
      webdav.markSyncedNow();
    });
    // Switching segments calls setState, the same rebuild the screen does
    // when a sync finishes.
    await tester.tap(find.text('kDrive').first);
    await tester.pump();
    await tester.tap(find.text('WebDAV').first);
    await tester.pump();
    expect(find.textContaining('Last sync: Just now'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.runAsync(db.close);
  });
}
