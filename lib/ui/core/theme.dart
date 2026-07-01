import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.cyan,
      scaffoldBackgroundColor: const Color(0xFF0B0F19),
      cardColor: const Color(0xFF151D30),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(fontFamily: 'Outfit', color: Colors.white),
        bodyMedium: TextStyle(fontFamily: 'Outfit', color: Colors.white70),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00D2FF),
        secondary: Color(0xFF9D4EDD),
        surface: Color(0xFF151D30),
      ),
    );
  }
}
