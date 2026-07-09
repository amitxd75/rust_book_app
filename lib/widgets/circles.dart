import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Spec for a high-performance radial gradient animated circle.
class CircleSpec {
  final double baseX;
  final double baseY;
  final double radius;
  final double orbitRadius;
  final double speedMultiplier;
  final double phase;
  final Color color;

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
  final double progress;

  RadialCirclesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final double angle = progress * 2 * math.pi;

    // 3 large blurred bubbles with extremely faint opacity for a subtle, premium orange/charcoal glow (no blue tones)
    final circles = [
      CircleSpec(
        baseX: size.width * 0.3,
        baseY: size.height * 0.25,
        radius: size.width * 0.6,
        orbitRadius: 70,
        speedMultiplier: 0.6,
        phase: 0.0,
        color: const Color(0xFFDE7B3F).withOpacity(0.07), // Extremely subtle orange glow
      ),
      CircleSpec(
        baseX: size.width * 0.75,
        baseY: size.height * 0.55,
        radius: size.width * 0.55,
        orbitRadius: 80,
        speedMultiplier: -0.7,
        phase: math.pi / 2,
        color: const Color(0xFFDE7B3F).withOpacity(0.04), // Warm orange glow instead of blue
      ),
      CircleSpec(
        baseX: size.width * 0.25,
        baseY: size.height * 0.75,
        radius: size.width * 0.45,
        orbitRadius: 60,
        speedMultiplier: 0.9,
        phase: math.pi,
        color: const Color(0xFFDE7B3F).withOpacity(0.05), // Extremely subtle orange glow
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
            spec.color.withOpacity(0.0),
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
