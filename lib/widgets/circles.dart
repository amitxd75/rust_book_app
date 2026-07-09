import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Specification for an animated background circle.
class CircleSpec {
  /// The base X coordinate (percentage of screen width, 0.0 to 1.0).
  final double baseX;

  /// The base Y coordinate (percentage of screen height, 0.0 to 1.0).
  final double baseY;

  /// The radius of the circle.
  final double radius;

  /// The radius of the orbital motion/drift path.
  final double orbitRadius;

  /// Speed multiplier for the orbital motion.
  final double speedMultiplier;

  /// Initial phase offset (in radians) for the animation loop.
  final double phase;

  /// The color used to draw the circle.
  final Color color;

  /// Creates a new [CircleSpec].
  CircleSpec({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.orbitRadius,
    required this.speedMultiplier,
    required this.phase,
    required this.color,
  });
}

/// Custom painter that renders radial gradients to simulate blurs at 120 FPS.
class RadialCirclesPainter extends CustomPainter {
  /// The current progress of the animation (0.0 to 1.0).
  final double progress;

  /// Creates a [RadialCirclesPainter] with the given animation progress.
  RadialCirclesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final double angle = progress * 2 * math.pi;

    // 3 large blurred bubbles with extremely faint opacity for a subtle
    final circles = [
      CircleSpec(
        baseX: size.width * 0.3,
        baseY: size.height * 0.25,
        radius: size.width * 0.6,
        orbitRadius: 70,
        speedMultiplier: 0.6,
        phase: 0.0,
        color: const Color(0xFFDE7B3F)
            .withValues(alpha: 0.07), // Extremely subtle orange glow
      ),
      CircleSpec(
        baseX: size.width * 0.75,
        baseY: size.height * 0.55,
        radius: size.width * 0.55,
        orbitRadius: 80,
        speedMultiplier: -0.7,
        phase: math.pi / 2,
        color: const Color(0xFFDE7B3F)
            .withValues(alpha: 0.04), // Warm orange glow instead of blue
      ),
      CircleSpec(
        baseX: size.width * 0.25,
        baseY: size.height * 0.75,
        radius: size.width * 0.45,
        orbitRadius: 60,
        speedMultiplier: 0.9,
        phase: math.pi,
        color: const Color(0xFFDE7B3F)
            .withValues(alpha: 0.05), // Extremely subtle orange glow
      ),
    ];

    for (var spec in circles) {
      final currentAngle = angle * spec.speedMultiplier + spec.phase;
      final x = spec.baseX + spec.orbitRadius * math.cos(currentAngle);
      final y = spec.baseY + spec.orbitRadius * math.sin(currentAngle);
      final offset = Offset(x, y);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            spec.color,
            spec.color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: offset, radius: spec.radius));

      canvas.drawCircle(offset, spec.radius, paint);
    }
  }

  @override
  bool shouldRepaint(RadialCirclesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Animated background featuring drifting orbital bubbles with radial blur shaders.
/// Runs extremely smooth on both Skia and Impeller backends.
class CirclesBackground extends StatefulWidget {
  /// Creates the [CirclesBackground] widget.
  const CirclesBackground({super.key});

  @override
  State<CirclesBackground> createState() => _CirclesBackgroundState();
}

class _CirclesBackgroundState extends State<CirclesBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 35),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: RadialCirclesPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}
