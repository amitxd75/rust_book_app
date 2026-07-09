import 'package:flutter/material.dart';

/// Central color/style tokens for the "liquid glass" look.
class AppColors {
  /// Primary rust orange accent color.
  static const Color rustOrange = Color(0xFFDE7B3F);

  /// Deeper rust orange color for gradients and borders.
  static const Color rustOrangeDeep = Color(0xFFB1552A);

  /// Top color for background gradients.
  static const Color bgTop = Color(0xFF0E0F12);

  /// Bottom color for background gradients.
  static const Color bgBottom = Color(0xFF1B1D22);

  /// Semi-transparent white fill for glassmorphic elements.
  static const Color glassFill = Color(0x33FFFFFF);

  /// Semi-transparent white border for glassmorphic elements.
  static const Color glassBorder = Color(0x55FFFFFF);

  /// Primary light color for readable text.
  static const Color textPrimary = Color(0xFFF5F1EA);

  /// Muted grey-tan color for secondary/helper text.
  static const Color textMuted = Color(0xFFB8B5B0);
}

/// A collection of standard gradient decorations used throughout the application.
class AppGradients {
  /// The main dark gradient used as the background of screens.
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.bgTop, AppColors.bgBottom],
  );

  /// The orange gradient used for key accents, active states, and buttons.
  static const LinearGradient rustAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.rustOrange, AppColors.rustOrangeDeep],
  );
}

/// Builds the overall dark [ThemeData] for the application, applying
/// the custom color scheme, typography colors, and ink ripple effect.
ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bgTop,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.rustOrange,
      secondary: AppColors.rustOrangeDeep,
      surface: AppColors.bgBottom,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}
