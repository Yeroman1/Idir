import 'package:flutter/material.dart';

/// ─── Idir App Colour System ──────────────────────────────────────────────────
///
/// Primary: deep teal-green (trust, community)
/// Secondary: warm amber (Ethiopian warmth)
/// Error/Danger: crimson
/// Neutral surface: near-white / dark-charcoal

abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF1A6B5A); // deep teal-green
  static const primaryLight = Color(0xFF2E9E7E);
  static const primaryDark = Color(0xFF0F4A3D);

  static const secondary = Color(0xFFD4821A); // warm amber
  static const secondaryLight = Color(0xFFF5A623);
  static const secondaryDark = Color(0xFF9E5C0D);

  // Status
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF57C00);
  static const error = Color(0xFFC62828);
  static const info = Color(0xFF1565C0);

  // Claim status chips
  static const statusSubmitted = Color(0xFF1565C0);
  static const statusApproved = Color(0xFF2E7D32);
  static const statusRejected = Color(0xFFC62828);
  static const statusPaid = Color(0xFF1A6B5A);

  // Neutral (light)
  static const surfaceLight = Color(0xFFF5F7F6);
  static const cardLight = Color(0xFFFFFFFF);
  static const dividerLight = Color(0xFFDEE4E2);
  static const onSurfaceLight = Color(0xFF0F2420);
  static const subtextLight = Color(0xFF5A7870);

  // Neutral (dark)
  static const surfaceDark = Color(0xFF0D1F1B);
  static const cardDark = Color(0xFF172820);
  static const dividerDark = Color(0xFF2A3D38);
  static const onSurfaceDark = Color(0xFFE0EDEA);
  static const subtextDark = Color(0xFF7AADA0);
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
      primaryContainer: isDark ? AppColors.primaryDark : const Color(0xFFB2D8D0),
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      onSurface: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,

      // ── Typography ────────────────────────────────────────────────────
      fontFamily: 'NotoSansEthiopic',
      textTheme: _textTheme(colorScheme),

      // ── AppBar ────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'NotoSansEthiopic',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      // ── Navigation bar ────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return IconThemeData(
            color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
            size: 24,
          );
        }),
      ),

      // ── Cards ─────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
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
            : AppColors.cardLight,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: TextStyle(
          color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
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
          foregroundColor: AppColors.primary,
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      displayLarge: TextStyle(
          fontSize: 48, fontWeight: FontWeight.w800, color: scheme.onSurface),
      displayMedium: TextStyle(
          fontSize: 36, fontWeight: FontWeight.w700, color: scheme.onSurface),
      headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700, color: scheme.onSurface),
      headlineMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: scheme.onSurface),
      headlineSmall: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
      titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurface),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
      titleSmall: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface),
      bodyLarge: TextStyle(fontSize: 16, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: scheme.onSurface),
      bodySmall:
          TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
      labelLarge: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      labelMedium: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      labelSmall: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
  }
}
