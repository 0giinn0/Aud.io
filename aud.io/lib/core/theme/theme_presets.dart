import 'package:flutter/material.dart';

class ThemePreset {
  final String id;
  final String name;
  final String category;
  final Color preview;
  final Color bg;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color border;
  final Color primary;
  final Color onBg;
  final Color onSurface;
  final Color muted;
  final Color subtle;
  final Color green;
  final Color error;
  final Color gradientStart;
  final Color gradientEnd;
  final Brightness brightness;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.category,
    required this.preview,
    required this.bg,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.border,
    required this.primary,
    required this.onBg,
    required this.onSurface,
    required this.muted,
    required this.subtle,
    required this.green,
    required this.error,
    required this.gradientStart,
    required this.gradientEnd,
    required this.brightness,
  });
}

class ThemePresets {
  ThemePresets._();

  static const List<ThemePreset> all = [
    inkRed,
    blackGrey,
    blackGold,
    midnightBlue,
    creamRed,
    pureWhite,
    warmSand,
  ];

  // ── DARK THEMES ──

  static const inkRed = ThemePreset(
    id: 'ink_red',
    name: 'Ink & Red',
    category: 'Dark',
    preview: Color(0xFFE8432A),
    bg: Color(0xFF14120F),
    surface: Color(0xFF201D18),
    surfaceVariant: Color(0xFF2C2821),
    card: Color(0xFF1B1814),
    border: Color(0xFF3A352C),
    primary: Color(0xFFE8432A),
    onBg: Color(0xFFE6E2D7),
    onSurface: Color(0xFFDCD8CD),
    muted: Color(0xFFA49F92),
    subtle: Color(0xFF6F6A5E),
    green: Color(0xFFE8432A),
    error: Color(0xFFC93418),
    gradientStart: Color(0xFF1B1814),
    gradientEnd: Color(0xFF14120F),
    brightness: Brightness.dark,
  );

  static const blackGrey = ThemePreset(
    id: 'black_grey',
    name: 'Black & Grey',
    category: 'Dark',
    preview: Color(0xFF9E9E9E),
    bg: Color(0xFF0A0A0A),
    surface: Color(0xFF1A1A1A),
    surfaceVariant: Color(0xFF2A2A2A),
    card: Color(0xFF141414),
    border: Color(0xFF333333),
    primary: Color(0xFF9E9E9E),
    onBg: Color(0xFFE0E0E0),
    onSurface: Color(0xFFE0E0E0),
    muted: Color(0xFF888888),
    subtle: Color(0xFF555555),
    green: Color(0xFF4CAF50),
    error: Color(0xFFEF5350),
    gradientStart: Color(0xFF141414),
    gradientEnd: Color(0xFF0A0A0A),
    brightness: Brightness.dark,
  );

  static const blackGold = ThemePreset(
    id: 'black_gold',
    name: 'Black & Gold',
    category: 'Dark',
    preview: Color(0xFFD4A843),
    bg: Color(0xFF0D0D0D),
    surface: Color(0xFF1A1714),
    surfaceVariant: Color(0xFF2A2520),
    card: Color(0xFF15120F),
    border: Color(0xFF3D3520),
    primary: Color(0xFFD4A843),
    onBg: Color(0xFFF5E6C8),
    onSurface: Color(0xFFEDE0C0),
    muted: Color(0xFFA09070),
    subtle: Color(0xFF6B5E42),
    green: Color(0xFF4CAF50),
    error: Color(0xFFEF5350),
    gradientStart: Color(0xFF15120F),
    gradientEnd: Color(0xFF0D0D0D),
    brightness: Brightness.dark,
  );

  static const midnightBlue = ThemePreset(
    id: 'midnight_blue',
    name: 'Midnight Blue',
    category: 'Dark',
    preview: Color(0xFF5C6BC0),
    bg: Color(0xFF0F1623),
    surface: Color(0xFF172033),
    surfaceVariant: Color(0xFF222C42),
    card: Color(0xFF131B2D),
    border: Color(0xFF2E3A52),
    primary: Color(0xFF5C6BC0),
    onBg: Color(0xFFD8DEE9),
    onSurface: Color(0xFFC8D0DE),
    muted: Color(0xFF8892A8),
    subtle: Color(0xFF5A6380),
    green: Color(0xFF66BB6A),
    error: Color(0xFFEF5350),
    gradientStart: Color(0xFF131B2D),
    gradientEnd: Color(0xFF0F1623),
    brightness: Brightness.dark,
  );

  // ── LIGHT THEMES ──

  static const creamRed = ThemePreset(
    id: 'cream_red',
    name: 'Cream & Red',
    category: 'Light',
    preview: Color(0xFFE8432A),
    bg: Color(0xFFDCD8CD),
    surface: Color(0xFFE6E2D7),
    surfaceVariant: Color(0xFFCDC9BE),
    card: Color(0xFFE6E2D7),
    border: Color(0xFF14120F),
    primary: Color(0xFFE8432A),
    onBg: Color(0xFF14120F),
    onSurface: Color(0xFF1C1A16),
    muted: Color(0xFF6C675C),
    subtle: Color(0xFF959085),
    green: Color(0xFFE8432A),
    error: Color(0xFFC93418),
    gradientStart: Color(0xFFE6E2D7),
    gradientEnd: Color(0xFFDCD8CD),
    brightness: Brightness.light,
  );

  static const pureWhite = ThemePreset(
    id: 'pure_white',
    name: 'Pure White',
    category: 'Light',
    preview: Color(0xFF616161),
    bg: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEEEEEE),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE0E0E0),
    primary: Color(0xFF424242),
    onBg: Color(0xFF1A1A1A),
    onSurface: Color(0xFF212121),
    muted: Color(0xFF757575),
    subtle: Color(0xFFBDBDBD),
    green: Color(0xFF4CAF50),
    error: Color(0xFFE53935),
    gradientStart: Color(0xFFFFFFFF),
    gradientEnd: Color(0xFFF5F5F5),
    brightness: Brightness.light,
  );

  static const warmSand = ThemePreset(
    id: 'warm_sand',
    name: 'Warm Sand',
    category: 'Light',
    preview: Color(0xFFA1887F),
    bg: Color(0xFFF5E6D3),
    surface: Color(0xFFFCEBD6),
    surfaceVariant: Color(0xFFE8D5BF),
    card: Color(0xFFFCEBD6),
    border: Color(0xFFC4A882),
    primary: Color(0xFF8D6E63),
    onBg: Color(0xFF3E2723),
    onSurface: Color(0xFF4E342E),
    muted: Color(0xFF8D6E63),
    subtle: Color(0xFFBCAAA4),
    green: Color(0xFF66BB6A),
    error: Color(0xFFE53935),
    gradientStart: Color(0xFFFCEBD6),
    gradientEnd: Color(0xFFF5E6D3),
    brightness: Brightness.light,
  );
}
