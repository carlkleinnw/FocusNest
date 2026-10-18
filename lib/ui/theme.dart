import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// HyperOS-inspired design tokens.
///
/// The palette is a near-white canvas with pure white cards, ink text and a
/// single warm accent (orange) reserved for action and progress. Green and blue
/// only appear as semantic states (done / info), never as decoration.
abstract final class NestColors {
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF17181A);
  static const inkSoft = Color(0xFF3B3E44);
  static const muted = Color(0xFF8A8E96);
  static const faint = Color(0xFFB9BDC5);

  /// Canvas behind cards.
  static const paper = Color(0xFFF4F5F7);
  static const paperDeep = Color(0xFFE9EBF0);

  /// Card surface.
  static const surface = Color(0xFFFFFFFF);

  /// Hairlines and outlines.
  static const line = Color(0xFFEDEEF2);
  static const lineStrong = Color(0xFFE2E4EA);

  /// Accent: Xiaomi orange.
  static const orange = Color(0xFFFF6900);
  static const orangeDeep = Color(0xFFE85A00);
  static const softOrange = Color(0xFFFFF1E6);
  static const orangeGlow = Color(0x33FF6900);

  /// Semantic green (completion, healthy progress).
  static const green = Color(0xFF0F9D58);
  static const softGreen = Color(0xFFEAF7EF);

  /// Semantic blue (informational).
  static const blue = Color(0xFF2F7CF6);
  static const softBlue = Color(0xFFEDF3FF);

  /// Warning amber.
  static const sand = Color(0xFFFFF4DC);
  static const amber = Color(0xFFC77700);

  /// Dark hero surfaces.
  static const heroStart = Color(0xFF1D1E22);
  static const heroEnd = Color(0xFF2C2E35);

  static const danger = Color(0xFFE5484D);
  static const softDanger = Color(0xFFFDEDED);
}

abstract final class NestRadius {
  static const card = 22.0;
  static const sheet = 28.0;
  static const tile = 12.0;
  static const pill = 999.0;
}

abstract final class NestShadow {
  static const card = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x14101828), blurRadius: 28, offset: Offset(0, 12)),
  ];
  static const accentGlow = [
    BoxShadow(color: Color(0x40FF6900), blurRadius: 26, offset: Offset(0, 10)),
  ];
}

