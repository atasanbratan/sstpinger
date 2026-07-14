import 'package:flutter/material.dart';

/// Central palette for the app. Never inline `Color(0xFF...)` in a widget —
/// add a named constant here and reference it so the theme stays consistent
/// and is trivial to re-skin.
class AppColors {
  AppColors._();

  // Surfaces (darkest → lightest).
  static const Color background = Color(0xFF0B0F19);
  static const Color surfaceDeep = Color(0xFF0F172A);
  static const Color surface = Color(0xFF151D30);
  static const Color surfaceRaised = Color(0xFF1E293B);
  static const Color surfaceSelected = Color(0xFF1E2D4A);
  static const Color statusButtonCore = Color(0xFF1F293D);

  // Brand accents.
  static const Color accent = Color(0xFF00D2FF); // cyan
  static const Color accentSecondary = Color(0xFF9D4EDD); // purple

  // Semantic status colors.
  static const Color connected = Color(0xFF10B981);
  static const Color connecting = Color(0xFFF59E0B);
  static const Color disconnected = Colors.grey;
  static const Color error = Colors.redAccent;

  // Ping latency buckets.
  static const Color pingGood = Colors.green;
  static const Color pingMedium = Colors.orange;
  static const Color pingBad = Colors.red;

  // Activation screen gradient.
  static const Color gradientTop = Color(0xFF0B1222);
  static const Color gradientBottom = Color(0xFF070B14);

  // Misc surfaces / inputs.
  static const Color surfaceCard = Color(0xFF161F34);
  static const Color inputBackground = Color(0xFF0B101E);
  static const Color errorSurface = Color(0xFF2D161F);

  // Translucent accent borders (kept as compile-time constants so they can be
  // used inside `const` widget constructors).
  static const Color accentBorder = Color(0x5500D2FF);
  static const Color accentBorderFaint = Color(0x3300D2FF);

  // Text tints (on dark surfaces).
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;
  static const Color textFaint = Colors.white38;
  static const Color divider = Colors.white10;
}
