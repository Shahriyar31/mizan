/// Mizan App Theme
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
  static ThemeData get dark => build(Brightness.dark);

  static ThemeData get light => build(Brightness.light);

  /// Builds the theme for either brightness. AppColors is switched first so
  /// every token read below resolves against the right palette.
  static ThemeData build(Brightness brightness) {
    AppColors.applyBrightness(brightness);
    final isLight = brightness == Brightness.light;
    return ThemeData(
        useMaterial3: true,
        brightness: brightness,

        // ── Core Colors ─────────────────────────────────────────────
        scaffoldBackgroundColor: AppColors.night,
        primaryColor: AppColors.jade,
        colorScheme: ColorScheme(
          brightness: brightness,
          primary: AppColors.jade,
          secondary: AppColors.gold,
          surface: AppColors.surface,
          error: AppColors.error,
          // ink, not night: this is text/icons drawn ON TOP of the jade/gold
          // fill, so it must stay near-black in both themes — night is the
          // *app background* token and flips to cream in light mode, which
          // would make this text vanish against a still-mid-tone accent fill.
          onPrimary: AppColors.ink,
          onSecondary: AppColors.ink,
          onSurface: AppColors.textPrimary,
          onError: AppColors.white,
        ),

        // ── AppBar ──────────────────────────────────────────────────
        // All screens that use AppBar get this automatically
        appBarTheme:  AppBarTheme(
          backgroundColor: AppColors.night,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle:
              isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        ),

        // ── Bottom Navigation ────────────────────────────────────────
        bottomNavigationBarTheme:  BottomNavigationBarThemeData(
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
          side:  BorderSide(color: AppColors.border),
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
            borderSide:  BorderSide(color: AppColors.jade, width: 1.5),
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
            foregroundColor: AppColors.ink,
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
            side:  BorderSide(color: AppColors.jade, width: 1.5),
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

        floatingActionButtonTheme:  FloatingActionButtonThemeData(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.night,
          shape: StadiumBorder(),
        ),

        bottomSheetTheme:  BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          modalBackgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),

        // ── Divider ──────────────────────────────────────────────────
        dividerTheme:  DividerThemeData(
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
        progressIndicatorTheme:  ProgressIndicatorThemeData(
          color: AppColors.gold,
          linearTrackColor: AppColors.surfaceElevated,
        ),
      );
  }
}
