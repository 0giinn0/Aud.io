import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aud_io/core/theme/theme_presets.dart';

/// Swiss/Bauhaus theme engine.
/// Typography follows a golden-ratio (Fibonacci) scale: 8 · 13 · 21 · 34 · 55.
class AppTheme {
  AppTheme._();

  static const Color red = Color(0xFFE8432A);
  static const Color redDeep = Color(0xFFC93418);
  static const Color cream = Color(0xFFDCD8CD);
  static const Color creamBright = Color(0xFFE6E2D7);
  static const Color ink = Color(0xFF14120F);

  static TextTheme _textTheme(Color strong, Color body, Color muted, Color subtle) {
    return GoogleFonts.archivoTextTheme(
      TextTheme(
        displayLarge: TextStyle(fontSize: 55, fontWeight: FontWeight.w800, color: strong, height: 0.95, letterSpacing: -2),
        displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: strong, height: 0.95, letterSpacing: -1),
        displaySmall: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: strong, height: 1.0, letterSpacing: -0.5),
        headlineLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: strong, height: 1.0, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: body),
        headlineSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: body),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: body),
        titleMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: body),
        titleSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: body),
        bodyLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: body),
        bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: body),
        bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: muted),
        labelLarge: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted, letterSpacing: 1.5),
        labelMedium: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: muted, letterSpacing: 1),
        labelSmall: TextStyle(fontSize: 8, fontWeight: FontWeight.w500, color: subtle, letterSpacing: 0.5),
      ),
    );
  }

  /// Build a [ThemeData] from any [ThemePreset].
  static ThemeData fromPreset(ThemePreset p) {
    final textTheme = _textTheme(p.onBg, p.onSurface, p.muted, p.subtle);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: p.brightness,
        primary: p.primary,
        onPrimary: p.onBg,
        secondary: p.primary,
        surface: p.surface,
        onSurface: p.onSurface,
        error: p.error,
        outline: p.border,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.bg,
        selectedItemColor: p.primary,
        unselectedItemColor: p.subtle,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.onBg,
        inactiveTrackColor: p.surfaceVariant,
        thumbColor: p.onBg,
        overlayColor: p.primary.withValues(alpha: 0.15),
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceVariant,
        contentTextStyle: GoogleFonts.archivo(color: p.onSurface, fontSize: 12),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    );
  }

  static ThemeData get dark => fromPreset(ThemePresets.inkRed);
  static ThemeData get light => fromPreset(ThemePresets.creamRed);
}
