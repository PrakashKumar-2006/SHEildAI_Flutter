import 'package:flutter/material.dart';

// ─── Light Theme Colors (from React Native ThemeContext) ───────────────────────
class AppColors {
  // ─── Light Theme Colors ──────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightAccent = Color(0xFF2563EB);
  static const Color lightDanger = Color(0xFFEF4444);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Premium Dark Theme Colors (Slate/Blue gradient feel)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkAccent = Color(0xFF3B82F6);
  static const Color darkDanger = Color(0xFFF87171);
  static const Color darkBorder = Color(0xFF334155);

  // Brand Colors
  static const Color brandNavy = Color(0xFF0D1B6E);
  static const Color brandBlue = Color(0xFF1976D2);
  static const Color primaryRed = Color(0xFFD32F2F);

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
      centerTitle: true,
      titleTextStyle: TextStyle(color: AppColors.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      secondary: AppColors.darkAccent,
      surface: AppColors.darkSurface,
      error: AppColors.darkDanger,
      onSurface: AppColors.darkTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
      bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
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

