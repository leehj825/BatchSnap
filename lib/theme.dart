import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2563EB);
  static const teal = Color(0xFF0D9488);
  static const success = Color(0xFF10B981);
  static const bgLight = Color(0xFFF8FAFC);
  static const bgDark = Color(0xFF0F172A);
  static const border = Color(0xFFE2E8F0);
}

/// For size figures: fixed-width tabular numerals.
const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: b,
  ).copyWith(primary: dark ? const Color(0xFF60A5FA) : AppColors.primary);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? AppColors.bgDark : AppColors.bgLight,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppColors.bgDark : AppColors.bgLight,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark ? const Color(0xFF334155) : AppColors.border,
        ),
      ),
    ),
  );
}
