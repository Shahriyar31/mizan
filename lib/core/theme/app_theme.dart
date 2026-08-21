/// Taddabur App Theme
///
/// Assembles AppColors and AppTypography into Flutter's ThemeData.
/// Every Material widget in the app inherits these styles automatically.
///
/// Why ThemeData matters: without it, every widget needs manual styling.
/// With it, ElevatedButton automatically uses jade, AppBar uses night, etc.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  /// The sole dark theme — matte, warm, immersive.
  /// Every screen in the app uses this.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        // ── Core Colors ─────────────────────────────────────────────
        scaffoldBackgroundColor: AppColors.night,
        primaryColor: AppColors.jade,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.jade,
          secondary: AppColors.gold,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: AppColors.night,
          onSecondary: AppColors.night,
          onSurface: AppColors.textPrimary,
          onError: AppColors.white,
        ),

        // ── AppBar ──────────────────────────────────────────────────
        // All screens that use AppBar get this automatically
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.night,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),

        // ── Bottom Navigation ────────────────────────────────────────
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.navBg,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.navInactive,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),

        // ── Cards ───────────────────────────────────────────────────
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),

        // Material controls share the same generous, tactile silhouette.
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(48, 48),
            shape: const StadiumBorder(),
          ),
        ),

        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceElevated,
          selectedColor: AppColors.jade.withValues(alpha: 0.22),
          disabledColor: AppColors.surfaceDim,
          labelStyle: AppTypography.labelMedium(color: AppColors.textSecondary),
          secondaryLabelStyle:
              AppTypography.labelMedium(color: AppColors.jadeLight),
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),

        // ── Input Fields ─────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.slate,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(99), // pill shape
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(99),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(99),
            borderSide: const BorderSide(color: AppColors.jade, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),

        // ── Elevated Button — PILL SHAPE ─────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.jade,
            foregroundColor: AppColors.night,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 16,
            ),
            shape: const StadiumBorder(), // pill shape
            textStyle: AppTypography.buttonPrimary(),
          ),
        ),

        // ── Outlined Button — PILL SHAPE ─────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.jade,
            side: const BorderSide(color: AppColors.jade, width: 1.5),
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 16,
            ),
            shape: const StadiumBorder(),
            textStyle: AppTypography.buttonSecondary(),
          ),
        ),

        // ── Text Button — PILL SHAPE ─────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.jade,
            shape: const StadiumBorder(),
            textStyle: AppTypography.buttonSecondary(),
          ),
        ),

        // ── FilledButton — PILL SHAPE ────────────────────────────────
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.night,
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 16,
            ),
            shape: const StadiumBorder(),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.night,
          shape: StadiumBorder(),
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          modalBackgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),

        // ── Divider ──────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 1,
        ),

        // ── Snackbar ─────────────────────────────────────────────────
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceElevated,
          contentTextStyle:
              AppTypography.bodySmall(color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // ── Dialog ───────────────────────────────────────────────────
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),

        // ── Slider ──────────────────────────────────────────────────
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.gold,
          inactiveTrackColor: AppColors.gold.withValues(alpha: 0.2),
          thumbColor: AppColors.gold,
          overlayColor: AppColors.gold.withValues(alpha: 0.15),
          trackHeight: 3,
        ),

        // ── Progress Indicator ──────────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.gold,
          linearTrackColor: Color(0xFF1E2A3A),
        ),
      );

  /// Legacy accessor — redirects to dark theme
  static ThemeData get light => dark;
}
