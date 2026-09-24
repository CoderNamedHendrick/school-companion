import 'package:flutter/material.dart';

abstract final class MivaColors {
  static const navy = Color(0xFF0A3150);
  static const blue = Color(0xFF3B5A73);
  static const gold = Color(0xFFB79A7F);
  static const red = Color(0xFFE83831);
  static const cloud = Color(0xFFF6F8FA);
  static const line = Color(0xFFDDE2E7);
  static const ink = Color(0xFF1F2124);
}

ThemeData buildMivaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MivaColors.navy,
    primary: MivaColors.navy,
    secondary: MivaColors.gold,
    tertiary: MivaColors.red,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MivaColors.cloud,
    fontFamily: 'Manrope',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: MivaColors.navy,
      surfaceTintColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: MivaColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MivaColors.navy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: MivaColors.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: MivaColors.gold.withValues(alpha: 0.24),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      selectedIconTheme: const IconThemeData(color: MivaColors.navy),
      selectedLabelTextStyle: const TextStyle(color: MivaColors.navy, fontWeight: FontWeight.w800),
      indicatorColor: MivaColors.gold.withValues(alpha: 0.26),
    ),
  );
}
