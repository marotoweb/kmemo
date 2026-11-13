// lib/ui/widgets/swipe_action_card.dart

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Card wrapper that runs [onDismissed] only after a deliberate swipe.
///
/// A plain [Dismissible] accepts the drag as soon as the pointer travels one
/// touch slop, so a diagonal scroll grabbed the card and revealed the action
/// by accident, and a fast fling dismissed it no matter how little it moved.
///
/// This wrapper owns the horizontal drag instead:
///  * the gesture is accepted only after twice the normal horizontal slop and
///    when the card moved clearly more sideways than vertically (see
///    [_GuardedHorizontalDragRecognizer]), so a vertical or diagonal scroll
///    keeps scrolling the list and never touches the card;
///  * the action runs only when the card itself was dragged [threshold] of
///    its width, measured from where the drag was recognised.
///
/// The card is moved with a [Transform]; [onDismissed] runs on release and the
/// card disappears when the list rebuilds after the database write. It is
/// never removed by Flutter, so there is no "dismissed widget still in the
/// tree" failure to avoid.
class SwipeActionCard extends StatefulWidget {
  const SwipeActionCard({
    super.key,
    required this.dismissKey,
    required this.child,
    required this.onDismissed,
    this.direction = DismissDirection.horizontal,
    this.threshold = 0.35,
    this.background,
    this.secondaryBackground,
  });

  /// Key applied to the card itself, so a list can find the entry by note id.
  final Key dismissKey;
  final Widget child;
  final void Function(DismissDirection direction) onDismissed;

  /// Which horizontal drags move the card.
  final DismissDirection direction;

  /// Fraction of the card width that must be dragged to run [onDismissed].
  ///
  /// 35% is a comfortable one-thumb travel on a full-width card (about 370 px
  /// on a 1080-wide screen, plus the slop consumed before the drag starts).
  /// It is safe because the drag itself is only accepted when the movement is
  /// clearly horizontal: a scroll can never reach this offset.
  final double threshold;

  /// Painted behind the card when it is dragged to the right.
  final Widget? background;

  /// Painted behind the card when it is dragged to the left.
  final Widget? secondaryBackground;

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

/// Horizontal drag that ignores diagonal movement.
///
/// [HorizontalDragGestureRecognizer] accepts as soon as the pointer moves one
/// touch slop sideways, without looking at the vertical movement. Inside a
/// scrolling list that is too eager: a scroll flicked slightly off-axis was
/// taken as a swipe. Requiring twice the slop and a clearly horizontal
/// direction lets the scroll view's vertical recogniser win those gestures.
class _GuardedHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  Offset _down = Offset.zero;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _down = event.position;
    super.addAllowedPointer(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final slop = computeHitSlop(pointerDeviceKind, gestureSettings);
    final moved = lastPosition.global - _down;
    return moved.dx.abs() >= slop * 2 &&
        moved.dx.abs() >= moved.dy.abs() * 1.5;
  }
}

class _SwipeActionCardState extends State<SwipeActionCard>
    with SingleTickerProviderStateMixin {
  /// Horizontal displacement of the card in pixels; positive is to the right.
  double _offset = 0;

  /// Where the drag was recognised, in global coordinates.
  double _dragStartX = 0;

  /// Width of the card, captured on every layout.
  double _width = 0;

  /// Animates the card back to its place after a short or rejected swipe.
  late final AnimationController _settleController;
  Animation<double>? _settleAnimation;

  /// Blocks a second action while the note is being removed from the list.
  bool _actionFired = false;
  Timer? _resetTimer;

  bool get _allowsRight =>
      widget.direction == DismissDirection.horizontal ||
      widget.direction == DismissDirection.startToEnd;

  bool get _allowsLeft =>
      widget.direction == DismissDirection.horizontal ||
      widget.direction == DismissDirection.endToStart;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(_onSettleTick);
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _settleController.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final animation = _settleAnimation;
    if (animation == null) return;
    setState(() => _offset = animation.value);
  }

  void _settleBack() {
    if (_offset == 0) return;
    _settleAnimation = Tween<double>(begin: _offset, end: 0).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOut),
    );
    _settleController.forward(from: 0);
  }

  void _handleDragStart(DragStartDetails details) {
    if (_actionFired) return;
    _settleController.stop();
    _settleAnimation = null;
    // DragStartBehavior.start: the drag is measured from the point where it
    // was recognised, so the card starts moving from its resting place.
    _dragStartX = details.globalPosition.dx;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_actionFired || _width <= 0) return;
    var next = details.globalPosition.dx - _dragStartX;
    if (next > 0 && !_allowsRight) next = 0;
    if (next < 0 && !_allowsLeft) next = 0;
    next = next.clamp(-_width, _width);
    if (next == _offset) return;
    setState(() => _offset = next);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_actionFired) return;
    final width = _width;
    final offset = _offset;
    if (width > 0 && offset.abs() >= width * widget.threshold) {
      _fireAction(
        offset > 0 ? DismissDirection.startToEnd : DismissDirection.endToStart,
      );
    }
    _settleBack();
  }

  void _fireAction(DismissDirection direction) {
    if (_actionFired) return;
    _actionFired = true;
    widget.onDismissed(direction);
    // The list rebuild after the database write removes this card. If the
    // action failed and the card is still here, allow swiping again.
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _actionFired = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;

        // The reveal background is painted behind the card instead of using
        // a Dismissible background: those are clipped with a straight edge at
        // the card's leading edge, which leaves a white gap and a white wedge
        // at the card's rounded corners.
        final background = _offset < 0
            ? (widget.secondaryBackground ?? widget.background)
            : (widget.background ?? widget.secondaryBackground);

        // Dim the reveal until the drag is far enough to act: lifting the
        // finger before that does nothing, so the card tells the user when it
        // is armed instead of leaving them to guess.
        final armed =
            _width > 0 && _offset.abs() >= _width * widget.threshold;

        return Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: armed ? 1 : 0.55,
                  child: background ?? const SizedBox.shrink(),
                ),
              ),
            ),
            RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                _GuardedHorizontalDragRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _GuardedHorizontalDragRecognizer
                    >(_GuardedHorizontalDragRecognizer.new, (recognizer) {
                      recognizer
                        ..dragStartBehavior = DragStartBehavior.start
                        ..onStart = _handleDragStart
                        ..onUpdate = _handleDragUpdate
                        ..onEnd = _handleDragEnd
                        ..onCancel = _settleBack;
                    }),
              },
              child: Transform.translate(
                offset: Offset(_offset, 0),
                child: KeyedSubtree(key: widget.dismissKey, child: widget.child),
              ),
            ),
          ],
        );
      },
    );
  }
}
