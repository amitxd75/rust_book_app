import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'book_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/circles.dart';
import '../widgets/glass_widgets.dart';

/// A splash screen displaying an intro animation and the app title
/// before redirecting to the main reader screen.
class SplashScreen extends StatefulWidget {
  /// Creates the [SplashScreen] widget.
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Transition to the main book reader screen after 2.5 seconds
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const BookScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 1. Drifting animated background circles
            const CirclesBackground(),

            // 2. Main content overlay
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GlassContainer(
                      blur: 16.0,
                      borderRadius: BorderRadius.circular(28),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glowing Rust Logo
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDE7B3F)
                                  .withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFDE7B3F)
                                    .withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFDE7B3F)
                                      .withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const FaIcon(
                              FontAwesomeIcons.rust,
                              size: 64,
                              color: Color(0xFFDE7B3F), // Rust Orange glow
                            ),
                          ),
                          const SizedBox(height: 24),
                          // App Name
                          const Text(
                            'RUST BOOK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cognitive Engineering Lab Fork',
                            style: TextStyle(
                              color:
                                  const Color(0xFF2083A4), // Ocean Blue accent
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF2083A4)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const SizedBox(
                            width: 120,
                            child: LinearProgressIndicator(
                              color: Color(0xFFDE7B3F),
                              backgroundColor: Colors.white10,
                              minHeight: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Credits section
                          Text(
                            'Made by amitxd',
                            style: TextStyle(
                              color: AppColors.textMuted.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
