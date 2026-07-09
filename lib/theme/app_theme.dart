import 'package:flutter/material.dart';

/// Central color/style tokens for the "liquid glass" look.
class AppColors {
  static const Color rustOrange = Color(0xFFDE7B3F);
  static const Color rustOrangeDeep = Color(0xFFB1552A);
  static const Color bgTop = Color(0xFF0E0F12);
  static const Color bgBottom = Color(0xFF1B1D22);
  static const Color glassFill = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x55FFFFFF);
  static const Color textPrimary = Color(0xFFF5F1EA);
  static const Color textMuted = Color(0xFFB8B5B0);
}

class AppGradients {
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.bgTop, AppColors.bgBottom],
  );

  static const LinearGradient rustAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.rustOrange, AppColors.rustOrangeDeep],
  );
}

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