ThemeData nestTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    // MiSans ships with HyperOS, so Xiaomi phones get the real system face.
    // On the web an unavailable family breaks CJK text measurement, so the
    // browser default (Roboto + system CJK fallback) is used instead.
    fontFamily: kIsWeb ? null : 'MiSans',
    fontFamilyFallback: kIsWeb
        ? null
        : const [
            'HarmonyOS Sans SC',
            'PingFang SC',
            'Noto Sans SC',
            'Microsoft YaHei',
          ],
    scaffoldBackgroundColor: NestColors.paper,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: NestColors.orange,
      onPrimary: Colors.white,
      primaryContainer: NestColors.softOrange,
      onPrimaryContainer: NestColors.orangeDeep,
      secondary: NestColors.green,
      onSecondary: Colors.white,
      secondaryContainer: NestColors.softGreen,
      onSecondaryContainer: NestColors.green,
      tertiary: NestColors.blue,
      onTertiary: Colors.white,
      tertiaryContainer: NestColors.softBlue,
      onTertiaryContainer: NestColors.blue,
      error: NestColors.danger,
      onError: Colors.white,
      errorContainer: NestColors.softDanger,
      onErrorContainer: NestColors.danger,
      surface: NestColors.surface,
      onSurface: NestColors.ink,
      surfaceContainerHighest: NestColors.paperDeep,
      outline: NestColors.line,
      outlineVariant: NestColors.line,
    ),
  );

  final text = base.textTheme.copyWith(
    displayLarge: const TextStyle(
      fontSize: 56,
      height: 1.05,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.2,
      color: NestColors.ink,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    displayMedium: const TextStyle(
      fontSize: 44,
      height: 1.1,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
      color: NestColors.ink,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    displaySmall: const TextStyle(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: NestColors.ink,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    headlineLarge: const TextStyle(
      fontSize: 28,
      height: 1.22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: NestColors.ink,
    ),
    headlineMedium: const TextStyle(
      fontSize: 22,
      height: 1.28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: NestColors.ink,
    ),
    headlineSmall: const TextStyle(
      fontSize: 19,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: NestColors.ink,
    ),
    titleLarge: const TextStyle(
      fontSize: 17,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: NestColors.ink,
    ),
    titleMedium: const TextStyle(
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: NestColors.ink,
    ),
    titleSmall: const TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: NestColors.inkSoft,
    ),
    bodyLarge: const TextStyle(
      fontSize: 15,
      height: 1.6,
      color: NestColors.inkSoft,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      height: 1.6,
      color: NestColors.inkSoft,
    ),
    bodySmall: const TextStyle(
      fontSize: 12,
      height: 1.55,
      color: NestColors.muted,
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: NestColors.ink,
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: NestColors.muted,
    ),
    labelSmall: const TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: NestColors.muted,
    ),
  );

  OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: text,
    primaryTextTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: NestColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: NestColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: NestColors.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: NestColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NestRadius.card),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: NestColors.line,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: NestColors.inkSoft, size: 22),
    listTileTheme: const ListTileThemeData(
      iconColor: NestColors.muted,
      textColor: NestColors.ink,
      titleTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: NestColors.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 12,
        height: 1.45,
        color: NestColors.muted,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 10,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NestColors.surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(fontSize: 14, color: NestColors.faint),
      labelStyle: const TextStyle(fontSize: 14, color: NestColors.muted),
      floatingLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: NestColors.orangeDeep,
      ),
      helperStyle: const TextStyle(fontSize: 12, color: NestColors.muted),
      border: fieldBorder(NestColors.line),
      enabledBorder: fieldBorder(NestColors.line),
      focusedBorder: fieldBorder(NestColors.orange, 1.6),
      errorBorder: fieldBorder(NestColors.danger),
      focusedErrorBorder: fieldBorder(NestColors.danger, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NestColors.orange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: NestColors.paperDeep,
        disabledForegroundColor: NestColors.faint,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NestRadius.pill),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NestColors.ink,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: const BorderSide(color: NestColors.lineStrong),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NestRadius.pill),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NestColors.orangeDeep,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NestRadius.pill),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NestColors.surface,
      selectedColor: NestColors.softOrange,
      disabledColor: NestColors.paperDeep,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NestRadius.pill),
      ),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: NestColors.inkSoft,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: NestColors.orangeDeep,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      showCheckmark: false,
      checkmarkColor: NestColors.orange,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? NestColors.orange
            : NestColors.paperDeep,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      side: const BorderSide(color: NestColors.faint, width: 1.6),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? NestColors.orange
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: NestColors.orange,
      linearTrackColor: NestColors.paperDeep,
      circularTrackColor: NestColors.paperDeep,
      linearMinHeight: 6,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NestColors.ink,
      contentTextStyle: const TextStyle(
        fontSize: 13.5,
        color: Colors.white,
        height: 1.4,
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NestColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NestRadius.sheet),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: NestColors.ink,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: NestColors.inkSoft,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NestColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: NestColors.lineStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NestRadius.sheet),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: NestColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontSize: 14, color: NestColors.ink),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: NestColors.muted,
      collapsedIconColor: NestColors.muted,
      textColor: NestColors.ink,
      collapsedTextColor: NestColors.ink,
      childrenPadding: EdgeInsets.only(bottom: 8),
      tilePadding: EdgeInsets.symmetric(horizontal: 16),
      shape: Border(),
      collapsedShape: Border(),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: NestColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NestRadius.sheet),
      ),
      dayShape: const WidgetStatePropertyAll(CircleBorder()),
      todayBorder: const BorderSide(color: NestColors.orange),
      headerBackgroundColor: NestColors.paper,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
