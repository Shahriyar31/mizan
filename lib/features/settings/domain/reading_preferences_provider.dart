/// Reading preferences — shared, persisted state for the Quran reader
/// (features/quran/presentation/ayah_detail_screen.dart), set from
/// Settings → Personalisation. Font choices use `google_fonts` (already a
/// project dependency) rather than bundling new font assets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ArabicFont { amiri, scheherazade, lateef }

extension ArabicFontX on ArabicFont {
  String get label => switch (this) {
        ArabicFont.amiri => 'Amiri',
        ArabicFont.scheherazade => 'Scheherazade New',
        ArabicFont.lateef => 'Lateef',
      };

  TextStyle style({required double size, Color? color, double? height}) {
    switch (this) {
      case ArabicFont.amiri:
        return TextStyle(
            fontFamily: 'Amiri', fontSize: size, color: color, height: height);
      case ArabicFont.scheherazade:
        return GoogleFonts.scheherazadeNew(
            fontSize: size, color: color, height: height);
      case ArabicFont.lateef:
        return GoogleFonts.lateef(fontSize: size, color: color, height: height);
    }
  }

  static ArabicFont fromName(String? name) => ArabicFont.values.firstWhere(
        (f) => f.name == name,
        orElse: () => ArabicFont.amiri,
      );
}

class ReadingPreferences {
  const ReadingPreferences({
    this.arabicFont = ArabicFont.amiri,
    this.showTranslation = true,
    this.showTransliteration = false,
    this.arabicTextSize = 28,
    this.translationTextSize = 14,
  });

  final ArabicFont arabicFont;
  final bool showTranslation;
  final bool showTransliteration;
  final double arabicTextSize;
  final double translationTextSize;

  ReadingPreferences copyWith({
    ArabicFont? arabicFont,
    bool? showTranslation,
    bool? showTransliteration,
    double? arabicTextSize,
    double? translationTextSize,
  }) =>
      ReadingPreferences(
        arabicFont: arabicFont ?? this.arabicFont,
        showTranslation: showTranslation ?? this.showTranslation,
        showTransliteration: showTransliteration ?? this.showTransliteration,
        arabicTextSize: arabicTextSize ?? this.arabicTextSize,
        translationTextSize: translationTextSize ?? this.translationTextSize,
      );
}

class ReadingPreferencesController extends StateNotifier<ReadingPreferences> {
  ReadingPreferencesController() : super(const ReadingPreferences()) {
    _load();
  }

  static const _kFont = 'reading_arabic_font';
  static const _kShowTranslation = 'reading_show_translation';
  static const _kShowTransliteration = 'reading_show_transliteration';
  static const _kArabicSize = 'reading_arabic_text_size';
  static const _kTranslationSize = 'reading_translation_text_size';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = ReadingPreferences(
      arabicFont: ArabicFontX.fromName(p.getString(_kFont)),
      showTranslation: p.getBool(_kShowTranslation) ?? true,
      showTransliteration: p.getBool(_kShowTransliteration) ?? false,
      arabicTextSize: p.getDouble(_kArabicSize) ?? 28,
      translationTextSize: p.getDouble(_kTranslationSize) ?? 14,
    );
  }

  Future<void> setFont(ArabicFont font) async {
    state = state.copyWith(arabicFont: font);
    (await SharedPreferences.getInstance()).setString(_kFont, font.name);
  }

  Future<void> setShowTranslation(bool value) async {
    state = state.copyWith(showTranslation: value);
    (await SharedPreferences.getInstance())
        .setBool(_kShowTranslation, value);
  }

  Future<void> setShowTransliteration(bool value) async {
    state = state.copyWith(showTransliteration: value);
    (await SharedPreferences.getInstance())
        .setBool(_kShowTransliteration, value);
  }

  Future<void> setArabicTextSize(double value) async {
    state = state.copyWith(arabicTextSize: value);
    (await SharedPreferences.getInstance())
        .setDouble(_kArabicSize, value);
  }

  Future<void> setTranslationTextSize(double value) async {
    state = state.copyWith(translationTextSize: value);
    (await SharedPreferences.getInstance())
        .setDouble(_kTranslationSize, value);
  }
}

final readingPreferencesProvider =
    StateNotifierProvider<ReadingPreferencesController, ReadingPreferences>(
  (ref) => ReadingPreferencesController(),
);
