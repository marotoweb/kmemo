// lib/ui/widgets/swipe_action_card.dart

import 'package:flutter/material.dart';

/// Card wrapper that runs [onDismissed] only after a near-complete swipe.
///
/// A plain [Dismissible] also dismisses on a fast fling, no matter how little
/// the card moved, which archived notes on the home screen and restored notes
/// in the trash by accident after a small swipe. The pointer travel is recorded
/// here and [Dismissible.confirmDismiss] rejects any dismissal that did not
/// drag the card at least [threshold] of its width.
///
/// The recorded travel is used instead of the [Dismissible] progress because
/// the progress is already 1.0 by the time `confirmDismiss` runs (the dismiss
/// animation has completed), so it cannot tell a long drag from a fast fling.
class SwipeActionCard extends StatefulWidget {
  const SwipeActionCard({
    super.key,
    required this.dismissKey,
    required this.child,
    required this.onDismissed,
    this.direction = DismissDirection.horizontal,
    this.threshold = 0.9,
    this.background,
    this.secondaryBackground,
  });

  /// Key for the inner [Dismissible]; must be unique per item (the memo uuid).
  final Key dismissKey;

  final Widget child;

  final void Function(DismissDirection direction) onDismissed;

  final DismissDirection direction;

  /// Fraction of the card width the finger must travel for the swipe to count.
  final double threshold;

  /// Shown behind the card while it is dragged towards the end (right in LTR).
  final Widget? background;

  /// Shown behind the card while it is dragged towards the start (left in LTR).
  final Widget? secondaryBackground;

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

class _SwipeActionCardState extends State<SwipeActionCard> {
  int? _pointer;
  double _startX = 0;
  double _distance = 0;

  /// Direction of the current drag, used to pick the background to reveal.
  late DismissDirection _dragDirection = _initialDirection;

  DismissDirection get _initialDirection =>
      widget.direction == DismissDirection.horizontal
      ? DismissDirection.startToEnd
      : widget.direction;

  void _handleUpdate(DismissUpdateDetails details) {
    final direction = details.direction;
    if (direction == _dragDirection) return;
    // Only the revealed background changes; the pointer travel keeps counting
    // from the same origin, exactly like the Dismissible drag extent.
    setState(() => _dragDirection = direction);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;

        // The reveal background is painted behind the card instead of using
        // the Dismissible background/secondaryBackground: Dismissible clips
        // those with a straight edge at the card's leading edge, which leaves
        // a white gap and a white wedge at the card's rounded corners.
        final background = _dragDirection == DismissDirection.endToStart
            ? (widget.secondaryBackground ?? widget.background)
            : (widget.background ?? widget.secondaryBackground);

        final card = Listener(
          onPointerDown: (event) {
            // Always restart tracking: a missed pointer up (e.g. the card
            // unmounting during a reorder) must not disable swiping.
            _pointer = event.pointer;
            _startX = event.position.dx;
            _distance = 0;
          },
          onPointerMove: (event) {
            if (event.pointer != _pointer) return;
            _distance = event.position.dx - _startX;
          },
          onPointerUp: (event) {
            // Keep the distance: confirmDismiss runs after the pointer up.
            if (event.pointer == _pointer) _pointer = null;
          },
          onPointerCancel: (event) {
            if (event.pointer == _pointer) _pointer = null;
          },
          child: Dismissible(
            key: widget.dismissKey,
            direction: widget.direction,
            dismissThresholds: {
              DismissDirection.startToEnd: widget.threshold,
              DismissDirection.endToStart: widget.threshold,
            },
            onUpdate: _handleUpdate,
            confirmDismiss: (_) async {
              if (cardWidth <= 0) return false;
              return _distance.abs() >= cardWidth * widget.threshold;
            },
            onDismissed: widget.onDismissed,
            child: widget.child,
          ),
        );

        // StackFit.passthrough gives the card the same constraints it had
        // before being wrapped, so it still fills the row and receives the
        // drag. The background keeps its own slot at all times: changing the
        // tree shape would remount the Dismissible mid-dismissal.
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(child: background ?? const SizedBox.shrink()),
            card,
          ],
        );
      },
    );
  }
}
