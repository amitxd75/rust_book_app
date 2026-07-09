import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A premium glass panel with authentic blur, faint outline, and soft shadow.
/// Skips BackdropFilter if blur <= 0 for maximum GPU optimization.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final Color fillColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blur = 18.0,
    this.fillColor = const Color(0x02FFFFFF), // ~0.8% white for absolute transparency
  });

  @override
  Widget build(BuildContext context) {
    final innerContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        // Extremely faint glass border outline
        border: Border.all(
          color: Colors.white.withOpacity(0.015),
          width: 0.8,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fillColor,
            fillColor.withOpacity(0.2),
          ],
        ),
      ),
      child: child,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        // High-end soft shadow to make the glass panel float
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: blur > 0.0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: innerContainer,
              )
            : innerContainer,
      ),
    );
  }
}

/// An interactive glass circular button (icon inside a circle) with dynamic active gradients and tap scaling.
class GlassIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor; // Color-matched highlight background
  final double size;
  final String? tooltip;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.size = 40,
    this.tooltip,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final highlightColor = widget.activeColor ?? AppColors.rustOrange;

    final button = GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) {
          setState(() => _scale = 0.86);
        }
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          setState(() => _scale = 1.0);
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) {
          setState(() => _scale = 1.0);
        }
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: widget.onTap == null ? 0.35 : 1.0,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Glowing backlight aura when the button is active
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: highlightColor.withOpacity(0.14),
                        blurRadius: 8,
                        spreadRadius: 0.2,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.size),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Extremely subtle border outline
                    border: Border.all(
                      color: widget.active 
                          ? highlightColor.withOpacity(0.3) 
                          : Colors.white.withOpacity(0.02),
                      width: 0.8,
                    ),
                    gradient: widget.active
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              highlightColor.withOpacity(0.55),
                              highlightColor.withOpacity(0.35),
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.04),
                              Colors.white.withOpacity(0.002),
                            ],
                          ),
                  ),
                  child: Center(
                    child: widget.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
