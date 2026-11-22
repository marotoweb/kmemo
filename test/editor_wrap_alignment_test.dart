// test/editor_wrap_alignment_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/l10n/app_localizations.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/providers/theme_provider.dart';
import 'package:kmemo/ui/screens/memo_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _body =
    '- [All] **A tap in the empty part of a note clears the text selection:** '
    'the editor field is only as tall as its text, so a tap below the last line '
    'landed on the background, which only asked for focus. After selecting a '
    'word, the selection and its handles stayed on screen and every tap in the '
    'empty part of the note kept them there. A tap anywhere in the note now '
    'collapses the selection and places the caret at the closest posição.';

/// Line index of every character, derived from the vertical position of the
/// glyph (or of the caret) at that offset.
List<int> _lines(Iterable<double> tops) {
  final distinct = tops.toSet().toList()..sort();
  return [for (final top in tops) distinct.indexOf(top)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the caret and the visible text break lines at the same points', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late AppDatabase db;
    late Memo memo;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.now().toUtc();
      memo = Memo(
        uuid: 'wrap-check',
        title: 'Wrap',
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
      await db.saveMemoWithBlocks(memo, [
        Block(
          id: 0,
          uuid: 'body-block',
          memoUuid: memo.uuid,
          type: BlockType.text,
          content: const {'text': _body},
          sortOrder: 0,
          isDeleted: false,
        ),
      ], writeSyncBookkeeping: true);
    });
    addTearDown(db.close);
    final provider = MemoProvider(db);

    // Widths where the old layout broke a line at a different word in the two
    // layers (the field keeps the caret width, the overlay used to take it).
    for (final width in [352.0, 368.0, 384.0, 400.0]) {
      tester.view.physicalSize = Size(width, 900);
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
            home: MemoDetailScreen(memo: memo),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      final overlay = tester.renderObject<RenderParagraph>(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == _body,
        ),
      );
      final field = tester.allRenderObjects
          .whereType<RenderEditable>()
          .firstWhere((editable) => editable.text?.toPlainText() == _body);

      final overlayTops = <double>[];
      final fieldTops = <double>[];
      for (var i = 0; i < _body.length; i++) {
        final boxes = overlay.getBoxesForSelection(
          TextSelection(baseOffset: i, extentOffset: i + 1),
        );
        if (boxes.isEmpty) continue;
        overlayTops.add((boxes.first.top * 2).roundToDouble() / 2);
        fieldTops.add(
          (field.getLocalRectForCaret(TextPosition(offset: i)).top * 2)
                  .roundToDouble() /
              2,
        );
      }

      expect(
        _lines(fieldTops),
        _lines(overlayTops),
        reason:
            'at width $width the caret and the drawn text must wrap on the '
            'same words',
      );
    }
  });
}
