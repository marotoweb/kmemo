// test/swipe_action_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/ui/widgets/swipe_action_card.dart';

/// The card lives inside a [ListView] in the app, and the scroll view's
/// vertical drag recogniser competing in the gesture arena is what makes a
/// diagonal drag keep scrolling instead of grabbing the card. These tests use
/// the same layout so they exercise that competition.
Widget _card({
  required ValueChanged<DismissDirection> onDismissed,
  DismissDirection direction = DismissDirection.horizontal,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: [
          Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: SwipeActionCard(
                dismissKey: const Key('note'),
                direction: direction,
                onDismissed: onDismissed,
                child: const SizedBox(height: 100),
              ),
            ),
          ),
          const SizedBox(height: 2000),
        ],
      ),
    ),
  );
}

/// Swipes the card horizontally by [dx] pixels.
///
/// The first move crosses the recognizer's horizontal slop (twice the normal
/// touch slop), so the card starts following the finger from there. Doing it
/// in two steps is what a real drag looks like.
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
  testWidgets('a full swipe fires the action and removes the card', (
    WidgetTester tester,
  ) async {
    var fired = 0;
    var visible = true;
    late StateSetter setListState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              Center(
                child: SizedBox(
                  width: 300,
                  height: 400,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      setListState = setState;
                      return visible
                          ? SwipeActionCard(
                              dismissKey: const Key('note'),
                              onDismissed: (_) {
                                fired++;
                                // Mimics the asynchronous database write: the
                                // card leaves the list only after the action.
                                Future<void>.delayed(
                                  const Duration(milliseconds: 50),
                                  () => setListState(() => visible = false),
                                );
                              },
                              child: const SizedBox(height: 100),
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );

    await _swipe(tester, find.byKey(const Key('note')), 300);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(fired, 1);
    expect(find.byKey(const Key('note')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short swipe does not fire the action', (
    WidgetTester tester,
  ) async {
    var fired = 0;

    await tester.pumpWidget(_card(onDismissed: (_) => fired++));

    await _swipe(tester, find.byKey(const Key('note')), 60);
    await tester.pumpAndSettle();

    expect(fired, 0);
    expect(find.byKey(const Key('note')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the threshold is 35% of the card width', (
    WidgetTester tester,
  ) async {
    var fired = 0;

    await tester.pumpWidget(_card(onDismissed: (_) => fired++));

    // 30% of the 300px card: rejected.
    await _swipe(tester, find.byKey(const Key('note')), 90);
    await tester.pumpAndSettle();
    expect(fired, 0);

    // 40%: accepted.
    await _swipe(tester, find.byKey(const Key('note')), 120);
    await tester.pumpAndSettle();
    expect(fired, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a diagonal drag scrolls the list instead of the card', (
    WidgetTester tester,
  ) async {
    var fired = 0;

    await tester.pumpWidget(_card(onDismissed: (_) => fired++));

    final before = tester.getTopLeft(find.byKey(const Key('note')));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('note'))),
    );
    // A scroll flicked off-axis: as much vertical as horizontal movement.
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(40, 40));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // The card must not have moved at all: the scroll view takes the gesture.
    expect(tester.getTopLeft(find.byKey(const Key('note'))), before);
    expect(fired, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a vertical drag scrolls the list and leaves the card alone', (
    WidgetTester tester,
  ) async {
    var fired = 0;

    await tester.pumpWidget(_card(onDismissed: (_) => fired++));

    final before = tester.getTopLeft(find.byKey(const Key('note')));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.byKey(const Key('note')));

    expect(after.dy, lessThan(before.dy)); // the list scrolled
    expect(after.dx, before.dx); // the card did not slide sideways
    expect(fired, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a drag in the disabled direction does nothing', (
    WidgetTester tester,
  ) async {
    var fired = 0;

    await tester.pumpWidget(
      _card(
        onDismissed: (_) => fired++,
        direction: DismissDirection.startToEnd,
      ),
    );

    final before = tester.getTopLeft(find.byKey(const Key('note')));
    await _swipe(tester, find.byKey(const Key('note')), -300);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(const Key('note'))), before);
    expect(fired, 0);
  });
}
