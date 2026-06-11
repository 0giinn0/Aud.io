import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Swiss/Bauhaus theme: vivid red, warm cream, ink black.
/// Typography follows a golden-ratio (Fibonacci) scale: 8 · 13 · 21 · 34 · 55.
class AppTheme {
  AppTheme._();

  // ── Shared Bauhaus palette ──
  static const Color red = Color(0xFFE8432A);
  static const Color redDeep = Color(0xFFC93418);
  static const Color cream = Color(0xFFDCD8CD);
  static const Color creamBright = Color(0xFFE6E2D7);
  static const Color ink = Color(0xFF14120F);

  // ── Dark (ink canvas) ──
  static const Color darkBg = Color(0xFF14120F);
  static const Color darkSurface = Color(0xFF201D18);
  static const Color darkSurfaceVariant = Color(0xFF2C2821);
  static const Color darkCard = Color(0xFF1B1814);
  static const Color darkBorder = Color(0xFF3A352C);
  static const Color darkPrimary = red;
  static const Color darkOnBg = Color(0xFFE6E2D7);
  static const Color darkOnSurface = Color(0xFFDCD8CD);
  static const Color darkMuted = Color(0xFFA49F92);
  static const Color darkSubtle = Color(0xFF6F6A5E);
  static const Color darkGreen = red;
  static const Color darkError = redDeep;
  static const Color darkGradientStart = Color(0xFF1B1814);
  static const Color darkGradientEnd = Color(0xFF14120F);

  // ── Light (cream canvas) ──
  static const Color lightBg = cream;
  static const Color lightSurface = creamBright;
  static const Color lightSurfaceVariant = Color(0xFFCDC9BE);
  static const Color lightCard = creamBright;
  static const Color lightBorder = Color(0xFF14120F);
  static const Color lightPrimary = red;
  static const Color lightOnBg = ink;
  static const Color lightOnSurface = Color(0xFF1C1A16);
  static const Color lightMuted = Color(0xFF6C675C);
  static const Color lightSubtle = Color(0xFF959085);
  static const Color lightGreen = red;
  static const Color lightError = redDeep;
  static const Color lightGradientStart = creamBright;
  static const Color lightGradientEnd = cream;

  static TextTheme _textTheme(Color strong, Color body, Color muted, Color subtle) {
    return GoogleFonts.archivoTextTheme(
      TextTheme(
        // Golden-ratio scale: 55 / 34 / 21 / 13 / 8
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

  static ThemeData _base({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surfaceVariant,
    required Color card,
    required Color border,
    required Color onBg,
    required Color onSurface,
    required Color muted,
    required Color subtle,
    required Color error,
  }) {
    final textTheme = _textTheme(onBg, onSurface, muted, subtle);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: red,
        brightness: brightness,
        primary: red,
        onPrimary: cream,
        secondary: red,
        surface: surface,
        onSurface: onSurface,
        error: error,
        outline: border,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      // Swiss style: hard edges everywhere; circles are the only round shapes.
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: red,
        unselectedItemColor: subtle,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: onBg,
        inactiveTrackColor: surfaceVariant,
        thumbColor: onBg,
        overlayColor: red.withValues(alpha: 0.15),
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: GoogleFonts.archivo(color: onSurface, fontSize: 12),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    );
  }

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        bg: darkBg,
        surface: darkSurface,
        surfaceVariant: darkSurfaceVariant,
        card: darkCard,
        border: darkBorder,
        onBg: darkOnBg,
        onSurface: darkOnSurface,
        muted: darkMuted,
        subtle: darkSubtle,
        error: darkError,
      );

  static ThemeData get light => _base(
        brightness: Brightness.light,
        bg: lightBg,
        surface: lightSurface,
        surfaceVariant: lightSurfaceVariant,
        card: lightCard,
        border: lightBorder,
        onBg: lightOnBg,
        onSurface: lightOnSurface,
        muted: lightMuted,
        subtle: lightSubtle,
        error: lightError,
      );
}
