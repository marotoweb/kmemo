// test/simple_markdown_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/ui/widgets/simple_markdown.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('headings, bullets and bold lose their markers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SimpleMarkdown(
          '### ✨ New\n\n'
          '- **A sync button:** runs a pass.\n'
          '- plain item\n\n'
          '### 🐛 Fixes\n'
          '- fixed',
        ),
      ),
    );

    expect(find.textContaining('###'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('✨ New'), findsOneWidget);
    expect(find.textContaining('A sync button:'), findsOneWidget);
    expect(find.textContaining('plain item'), findsOneWidget);

    // One bullet per list item.
    expect(find.text('•'), findsNWidgets(3));
  });

  testWidgets('a link keeps its label and reports the URL', (
    WidgetTester tester,
  ) async {
    Uri? tapped;
    await tester.pumpWidget(
      _wrap(
        SimpleMarkdown(
          'See [issue #2](https://example.com/2) for details.',
          onLinkTap: (uri) => tapped = uri,
        ),
      ),
    );

    expect(find.textContaining('['), findsNothing);
    expect(find.textContaining('issue #2'), findsOneWidget);

    await tester.tapOnText(find.textRange.ofSubstring('issue #2'));
    expect(tapped, Uri.parse('https://example.com/2'));
  });

  testWidgets('inline code and italics render as text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const SimpleMarkdown('Use `flutter test` and *never* skip it.')),
    );

    expect(find.textContaining('`'), findsNothing);
    expect(find.textContaining('flutter test'), findsOneWidget);
    expect(find.textContaining('never'), findsOneWidget);
  });

  testWidgets('numbered items keep their number', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const SimpleMarkdown('1. first\n2. second')));

    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.textContaining('first'), findsOneWidget);
  });
}
