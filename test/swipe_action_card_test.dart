import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/ui/widgets/swipe_action_card.dart';

void main() {
  // The card is 400 logical pixels wide in these tests.
  const cardWidth = 400.0;

  Future<void> pumpCard(
    WidgetTester tester,
    List<DismissDirection> dismissed,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: cardWidth,
              child: SwipeActionCard(
                dismissKey: const Key('memo'),
                onDismissed: dismissed.add,
                child: const SizedBox(
                  height: 80,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a small fast fling does not dismiss the card', (tester) async {
    final dismissed = <DismissDirection>[];
    await pumpCard(tester, dismissed);

    // Short distance (60 px) with a high velocity: Dismissible would dismiss
    // this on its own, because it ignores the threshold for fast flings.
    await tester.fling(find.byType(SwipeActionCard), const Offset(60, 0), 3000);
    await tester.pumpAndSettle();

    expect(dismissed, isEmpty);
  });

  testWidgets('a near-complete drag dismisses towards the end', (tester) async {
    final dismissed = <DismissDirection>[];
    await pumpCard(tester, dismissed);

    await tester.drag(
      find.byType(SwipeActionCard),
      const Offset(cardWidth * 0.98, 0),
    );
    await tester.pumpAndSettle();

    expect(dismissed, [DismissDirection.startToEnd]);
  });

  testWidgets('a near-complete drag dismisses towards the start', (
    tester,
  ) async {
    final dismissed = <DismissDirection>[];
    await pumpCard(tester, dismissed);

    await tester.drag(
      find.byType(SwipeActionCard),
      const Offset(-cardWidth * 0.98, 0),
    );
    await tester.pumpAndSettle();

    expect(dismissed, [DismissDirection.endToStart]);
  });

  testWidgets('a drag below the threshold does not dismiss', (tester) async {
    final dismissed = <DismissDirection>[];
    await pumpCard(tester, dismissed);

    await tester.drag(
      find.byType(SwipeActionCard),
      const Offset(cardWidth * 0.5, 0),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isEmpty);
  });
}
