// test/home_app_bar_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/main.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/providers/theme_provider.dart';
import 'package:kmemo/services/kdrive_storage.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the app with an unconfigured backend, so the pull answers instead of
/// reaching the network.
Future<MemoProvider> _pumpHome(WidgetTester tester, {required bool withNote}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final storage = KDriveStorage();
  final provider = MemoProvider(database, storage: storage);

  // The note is inserted before the widget is built: the home stream then
  // renders it on the first frame, without waiting for an extra event.
  if (withNote) {
    await tester.runAsync(() => provider.createNewMemo());
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<MemoProvider>.value(value: provider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<KDriveStorage>.value(value: storage),
      ],
      child: const KMemoApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return provider;
}

Future<void> _pullDown(WidgetTester tester) async {
  await tester.drag(find.byType(RefreshIndicator), const Offset(0, 320));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pulling the list down asks for a backend when there is one', (
    WidgetTester tester,
  ) async {
    await _pumpHome(tester, withNote: true);
    expect(find.byType(ReorderableListView), findsOneWidget);

    await _pullDown(tester);

    // Without a configured backend the pull still answers, instead of doing
    // nothing and leaving the user to guess why nothing happened.
    expect(find.text('No remote storage is configured'), findsOneWidget);
  });

  testWidgets('an empty list can be pulled too', (WidgetTester tester) async {
    await _pumpHome(tester, withNote: false);
    expect(find.byType(ReorderableListView), findsNothing);

    await _pullDown(tester);

    // The empty state has no scroll view of its own: without the full-height
    // one the gesture does nothing exactly when the user wants to fetch notes.
    expect(find.text('No remote storage is configured'), findsOneWidget);
  });

  testWidgets('sort icon keeps its position when the search opens', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase();
    final storage = KDriveStorage();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          ChangeNotifierProvider<MemoProvider>(
            create: (_) => MemoProvider(database, storage: storage),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          Provider<KDriveStorage>.value(value: storage),
        ],
        child: const KMemoApp(),
      ),
    );
    await tester.pump();

    // Closed search: only the search and sort actions are visible.
    final sortBefore = tester.getCenter(find.byIcon(Icons.sort));
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    // Open search: the close button sits before the sort icon, which keeps
    // the exact same position as in the closed state.
    final sortAfter = tester.getCenter(find.byIcon(Icons.sort));
    final closeAfter = tester.getCenter(find.byIcon(Icons.close));
    expect(sortAfter.dx, sortBefore.dx);
    expect(closeAfter.dx, lessThan(sortAfter.dx));
  });
}
