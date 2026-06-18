import 'package:flutter/material.dart';
import 'package:aud_io/core/theme/theme_presets.dart';

class AudIoTheme {
  static ThemePreset _current = ThemePresets.inkRed;
  static ThemePreset get current => _current;

  static void setTheme(ThemePreset preset) {
    _current = preset;
  }

  // ── Golden ratio ──
  static const double phi = 1.6180339887;
  static const double golden = 0.6180339887;
  static const double goldenMinor = 0.3819660113;
  static const double s1 = 5, s2 = 8, s3 = 13, s4 = 21, s5 = 34, s6 = 55;

  // ── Static Bauhaus accents (always available) ──
  static const Color red = Color(0xFFE8432A);
  static const Color cream = Color(0xFFDCD8CD);
  static const Color ink = Color(0xFF14120F);

  // ── Dynamic colors from current theme ──
  static Color get bg => _current.bg;
  static Color get surface => _current.surface;
  static Color get surfaceVariant => _current.surfaceVariant;
  static Color get card => _current.card;
  static Color get border => _current.border;
  static Color get primary => _current.primary;
  static Color get onBg => _current.onBg;
  static Color get onSurface => _current.onSurface;
  static Color get muted => _current.muted;
  static Color get subtle => _current.subtle;
  static Color get green => _current.green;
  static Color get error => _current.error;
  static Color get gradientStart => _current.gradientStart;
  static Color get gradientEnd => _current.gradientEnd;
  static bool get isDark => _current.brightness == Brightness.dark;

  static void setDarkMode(bool value) {
    // Legacy compat — no-op now that we use full theme presets.
  }
}
