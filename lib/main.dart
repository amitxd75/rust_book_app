import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

/// The entry point of the Rust Book application.
void main() {
  runApp(const RustBookApp());
}

/// The root widget of the Rust Book application.
///
/// Sets up the MaterialApp, including the app title, theme settings,
/// and sets the initial home screen to [SplashScreen].
class RustBookApp extends StatelessWidget {
  /// Creates the [RustBookApp] widget.
  const RustBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rust Book',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
