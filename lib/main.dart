import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RustBookApp());
}

class RustBookApp extends StatelessWidget {
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
