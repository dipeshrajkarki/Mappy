import 'dart:ui';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Primary — lime/yellow accent
  static const Color accent = Color(0xFFCDDC39);
  static const Color accentBright = Color(0xFFE6EE4D);
  static const Color accentDark = Color(0xFFB0C200);

  // Background — deep dark
  static const Color bgDark = Color(0xFF121212);
  static const Color bgCard = Color(0xFF1E1E1E);
  static const Color bgElevated = Color(0xFF2A2A2A);
  static const Color bgSurface = Color(0xFF333333);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted = Color(0xFF666666);

  // Route
  static const Color routeColor = Color(0xFFCDDC39);
  static const Color routeGlow = Color(0x40CDDC39);

  // Functional
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF4CAF50);

  // Spacing
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // Radii
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusFull = 999;

  // Shadows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: accent.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  // Glass container (dark frosted glass)
  static Widget glassContainer({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgCard.withValues(alpha: 0.85),
            borderRadius: borderRadius ?? BorderRadius.circular(radiusLg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // Material theme
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        colorSchemeSeed: accent,
        scaffoldBackgroundColor: bgDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
