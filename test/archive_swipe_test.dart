// test/archive_swipe_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/l10n/app_localizations.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/providers/theme_provider.dart';
import 'package:kmemo/ui/screens/archive_screen.dart';
import 'package:kmemo/ui/widgets/memo_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Drags the card by [dx] pixels, crossing the recogniser slop in two steps.
Future<void> _swipe(WidgetTester tester, Finder finder, double dx) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  final sign = dx < 0 ? -1.0 : 1.0;
  await gesture.moveBy(Offset(40 * sign, 0));
  await tester.pump();
  await gesture.moveBy(Offset(dx, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('swiping an archived note to the left moves it to the trash', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late AppDatabase db;
    late MemoProvider provider;
    late String uuid;

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      provider = MemoProvider(db);
      final memo = await provider.createNewMemo();
      uuid = memo.uuid;
      await provider.archiveMemoStatus(uuid, true);
      await _waitFor(() => provider.archivedMemos.isNotEmpty);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MemoProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ArchiveScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MemoCard), findsOneWidget);

    // A left swipe is the delete action; it is a soft delete, so the note
    // leaves the archive but stays recoverable from the trash.
    await _swipe(tester, find.byType(MemoCard), -400);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(
      () => _waitFor(
        () => provider.memos.any((m) => m.uuid == uuid && m.isDeleted),
      ),
    );

    final memo = provider.memos.firstWhere((m) => m.uuid == uuid);
    expect(memo.isDeleted, isTrue);
    expect(memo.isArchived, isTrue);
    expect(find.text('Note moved to trash'), findsOneWidget);

    // Let the snackbar timeout and the sync debounce fire.
    await tester.pump(const Duration(seconds: 9));
    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
  });

  testWidgets('swiping an archived note to the right unarchives it', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late AppDatabase db;
    late MemoProvider provider;
    late String uuid;

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      provider = MemoProvider(db);
      final memo = await provider.createNewMemo();
      uuid = memo.uuid;
      await provider.archiveMemoStatus(uuid, true);
      await _waitFor(() => provider.archivedMemos.isNotEmpty);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MemoProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ArchiveScreen(),
        ),
      ),
    );
    await tester.pump();

    await _swipe(tester, find.byType(MemoCard), 400);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(
      () => _waitFor(
        () => provider.memos.any((m) => m.uuid == uuid && !m.isArchived),
      ),
    );

    final memo = provider.memos.firstWhere((m) => m.uuid == uuid);
    expect(memo.isArchived, isFalse);
    expect(memo.isDeleted, isFalse);

    await tester.pump(const Duration(seconds: 9));
    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
  });
}
