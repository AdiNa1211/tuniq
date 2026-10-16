import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF5B4BDB);

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      sliderTheme: const SliderThemeData(trackHeight: 3),
      navigationBarTheme: const NavigationBarThemeData(height: 68),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
