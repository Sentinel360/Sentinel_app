import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandPrimary = Color(0xFF22D3EE);
  static const Color brandAccent = Color(0xFF38BDF8);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF0F172A),
      secondary: brandPrimary,
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF0F172A),
      onPrimary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandAccent, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: brandPrimary,
      secondary: brandAccent,
      surface: const Color(0xFF0F172A),
      onSurface: const Color(0xFFF8FAFC),
      onPrimary: const Color(0xFF00131A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF050A14),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0F172A),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandPrimary, width: 1.5),
        ),
      ),
    );
  }
}
