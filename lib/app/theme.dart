import 'package:flutter/material.dart';

/// Deliberately plain: a flat, neutral grey palette and flat (no shadow,
/// thin-bordered) cards rather than a "designed" seeded Material color
/// scheme with elevation everywhere — the goal is utilitarian software
/// that looks hand-built, not a polished dashboard. Color is reserved for
/// meaning (income vs. expense) rather than decoration; see [MoneyColors].
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.blueGrey,
    brightness: brightness,
    // A near-neutral primary instead of Material 3's usual saturated
    // tonal primary — this is most of what makes a seeded scheme read as
    // "designed" rather than plain.
  ).copyWith(
    primary: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
    secondary: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      indicatorColor: scheme.surfaceContainerHighest,
    ),
    navigationRailTheme: NavigationRailThemeData(
      indicatorColor: scheme.surfaceContainerHighest,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}

/// Semantic colors for money direction, independent of the neutral base
/// palette above — these must stay legible and unambiguous in both
/// themes.
extension MoneyColors on ColorScheme {
  Color get income => brightness == Brightness.dark ? const Color(0xFF6FCF97) : const Color(0xFF1B7A3D);
  Color get expense => brightness == Brightness.dark ? const Color(0xFFEF9A9A) : const Color(0xFFB71C1C);
}
