import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Delime's dark theme and shared colour tokens.
class AppTheme {
  // Core palette.
  static const Color background = Color(0xFF0E1116);
  static const Color surface = Color(0xFF171B22);
  static const Color surfaceHigh = Color(0xFF1F242D);
  static const Color outline = Color(0xFF2A313C);
  static const Color primary = Color(0xFF2DD4BF); // teal
  static const Color onPrimary = Color(0xFF052E2A);

  // Semantic colours for balances.
  static const Color positive = Color(0xFF34D399); // owed to them
  static const Color negative = Color(0xFFFB7185); // they owe
  static const Color neutral = Color(0xFF94A3B8);

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      surface: surface,
      onSurface: textPrimary,
      error: negative,
      outline: outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: negative, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceHigh,
        side: const BorderSide(color: outline),
        labelStyle: const TextStyle(color: textPrimary),
      ),
    );
  }
}
