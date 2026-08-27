import 'package:flutter/material.dart';

/// Minimal, finance-focused light/dark themes. Deliberately restrained —
/// a personal-finance ledger benefits from calm, high-contrast neutrals
/// more than a colorful brand identity, since color here is reserved for
/// meaning (income vs. expense, positive vs. negative) rather than
/// decoration.
ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E4F));
  return ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.light);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B5E4F),
    brightness: Brightness.dark,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
}

/// Semantic colors for money direction, independent of the primary brand
/// seed color above — these must stay legible and unambiguous in both
/// themes, which a seeded Material palette does not guarantee on its own.
extension MoneyColors on ColorScheme {
  Color get income => brightness == Brightness.dark ? const Color(0xFF6FCF97) : const Color(0xFF1B8A47);
  Color get expense => brightness == Brightness.dark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828);
}
