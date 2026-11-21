// lib/ui/widgets/sync_progress_bar.dart

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Progress card shown at the bottom of a page while a sync runs.
///
/// The home screen and the sync settings use this same widget, so the feedback
/// is identical wherever a manual cycle can take a while: a title, the wave and
/// the step count. The bar is always drawn as a wave; the empty part is the dim
/// track and the filled part lights up as it advances. With the system "remove
/// animations" setting the wave is drawn still.
class SyncProgressBar extends StatelessWidget {
  const SyncProgressBar({
    super.key,
    required this.title,
    required this.done,
    required this.total,
  });

  final String title;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        // Translucent and blurred on purpose: it floats over the note list, so
        // the notes underneath stay visible instead of being hidden by a solid
        // block.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.55),
                // Without the outline the translucent card has no visible edge
                // in the light theme: it blends into the note behind it.
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _WavyLine(
                  value: total > 0 ? (done / total).clamp(0.0, 1.0) : null,
                ),
                const SizedBox(height: 6),
                Text(
                  '$done / $total',
                  // Theme colour, not a fixed grey: over the translucent card
                  // a hardcoded grey is unreadable in the light theme.
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The wavy line: same thickness and colours as the Material bar, with the
/// stroke drawn as a sine that travels along the bar.
class _WavyLine extends StatefulWidget {
  const _WavyLine({this.value});

  /// Progress between 0 and 1, or null while the total is unknown.
  final double? value;

  @override
  State<_WavyLine> createState() => _WavyLineState();
}

class _WavyLineState extends State<_WavyLine>
    with SingleTickerProviderStateMixin {
  static const _height = 4.0;
  static const _amplitude = 2.5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox(
      // One extra pixel above and below: the stroke is centred on the wave,
      // so the crest must not touch the edge of the box.
      height: _height + _amplitude * 2 + 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _WavePainter(
            value: widget.value,
            phase: reduceMotion ? 0.0 : _controller.value,
            color: scheme.primary,
            trackColor: scheme.primary.withValues(alpha: 0.24),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.trackColor,
  });

  static const _height = 4.0;
  static const _amplitude = 2.5;
  static const _wavelength = 44.0;

  final double? value;
  final double phase;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    // The stroke is centred on the path, so without the clip the round caps
    // and the travelling segment would be painted outside the card.
    canvas.clipRect(Offset.zero & size);
    final centerY = size.height / 2;
    final inset = _height / 2;
    final span = size.width - inset * 2;
    if (span <= 0) return;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = _height
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final shift = phase * 2 * math.pi;

    // The whole bar is the wave: the empty part is the dim track, the filled
    // part lights up as it advances.
    _drawWave(
      canvas,
      Paint()
        ..color = trackColor
        ..strokeWidth = _height
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
      inset,
      size.width - inset,
      centerY,
      shift,
    );

    final progress = value;
    if (progress == null) {
      // The bright segment travels over the track.
      final segment = span * 0.35;
      final start = inset + (phase % 1.0) * (span + segment) - segment;
      _drawWave(canvas, progressPaint, start, start + segment, centerY, shift);
      return;
    }
    _drawWave(
      canvas,
      progressPaint,
      inset,
      inset + span * progress.clamp(0.0, 1.0),
      centerY,
      shift,
    );
  }

  void _drawWave(
    Canvas canvas,
    Paint paint,
    double x0,
    double x1,
    double centerY,
    double shift,
  ) {
    if (x1 <= x0) return;
    double yAt(double x) =>
        centerY + _amplitude * math.sin((x / _wavelength) * 2 * math.pi + shift);
    // Start on the wave itself: starting at the centre line leaves a short
    // straight stroke at the left end of the bar.
    final path = Path()..moveTo(x0, yAt(x0));
    for (double x = x0; x <= x1; x += 1.5) {
      path.lineTo(x, yAt(x));
    }
    path.lineTo(x1, yAt(x1));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.value != value ||
      old.phase != phase ||
      old.color != color ||
      old.trackColor != trackColor;
}
