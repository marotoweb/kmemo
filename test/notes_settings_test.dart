// test/notes_settings_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/l10n/app_localizations.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/providers/theme_provider.dart';
import 'package:kmemo/ui/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the notes card opens the editor and image options', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    late AppDatabase db;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    addTearDown(db.close);

    final themeProvider = ThemeProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider(create: (_) => MemoProvider(db)),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Notes'), 400);
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    // The editor switches moved to this page.
    expect(find.text('EDITOR'), findsOneWidget);
    expect(find.text('Automatic line wrapping'), findsOneWidget);

    // Image options, with 1920 and "Ask" as the defaults.
    expect(find.text('IMAGES'), findsOneWidget);
    expect(find.text('Maximum size'), findsOneWidget);
    expect(find.text('1920 px'), findsOneWidget);
    expect(find.text('Ask'), findsOneWidget);

    await tester.tap(find.text('1920 px'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1280 px').last);
    await tester.pumpAndSettle();
    expect(themeProvider.imageMaxSide, 1280);

    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Never resize').last);
    await tester.pumpAndSettle();
    expect(themeProvider.imageResizeMode, ImageResizeMode.never);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('image_max_side'), 1280);
    expect(prefs.getString('image_resize_mode'), 'never');
  });
}
