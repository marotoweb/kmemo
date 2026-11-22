// test/memo_detail_search_highlight_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/l10n/app_localizations.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/providers/theme_provider.dart';
import 'package:kmemo/ui/screens/memo_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background colours painted by the text spans currently on screen.
List<Color> _tints(WidgetTester tester) {
  final colours = <Color>[];
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.style?.backgroundColor != null) {
        colours.add(span.style!.backgroundColor!);
      }
      return true;
    });
  }
  return colours;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the note search tints every match and keeps the field focused', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // A phone-sized window: the editor toolbar does not fit in the default
    // 800x600 test surface and would overflow.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late AppDatabase db;
    late MemoProvider provider;
    late Memo memo;

    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // The note is written straight to the database, before the provider
      // exists, so the editor reads it from there (the provider caches what it
      // has read).
      final now = DateTime.now().toUtc();
      memo = Memo(
        uuid: 'memo-search',
        title: 'Search',
        createdAt: now,
        updatedAt: now,
        isSynced: false,
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
      await db.saveMemoWithBlocks(
        memo,
        [
          Block(
            id: 0,
            uuid: 'body-block',
            memoUuid: memo.uuid,
            type: BlockType.text,
            content: const {'text': 'hello world hello'},
            sortOrder: 0,
            isDeleted: false,
          ),
        ],
        writeSyncBookkeeping: true,
      );
      provider = MemoProvider(db);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider<MemoProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MemoDetailScreen(memo: memo, isNew: false),
        ),
      ),
    );
    // The blocks are read from the real database, which does not complete
    // inside the fake async zone.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // The block text reached the editor.
    expect(find.text('hello world hello'), findsWidgets);

    // Open "Find in note" from the three dots menu.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find in note'));
    await tester.pumpAndSettle();

    final searchField = find.byKey(const ValueKey('search_field'));
    expect(searchField, findsOneWidget);

    // Typing tints both occurrences after the debounce, without moving the
    // caret: the first match is the one in focus.
    await tester.enterText(searchField, 'hello');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('1 of 2'), findsOneWidget);
    // Both occurrences are tinted, the one in focus with its own colour.
    expect(_tints(tester).toSet().length, 2);

    EditableText searchEditable() => tester.widget<EditableText>(
      find.descendant(of: searchField, matching: find.byType(EditableText)),
    );
    expect(searchEditable().focusNode.hasFocus, isTrue);

    // Enter and the arrows move between the matches and leave the focus in the
    // search field, so the query can keep growing.
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(searchEditable().focusNode.hasFocus, isTrue);
    expect(_tints(tester).toSet().length, 2);

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    expect(searchEditable().focusNode.hasFocus, isTrue);

    // An IME can commit a conversion without changing the text: the marks have
    // to follow the committed word, not the previous query.
    final controller = searchEditable().controller;
    controller.value = const TextEditingValue(
      text: 'zzz',
      composing: TextRange(start: 0, end: 3),
    );
    await tester.pump();
    expect(find.text('1 of 2'), findsOneWidget);

    controller.value = const TextEditingValue(text: 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('1 of 2'), findsNothing);
    expect(_tints(tester), isEmpty);

    // Let the widget-update debounce fire before the tree is torn down.
    await tester.pump(const Duration(seconds: 1));
  });
}
