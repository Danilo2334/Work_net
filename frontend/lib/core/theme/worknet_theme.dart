import 'package:flutter/material.dart';

abstract final class WorkNetColors {
  static const green = Color(0xFF087F70);
  static const dark = Color(0xFF193F36);
  static const background = Color(0xFFEFF5F2);
  static const muted = Color(0xFF526D65);
  static const line = Color(0xFFD6E2DC);
  static const mint = Color(0xFFE8F5EE);
  static const onBrandMuted = Color(0xFFCEE2D9);
}

ThemeData workNetTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: WorkNetColors.green,
    primary: WorkNetColors.green,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: WorkNetColors.dark,
    error: const Color(0xFFB3261E),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: WorkNetColors.line),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: WorkNetColors.background,
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: WorkNetColors.line),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    ).apply(bodyColor: WorkNetColors.dark, displayColor: WorkNetColors.dark),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: WorkNetColors.green, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      errorMaxLines: 4,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}
