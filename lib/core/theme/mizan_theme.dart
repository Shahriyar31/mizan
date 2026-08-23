/// Mizan ThemeData
///
/// Assembles [MizanPalette] + [MizanType] into the two ThemeData objects the
/// app hands to `MaterialApp.router`. Nothing here invents a value — every
/// colour comes from the palette, every text style from the type scale.
///
/// Both themes are built independently and both are live at once, so switching
/// theme is just `themeMode`. (The legacy `AppTheme` could not do this: its
/// `AppColors` is one mutable static palette, so building light then dark left
/// every token resolved to dark. See app.dart for the workaround that exists
/// only because of that.)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mizan_tokens.dart';
import 'mizan_typography.dart';

abstract final class MizanTheme {
  static ThemeData get light => _build(MizanPalette.light);
  static ThemeData get dark => _build(MizanPalette.dark);

  static ThemeData _build(MizanPalette p) {
    final isLight = p.isLight;

    // Primary CTA: ink fill on cream, gold fill on navy. The label always
    // reads against the fill, never against the page.
    final primaryFill = isLight ? p.ink : p.accent;
    // Light: cream label on the navy fill. Dark: navy label on the gold fill.
    final onPrimaryFill = p.onFilled;

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      extensions: <ThemeExtension<dynamic>>[p],

      scaffoldBackgroundColor: p.page,
      canvasColor: p.page,
      primaryColor: primaryFill,
      dividerColor: p.hairline,
      splashFactory: InkSparkle.splashFactory,

      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: primaryFill,
        onPrimary: onPrimaryFill,
        secondary: p.link,
        onSecondary: p.onFilled,
        tertiary: p.sage,
        onTertiary: p.onFilled,
        surface: p.card,
        onSurface: p.ink,
        surfaceContainerHighest: p.sunk,
        outline: p.hairline,
        outlineVariant: p.hairline,
        // No red in the Mizan palette. Error borrows bronze/gold-as-text so a
        // validation message still belongs to the brand; the *word* carries the
        // meaning, not the hue. (Rule: depth — and colour — never carries
        // meaning alone.)
        error: p.accentText,
        onError: p.onFilled,
      ),

      textTheme: MizanType.textTheme(p.ink, p.muted),
      iconTheme: IconThemeData(color: p.ink, size: 22),
      primaryIconTheme: IconThemeData(color: p.ink, size: 22),

      // ── App bar ───────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: p.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: MizanType.cardHeadline(color: p.ink).copyWith(
          fontSize: 19,
          height: 1.2,
        ),
        iconTheme: IconThemeData(color: p.ink, size: 22),
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),

      // ── Cards ─────────────────────────────────────────────────────────
      // Elevation 0 everywhere. Depth in Mizan comes from the neumorphic
      // shadow set, applied only to touchables via MizanPressable — a card
      // that merely holds text stays flat with a hairline.
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: MizanGeometry.cardBorderRadius,
          side: BorderSide(color: p.hairline, width: MizanGeometry.hairlineWidth),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Bottom nav ────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.page,
        selectedItemColor: p.ink,
        unselectedItemColor: p.muted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: MizanType.navLabel(),
        unselectedLabelStyle: MizanType.navLabel(),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.page,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: MizanGeometry.tabBarHeight,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => MizanType.navLabel(
            color: states.contains(WidgetState.selected) ? p.ink : p.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? p.ink : p.muted,
          ),
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        selectedColor: primaryFill,
        disabledColor: p.sunk,
        labelStyle: MizanType.button(color: p.ink).copyWith(fontSize: 13),
        secondaryLabelStyle:
            MizanType.button(color: onPrimaryFill).copyWith(fontSize: 13),
        side: BorderSide(color: p.hairline, width: MizanGeometry.hairlineWidth),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        showCheckmark: false,
      ),

      // ── Inputs — the "sunk" well ───────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.sunk,
        hintStyle: MizanType.body(color: p.muted),
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(MizanGeometry.pillRadius)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(MizanGeometry.pillRadius)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(MizanGeometry.pillRadius),
          ),
          borderSide: BorderSide(color: p.link, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),

      // ── Buttons ───────────────────────────────────────────────────────
      // These cover stock Material call sites. Screens built to the Mizan
      // designs should prefer MizanButton, which adds the tactile press.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryFill,
          foregroundColor: onPrimaryFill,
          minimumSize: const Size(0, MizanGeometry.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: MizanType.button(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryFill,
          foregroundColor: onPrimaryFill,
          minimumSize: const Size(0, MizanGeometry.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: MizanType.button(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isLight ? p.ink : p.accentText,
          minimumSize: const Size(0, MizanGeometry.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: BorderSide(
            color: isLight ? p.ink : p.accent,
            width: MizanGeometry.hairlineWidth,
          ),
          shape: const StadiumBorder(),
          textStyle: MizanType.button(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.link,
          minimumSize: const Size(0, MizanGeometry.tapTarget),
          shape: const StadiumBorder(),
          textStyle: MizanType.button(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: const Size(MizanGeometry.tapTarget, MizanGeometry.tapTarget),
          shape: const CircleBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // The compose button on Al-Minbar: a navy disc with a gold glyph in
        // both themes — gold-on-navy is legal in light too, because the fill
        // is navy, not cream.
        backgroundColor: isLight ? p.ink : p.card,
        foregroundColor: p.accent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),

      // ── Surfaces & misc ───────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: p.hairline,
        thickness: MizanGeometry.hairlineWidth,
        space: MizanGeometry.hairlineWidth,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.accentText,
        textColor: p.ink,
        titleTextStyle: MizanType.bodyStrong(color: p.ink),
        subtitleTextStyle: MizanType.body(color: p.muted),
        shape: RoundedRectangleBorder(borderRadius: MizanGeometry.rowBorderRadius),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minVerticalPadding: 10,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        modalBackgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          // Top corners only — a modal sheet's bottom edge is off-screen.
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: MizanGeometry.cardBorderRadius,
          side: BorderSide(color: p.hairline, width: MizanGeometry.hairlineWidth),
        ),
        titleTextStyle: MizanType.cardHeadline(color: p.ink),
        contentTextStyle: MizanType.body(color: p.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? p.ink : p.sunk,
        contentTextStyle: MizanType.body(color: isLight ? p.onFilled : p.ink),
        actionTextColor: p.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const StadiumBorder(),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.hairline,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.14),
        trackHeight: 3,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.hairline,
        circularTrackColor: p.hairline,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onFilled : p.card,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primaryFill : p.sunk,
        ),
        trackOutlineColor: WidgetStateProperty.all(p.hairline),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? p.ink : p.sunk,
          borderRadius: MizanGeometry.rowBorderRadius,
        ),
        textStyle: MizanType.body(color: isLight ? p.onFilled : p.ink),
      ),
    );
  }
}
