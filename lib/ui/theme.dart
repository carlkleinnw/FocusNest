import 'package:flutter/material.dart';

abstract final class NestColors {
  static const ink = Color(0xFF332D28);
  static const muted = Color(0xFF756B61);
  static const paper = Color(0xFFF8F6F0);
  static const surface = Color(0xFFFFFEFA);
  static const line = Color(0xFFE8E2D6);
  static const green = Color(0xFF44664F);
  static const softGreen = Color(0xFFE8EFE3);
  static const orange = Color(0xFFB75B39);
  static const sand = Color(0xFFF1E7D6);
}

ThemeData nestTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: NestColors.paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: NestColors.green,
    primary: NestColors.green,
    secondary: NestColors.orange,
    surface: NestColors.surface,
    onSurface: NestColors.ink,
  ),
  fontFamily: 'Microsoft YaHei',
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: NestColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w700,
      color: NestColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: NestColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: NestColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 15, height: 1.6, color: NestColors.ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: NestColors.ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.5, color: NestColors.muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: NestColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: NestColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: NestColors.line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      side: const BorderSide(color: NestColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
);
