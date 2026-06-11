import 'package:flutter/material.dart';
import 'package:aud_io/core/theme/app_theme.dart';

class AudIoTheme {
  static bool _isDark = true;
  static bool get isDark => _isDark;

  static void setDarkMode(bool value) {
    _isDark = value;
  }

  // ── Golden ratio ──
  static const double phi = 1.6180339887;
  /// Major share of a golden split (≈ 0.618).
  static const double golden = 0.6180339887;
  /// Minor share of a golden split (≈ 0.382).
  static const double goldenMinor = 0.3819660113;
  /// Fibonacci spacing scale.
  static const double s1 = 5, s2 = 8, s3 = 13, s4 = 21, s5 = 34, s6 = 55;

  // ── Bauhaus accents (theme-independent) ──
  static const Color red = AppTheme.red;
  static const Color cream = AppTheme.cream;
  static const Color ink = AppTheme.ink;

  static Color get bg => _isDark ? AppTheme.darkBg : AppTheme.lightBg;
  static Color get surface => _isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
  static Color get surfaceVariant => _isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant;
  static Color get card => _isDark ? AppTheme.darkCard : AppTheme.lightCard;
  static Color get border => _isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
  static Color get primary => _isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
  static Color get onBg => _isDark ? AppTheme.darkOnBg : AppTheme.lightOnBg;
  static Color get onSurface => _isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
  static Color get muted => _isDark ? AppTheme.darkMuted : AppTheme.lightMuted;
  static Color get subtle => _isDark ? AppTheme.darkSubtle : AppTheme.lightSubtle;
  static Color get green => _isDark ? AppTheme.darkGreen : AppTheme.lightGreen;
  static Color get error => _isDark ? AppTheme.darkError : AppTheme.lightError;
  static Color get gradientStart => _isDark ? AppTheme.darkGradientStart : AppTheme.lightGradientStart;
  static Color get gradientEnd => _isDark ? AppTheme.darkGradientEnd : AppTheme.lightGradientEnd;
}
