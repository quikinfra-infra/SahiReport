// lib/core/theme/app_theme.dart
// ─────────────────────────────────────────────────────────────
// Full MaterialTheme — Professional navy + gray palette
// Used across the entire app for consistent styling
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand Colors ──────────────────────────────────────────
  static const Color navyDark = Color(0xFF0F1F3D); // Primary navy — nav bars
  static const Color navyMid = Color(0xFF1A3A7A); // Buttons, accents
  static const Color navyLight = Color(0xFF1E3A6E); // Cards on dark bg
  static const Color navyAccent = Color(0xFF7AADEE); // Active tabs, highlights

  // ── Neutral Colors ────────────────────────────────────────
  static const Color grayBg = Color(0xFFF4F5F7); // App background
  static const Color grayCard = Color(0xFFFFFFFF); // Card background
  static const Color grayBorder = Color(0xFFD8DCE6); // Card borders
  static const Color grayText = Color(0xFF6B7A99); // Secondary text
  static const Color grayDark = Color(0xFF3A4A6B); // Section titles
  static const Color textPrimary = Color(0xFF0F1F3D); // Primary text

  // ── Semantic Colors ───────────────────────────────────────
  static const Color success = Color(0xFF1A7A4A); // GPS locked, active badges
  static const Color successLight = Color(0xFFE3F5ED); // Success badge bg
  static const Color warning = Color(0xFFBA7517); // Warning states
  static const Color warningLight = Color(0xFFFAEEDA); // Warning badge bg
  static const Color error = Color(0xFF7A2A3A); // Error, removed user
  static const Color errorLight = Color(0xFFF0EAEC); // Error badge bg

  // ── Light Theme ───────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',

      colorScheme: const ColorScheme.light(
        primary: navyMid,
        onPrimary: Colors.white,
        primaryContainer: navyDark,
        secondary: navyAccent,
        onSecondary: navyDark,
        surface: grayCard,
        onSurface: textPrimary,
        surfaceContainerHighest: grayBg,
        error: error,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: grayBg,

      // ── AppBar ──────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // ── Bottom Navigation ────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: navyDark,
        selectedItemColor: navyAccent,
        unselectedItemColor: Color(0xFF4A5A7A),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 10),
      ),

      // ── Cards ────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: grayCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: grayBorder, width: 0.5),
        ),
        margin: const EdgeInsets.only(bottom: 8),
      ),

      // ── Elevated Buttons ─────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyMid,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined Buttons ─────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navyMid,
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: navyMid),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Fields ─────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grayBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: grayBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: grayBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: navyMid, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        labelStyle: const TextStyle(color: grayText, fontFamily: 'Poppins'),
        hintStyle: const TextStyle(
          color: grayText,
          fontFamily: 'Poppins',
          fontSize: 13,
        ),
        errorStyle: const TextStyle(
          color: error,
          fontFamily: 'Poppins',
          fontSize: 11,
        ),
      ),

      // ── Text Theme ───────────────────────────────────────
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontFamily: 'Poppins',
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Poppins',
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Poppins',
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Poppins',
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: 'Poppins',
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: 'Poppins',
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          fontFamily: 'Poppins',
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          fontFamily: 'Poppins',
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: grayText,
          fontFamily: 'Poppins',
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: grayDark,
          fontFamily: 'Poppins',
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: grayText,
          fontFamily: 'Poppins',
        ),
      ),

      // ── Divider ──────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: grayBorder,
        thickness: 0.5,
        space: 1,
      ),

      // ── Chip ─────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: grayBg,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: grayBorder, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  // ── Reusable Badge Styles ─────────────────────────────────
  static BoxDecoration activeBadge = BoxDecoration(
    color: successLight,
    borderRadius: BorderRadius.circular(20),
  );

  static BoxDecoration inactiveBadge = BoxDecoration(
    color: errorLight,
    borderRadius: BorderRadius.circular(20),
  );

  static BoxDecoration warningBadge = BoxDecoration(
    color: warningLight,
    borderRadius: BorderRadius.circular(20),
  );

  // ── Section Title Style ───────────────────────────────────
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: grayDark,
    letterSpacing: 0.06,
  );
}
