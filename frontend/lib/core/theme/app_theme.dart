import 'package:flutter/material.dart';

/// ─── Idir App Colour System ──────────────────────────────────────────────────
///
/// Primary: deep teal-green (trust, community)
/// Secondary: warm amber (Ethiopian warmth)
/// Error/Danger: crimson
/// Neutral surface: near-white / dark-charcoal

abstract final class AppColors {
  // Brand - Blues
  static const primary = Color(0xFF1D4ED8); // Royal Blue
  static const primaryLight = Color(0xFF60A5FA); // Light Blue
  static const primaryDark = Color(0xFF0F294D); // Deep Dark Blue

  static const secondary = Color(0xFF0284C7); // Sky / Light-Blue
  static const secondaryLight = Color(0xFF38BDF8);
  static const secondaryDark = Color(0xFF0369A1);

  // Status
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF57C00);
  static const error = Color(0xFFC62828);
  static const info = Color(0xFF1D4ED8);

  // Claim status chips
  static const statusSubmitted = Color(0xFF1D4ED8);
  static const statusApproved = Color(0xFF2E7D32);
  static const statusRejected = Color(0xFFC62828);
  static const statusPaid = Color(0xFF0F294D);

  // Text specific (Requested: dark blue, blue, light-blue)
  static const textDarkBlue = Color(0xFF0F294D); // Deep Navy/Dark Blue for headings & titles
  static const textBlue = Color(0xFF1D4ED8);     // Standard Blue for body and labels
  static const textLightBlue = Color(0xFF0284C7);// Light Blue for subtext, hints, captions

  // Neutral (light) - pure white background & cards
  static const surfaceLight = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFFFFFFF);
  static const dividerLight = Color(0xFFE2E8F0);
  static const onSurfaceLight = textDarkBlue;
  static const subtextLight = textLightBlue;

  // Neutral (dark)
  static const surfaceDark = Color(0xFF0A1128);
  static const cardDark = Color(0xFF121E3A);
  static const dividerDark = Color(0xFF1E293B);
  static const onSurfaceDark = Color(0xFFE0E7FF);
  static const subtextDark = Color(0xFF93C5FD);
}

/// ─── App Theme ───────────────────────────────────────────────────────────────
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: isDark ? AppColors.primaryDark : const Color(0xFFEFF6FF),
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      surface: isDark ? AppColors.surfaceDark : Colors.white,
      onSurface: isDark ? AppColors.onSurfaceDark : AppColors.textDarkBlue,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? AppColors.surfaceDark : Colors.white,

      // ── Typography ────────────────────────────────────────────────────
      fontFamily: 'NotoSansEthiopic',
      textTheme: _textTheme(colorScheme, isDark),

      // ── AppBar ────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textDarkBlue,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.textDarkBlue,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansEthiopic',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppColors.textDarkBlue,
        ),
      ),

      // ── Navigation bar ────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textDarkBlue,
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.subtextDark : AppColors.textLightBlue,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.textBlue, size: 24);
          }
          return IconThemeData(
            color: isDark ? AppColors.subtextDark : AppColors.textLightBlue,
            size: 24,
          );
        }),
      ),

      // ── Cards ─────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Inputs ────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.cardDark.withValues(alpha: 0.6)
            : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: TextStyle(
          color: isDark ? AppColors.subtextDark : AppColors.textLightBlue,
        ),
        helperStyle: TextStyle(
          color: isDark ? AppColors.subtextDark : AppColors.textLightBlue,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.subtextDark : AppColors.textLightBlue.withValues(alpha: 0.7),
        ),
      ),

      // ── Buttons ───────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textBlue,
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: AppColors.primary, width: 1);
          }
          return BorderSide(
            color: isDark ? AppColors.dividerDark : const Color(0xFFCBD5E1),
            width: 1,
          );
        }),
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return isDark
              ? AppColors.cardDark
              : const Color(0xFFF1F5F9);
        }),
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFE0E7FF) : AppColors.textDarkBlue,
          );
        }),
        backgroundColor: isDark ? AppColors.cardDark : const Color(0xFFF1F5F9),
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        iconTheme: IconThemeData(
          size: 16,
          color: isDark ? AppColors.onSurfaceDark : AppColors.textDarkBlue,
        ),
      ),

      // ── Divider ───────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),

      // ── FloatingActionButton ──────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme, bool isDark) {
    final darkBlue = isDark ? scheme.onSurface : AppColors.textDarkBlue;
    final blue = isDark ? scheme.onSurface : AppColors.textBlue;
    final lightBlue = isDark ? AppColors.subtextDark : AppColors.textLightBlue;

    return TextTheme(
      displayLarge: TextStyle(
          fontSize: 48, fontWeight: FontWeight.w800, color: darkBlue),
      displayMedium: TextStyle(
          fontSize: 36, fontWeight: FontWeight.w700, color: darkBlue),
      headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700, color: darkBlue),
      headlineMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: darkBlue),
      headlineSmall: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: darkBlue),
      titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: darkBlue),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: darkBlue),
      titleSmall: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: blue),
      bodyLarge: TextStyle(fontSize: 16, color: blue),
      bodyMedium: TextStyle(fontSize: 14, color: blue),
      bodySmall: TextStyle(fontSize: 12, color: lightBlue),
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: darkBlue),
      labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: blue),
      labelSmall: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: lightBlue),
    );
  }
}
