import 'package:flutter/material.dart';

class AppColors {
  // Brand Purples & Lilacs (inspired by Cortex aesthetic)
  static const primary = Color(0xFF7C3AED);
  static const primaryLight = Color(0xFF9333EA);
  static const primaryGlow = Color(0xFFA855F7);
  static const primarySoft = Color(0xFFC4B5FD);
  static const primaryTint = Color(0xFFF5F1FD);
  static const primaryBorder = Color(0xFFDDD0FA);

  // Backgrounds & Atmospheres
  static const scaffoldLight = Color(0xFFF7F5FA);
  static const scaffoldDark = Color(0xFF100E19);
  static const canvasBg = Color(0xFFF5F2F9);
  static const auraPurple1 = Color(0xFFE9E0F8);
  static const auraPurple2 = Color(0xFFF2ECFC);
  static const auraPink = Color(0xFFF5EBF7);

  // Surfaces
  static const surfaceLight = Colors.white;
  static const surfaceDark = Color(0xFF1A1726);
  static const surfaceSubtleLight = Color(0xFFFAF9FD);
  static const borderLight = Color(0xFFEAE5F3);
  static const borderDark = Color(0xFF2C273C);

  // Dark Contrast Buttons (New chat pill, Upgrade pill)
  static const darkPill = Color(0xFF13111B);
  static const darkPillText = Colors.white;

  // Text
  static const textPrimary = Color(0xFF151320);
  static const textSecondary = Color(0xFF726B82);
  static const textMuted = Color(0xFF9E98AD);
  static const textViolet = Color(0xFF7C3AED);

  // Functional
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
}

ThemeData appTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.primaryGlow,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceContainerLowest: isDark ? const Color(0xFF12101E) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF1C1929) : const Color(0xFFFAF8FD),
      surfaceContainer: isDark ? const Color(0xFF242035) : const Color(0xFFF5F1FB),
      surfaceContainerHigh: isDark ? const Color(0xFF2E2943) : const Color(0xFFEDE8F6),
      outline: isDark ? AppColors.borderDark : AppColors.borderLight,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
    fontFamily: 'Roboto',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF201D2E) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
      centerTitle: false,
    ),
  );
}
