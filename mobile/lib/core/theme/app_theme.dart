import 'package:flutter/material.dart';

ThemeData appTheme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  brightness: brightness,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff087f72),
    brightness: brightness,
  ),
  scaffoldBackgroundColor: brightness == Brightness.light
      ? const Color(0xfff6f5f0)
      : const Color(0xff111b1a),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
);
