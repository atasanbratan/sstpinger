import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.cyan,
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.textPrimary),
        bodyMedium: TextStyle(
          fontFamily: 'Outfit',
          color: AppColors.textSecondary,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentSecondary,
        surface: AppColors.surface,
      ),
    );
  }
}
