import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// WeChat-inspired layout with a Xiaomi (HyperOS) palette: a soft near-white
/// canvas, white list groups, hairline separators, near-black text and one
/// warm orange accent. Green is reserved for completion.
abstract final class NestColors {
  static const white = Color(0xFFFFFFFF);

  /// Canvas behind the white list groups.
  static const bg = Color(0xFFF1F2F5);
  static const paper = bg;
  static const paperDeep = Color(0xFFE9EBEF);

  static const surface = Color(0xFFFFFFFF);
  static const fill = Color(0xFFF7F8FA);

  static const ink = Color(0xFF151619);
  static const inkSoft = Color(0xFF34373D);
  static const muted = Color(0xFF6F747C);
  static const faint = Color(0xFF9CA1A9);

  static const line = Color(0xFFE6E8EC);
  static const lineStrong = Color(0xFFDCE0E6);

  /// Xiaomi orange: the accent for actions and selection.
  static const orange = Color(0xFFFF6900);
  static const orangeDeep = Color(0xFFE85A00);
  static const softOrange = Color(0xFFFFF1E6);
  static const sand = softOrange;

  /// Xiaomi green: completion only.
  static const green = Color(0xFF0F9D58);
  static const greenDeep = Color(0xFF0C8A4C);
  static const softGreen = Color(0xFFEAF7EF);

  /// Text actions share the warm accent.
  static const link = orangeDeep;
  static const blue = Color(0xFF2F7CF6);
  static const softBlue = Color(0xFFEDF3FF);

  static const danger = Color(0xFFE5484D);
  static const softDanger = Color(0xFFFDECEC);
  static const amber = Color(0xFFC77700);

  static const tagBg = Color(0xFFF1F2F4);
}

abstract final class NestRadius {
  static const card = 8.0;
  static const sheet = 12.0;
  static const tile = 4.0;
  static const pill = 6.0;
}

abstract final class NestShadow {
  static const card = <BoxShadow>[];
  static const floating = <BoxShadow>[];
  static const accentGlow = <BoxShadow>[];
}

ThemeData nestTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: kIsWeb ? null : 'MiSans',
    fontFamilyFallback: kIsWeb
        ? null
        : const [
            'HarmonyOS Sans SC',
            'PingFang SC',
            'Noto Sans SC',
            'Microsoft YaHei',
          ],
    scaffoldBackgroundColor: NestColors.bg,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: NestColors.orange,
      onPrimary: Colors.white,
      primaryContainer: NestColors.softOrange,
      onPrimaryContainer: NestColors.orangeDeep,
      secondary: NestColors.link,
      onSecondary: Colors.white,
      secondaryContainer: NestColors.softBlue,
      onSecondaryContainer: NestColors.link,
      tertiary: NestColors.link,
      onTertiary: Colors.white,
      tertiaryContainer: NestColors.softBlue,
      onTertiaryContainer: NestColors.link,
      error: NestColors.danger,
      onError: Colors.white,
      errorContainer: NestColors.softDanger,
      onErrorContainer: NestColors.danger,
      surface: NestColors.surface,
      onSurface: NestColors.ink,
      surfaceContainerHighest: NestColors.fill,
      outline: NestColors.line,
      outlineVariant: NestColors.line,
    ),
  );

  final text = base.textTheme.copyWith(
    headlineLarge: const TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: NestColors.ink,
    ),
    headlineMedium: const TextStyle(
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: NestColors.ink,
    ),
    headlineSmall: const TextStyle(
      fontSize: 17,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: NestColors.ink,
    ),
    titleLarge: const TextStyle(
      fontSize: 17,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: NestColors.ink,
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: NestColors.ink,
    ),
    titleSmall: const TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: NestColors.inkSoft,
    ),
    bodyLarge: const TextStyle(
      fontSize: 16,
      height: 1.6,
      color: NestColors.ink,
    ),
    bodyMedium: const TextStyle(
      fontSize: 15,
      height: 1.6,
      color: NestColors.ink,
    ),
    bodySmall: const TextStyle(
      fontSize: 13,
      height: 1.6,
      color: NestColors.muted,
    ),
    labelLarge: const TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: NestColors.ink,
    ),
    labelMedium: const TextStyle(
      fontSize: 13,
      height: 1.2,
      color: NestColors.muted,
    ),
    labelSmall: const TextStyle(
      fontSize: 11,
      height: 1.2,
      color: NestColors.muted,
    ),
  );

  OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(NestRadius.pill),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: text,
    primaryTextTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: NestColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: NestColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleSpacing: 0,
      toolbarHeight: 48,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: NestColors.ink,
      ),
      iconTheme: IconThemeData(color: NestColors.ink, size: 22),
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
    iconTheme: const IconThemeData(color: NestColors.ink, size: 22),
    listTileTheme: const ListTileThemeData(
      iconColor: NestColors.muted,
      textColor: NestColors.ink,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: NestColors.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: NestColors.muted,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      minVerticalPadding: 10,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NestColors.fill,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(fontSize: 15, color: NestColors.faint),
      labelStyle: const TextStyle(fontSize: 14, color: NestColors.muted),
      floatingLabelStyle: const TextStyle(
        fontSize: 12,
        color: NestColors.muted,
      ),
      helperStyle: const TextStyle(fontSize: 12, color: NestColors.muted),
      border: fieldBorder(NestColors.lineStrong),
      enabledBorder: fieldBorder(NestColors.lineStrong),
      focusedBorder: fieldBorder(NestColors.orange),
      errorBorder: fieldBorder(NestColors.danger),
      focusedErrorBorder: fieldBorder(NestColors.danger),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NestColors.orange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFF6D8C4),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NestRadius.pill),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NestColors.ink,
        backgroundColor: NestColors.surface,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        side: const BorderSide(color: NestColors.lineStrong),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NestRadius.pill),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NestColors.link,
        textStyle: const TextStyle(fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NestRadius.tile),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NestColors.tagBg,
      selectedColor: NestColors.softOrange,
      disabledColor: NestColors.tagBg,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NestRadius.tile),
      ),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: NestColors.inkSoft,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: NestColors.orangeDeep,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      showCheckmark: false,
      checkmarkColor: NestColors.orange,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? NestColors.orange
            : NestColors.lineStrong,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      side: const BorderSide(color: NestColors.lineStrong, width: 1.4),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? NestColors.green
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: NestColors.orange,
      linearTrackColor: NestColors.line,
      circularTrackColor: NestColors.line,
      linearMinHeight: 3,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF4C4C4C),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        color: Colors.white,
        height: 1.4,
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NestColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NestRadius.sheet),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: NestColors.ink,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 15,
        height: 1.6,
        color: NestColors.inkSoft,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NestRadius.sheet),
      ),
      textStyle: const TextStyle(fontSize: 15, color: NestColors.ink),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: NestColors.muted,
      collapsedIconColor: NestColors.muted,
      textColor: NestColors.ink,
      collapsedTextColor: NestColors.ink,
      childrenPadding: EdgeInsets.only(bottom: 4),
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
      headerBackgroundColor: NestColors.surface,
    ),
  );
}
