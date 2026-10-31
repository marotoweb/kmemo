// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/providers/theme_provider.dart';
import 'package:kmemo/services/kdrive_storage.dart';
import 'package:kmemo/main.dart';

void main() {
  testWidgets('kMemo smoke test', (WidgetTester tester) async {
    // Creates an isolated in-memory Drift instance exclusive to the test environment
    final database = AppDatabase();
  final storage = KDriveStorage();

    // Builds the app injecting the mocks needed to simulate the main.dart tree
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
        child:
            const KMemoApp(), // Fix: use the correct class defined in main.dart
      ),
    );

    // Waits for initial frames processing and async DB loading
    await tester.pump();

    // Verify the app title appears in the AppBar
    expect(find.text('kMemo'), findsOneWidget);

    // Verify the add button (+) exists on the home screen
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
