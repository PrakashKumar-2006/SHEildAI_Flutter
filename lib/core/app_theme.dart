import 'package:flutter/material.dart';

// ─── Light Theme Colors (from React Native ThemeContext) ───────────────────────
class AppColors {
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightAccent = Color(0xFF2563EB);
  static const Color lightDanger = Color(0xFFEF4444);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Dark Theme Colors (True AMOLED Black)
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkAccent = Color(0xFF3B82F6);
  static const Color darkDanger = Color(0xFFF87171);
  static const Color darkBorder = Color(0xFF334155);

  // Brand Colors
  static const Color brandNavy = Color(0xFF0D1B6E);
  static const Color brandBlue = Color(0xFF1976D2);

  // Risk Colors
  static const Color riskCritical = Color(0xFF8B0000);
  static const Color riskHigh = Color(0xFFFF4D4D);
  static const Color riskMedium = Color(0xFFFFD700);
  static const Color riskSafe = Color(0xFF43A047);
  static const Color riskGray = Color(0xFF9E9E9E);
}

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.brandNavy,
      secondary: AppColors.brandBlue,
      surface: AppColors.lightSurface,
      error: AppColors.lightDanger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brandNavy,
      secondary: AppColors.brandBlue,
      surface: AppColors.darkSurface,
      error: AppColors.darkDanger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
    ),
  );
}

extension AppThemeExtension on BuildContext {
  Color get bgColor => isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get surfaceColor => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get textPrimary => isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get accent => isDark ? AppColors.darkAccent : AppColors.lightAccent;
  Color get danger => isDark ? AppColors.darkDanger : AppColors.lightDanger;
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
