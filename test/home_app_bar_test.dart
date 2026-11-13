// test/home_app_bar_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/main.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/providers/theme_provider.dart';
import 'package:kmemo/services/kdrive_storage.dart';

void main() {
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
