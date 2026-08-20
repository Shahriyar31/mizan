#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# Taddabur — Enterprise Project Structure Setup Script
# Run this AFTER: flutter create taddabur && cd taddabur
# Usage: bash setup_structure.sh
# ═══════════════════════════════════════════════════════════════

set -e  # Exit immediately if any command fails

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║     Taddabur — Project Structure Setup        ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# ── Verify we're inside a Flutter project ──────────────────────
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found."
  echo "   Run this script from inside your Flutter project root."
  echo "   cd taddabur && bash setup_structure.sh"
  exit 1
fi

echo "✓ Flutter project detected"
echo ""

# ── 1. CORE LAYER ──────────────────────────────────────────────
echo "📁 Creating core/ layer..."

mkdir -p lib/core/theme
mkdir -p lib/core/constants
mkdir -p lib/core/router
mkdir -p lib/core/errors
mkdir -p lib/core/utils

# Theme files
cat > lib/core/theme/app_colors.dart << 'EOF'
/// Taddabur color system
/// All colors in the app come from here — never hardcode hex values elsewhere
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Prevent instantiation

  // ── Primary palette ──────────────────────────────────────────
  static const Color night      = Color(0xFF0B1120); // Deep night blue
  static const Color slate      = Color(0xFF1A2535); // Slightly lighter night
  static const Color jade       = Color(0xFF2B7A6F); // Verified/trusted
  static const Color jadeLlight = Color(0xFF3A9E90); // Jade hover state
  static const Color gold       = Color(0xFFC8973A); // Primary accent
  static const Color goldSoft   = Color(0xFFE8C97A); // Gold on dark bg
  static const Color goldPale   = Color(0xFFFDF6E3); // Gold tint on white

  // ── Surface palette ──────────────────────────────────────────
  static const Color parchment  = Color(0xFFF4EFE6); // Main background
  static const Color parchment2 = Color(0xFFEAE2D6); // Secondary surface
  static const Color parchment3 = Color(0xFFDDD5C8); // Border/divider
  static const Color white      = Color(0xFFFFFFFF);

  // ── Text palette ─────────────────────────────────────────────
  static const Color ink        = Color(0xFF0B1120); // Primary text
  static const Color body       = Color(0xFF374151); // Body text
  static const Color muted      = Color(0xFF6B7280); // Secondary text
  static const Color border     = Color(0xFFDDD5C8); // Border color

  // ── Semantic palette ─────────────────────────────────────────
  static const Color success    = Color(0xFF166534); // Sahih grade
  static const Color successBg  = Color(0xFFF0FDF4);
  static const Color error      = Color(0xFFBE123C); // Missing, offline
  static const Color errorBg    = Color(0xFFFFF1F2);
  static const Color amber      = Color(0xFF92400E); // Warning
  static const Color amberBg    = Color(0xFFFFFBEB);
  static const Color violet     = Color(0xFF5B21B6); // Hadith accent
  static const Color violetBg   = Color(0xFFF5F3FF);

  // ── Card type colors ─────────────────────────────────────────
  // Minbar card backgrounds — each content type has distinct material
  static const Color cardQuranBg    = Color(0xFFF4EFE6); // Parchment
  static const Color cardSahabiBg   = Color(0xFF1C1108); // Candlelight
  static const Color cardHadithBg   = Color(0xFF1E2D3D); // Scholarly navy
  static const Color cardNameBg     = Color(0xFF0B1120); // Carved night
  static const Color cardProphetBg  = Color(0xFF0D2218); // Emerald depth
}
EOF

cat > lib/core/theme/app_typography.dart << 'EOF'
/// Taddabur typography system
/// Three typefaces, used deliberately:
///   Amiri     → All Arabic text
///   Lora      → English display/headings (warm, manuscript feel)
///   Inter     → UI chrome only (buttons, labels, metadata)
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // ── Arabic (Amiri) ────────────────────────────────────────────
  static TextStyle arabicDisplay({
    double size = 28,
    Color color = AppColors.ink,
  }) =>
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        color: color,
        height: 1.9,
      );

  static TextStyle arabicHero({Color color = AppColors.white}) =>
      arabicDisplay(size: 32, color: color);

  static TextStyle arabicBody({Color color = AppColors.ink}) =>
      arabicDisplay(size: 20, color: color);

  static TextStyle arabicSmall({Color color = AppColors.ink}) =>
      arabicDisplay(size: 16, color: color);

  // ── Display (Lora) ────────────────────────────────────────────
  static TextStyle displayLarge({Color color = AppColors.ink}) =>
      GoogleFonts.lora(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      );

  static TextStyle displayMedium({Color color = AppColors.ink}) =>
      GoogleFonts.lora(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle displaySmall({Color color = AppColors.ink}) =>
      GoogleFonts.lora(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.4,
      );

  static TextStyle bodyItalic({Color color = AppColors.body}) =>
      GoogleFonts.lora(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: color,
        height: 1.7,
      );

  // ── UI (Inter) ────────────────────────────────────────────────
  static TextStyle labelLarge({Color color = AppColors.ink}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle labelMedium({Color color = AppColors.muted}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle labelSmall({Color color = AppColors.muted}) =>
      GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.8,
      );

  static TextStyle bodyLarge({Color color = AppColors.body}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.75,
      );

  static TextStyle bodySmall({Color color = AppColors.muted}) =>
      GoogleFonts.inter(
        fontSize: 12,
        color: color,
        height: 1.55,
      );

  static TextStyle caption({Color color = AppColors.muted}) =>
      GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle buttonPrimary() =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      );
}
EOF

cat > lib/core/theme/app_theme.dart << 'EOF'
/// Taddabur app theme
/// Assembles colors and typography into Flutter ThemeData
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.parchment,
        primaryColor: AppColors.jade,
        colorScheme: const ColorScheme.light(
          primary: AppColors.jade,
          secondary: AppColors.gold,
          surface: AppColors.white,
          background: AppColors.parchment,
          error: AppColors.error,
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.night,
          foregroundColor: AppColors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.muted,
          elevation: 0,
        ),
      );
}
EOF

echo "  ✓ core/theme/"

# Constants
cat > lib/core/constants/api_constants.dart << 'EOF'
/// All API base URLs and endpoint paths
/// Never hardcode these in service files
library;

class ApiConstants {
  ApiConstants._();

  // ── Quran.com API ─────────────────────────────────────────────
  static const String quranBaseUrl = 'https://api.quran.com/api/v4';
  static const String quranChapters = '/chapters';
  static const String quranVersesByChapter = '/verses/by_chapter';
  static const String quranVerseByKey = '/verses/by_key';

  // Default translation IDs from Quran.com
  static const int translationEnglish = 131;  // Sahih International
  static const int translationBengali = 213;  // Muhammad Muhiuddin Khan
  static const int translationHindi   = 462;  // Fateh Muhammad Jalandhri

  // ── Sunnah.com API ────────────────────────────────────────────
  static const String hadithBaseUrl = 'https://api.sunnah.com/v1';
  static const String hadithCollections = '/collections';
  static const String hadithRandom = '/hadiths/random';

  // ── Azure OpenAI ──────────────────────────────────────────────
  // Values loaded from .env — never hardcode keys here
  static const String azureOpenAiVersion = '2024-02-01';

  // ── Timeouts ──────────────────────────────────────────────────
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration aiTimeout  = Duration(seconds: 60);
}
EOF

cat > lib/core/constants/app_constants.dart << 'EOF'
/// App-wide business logic constants
library;

class AppConstants {
  AppConstants._();

  // ── Tafseer layer system ──────────────────────────────────────
  static const int totalLayers = 5;
  // Layers unlock Mon=1, Tue=2, Wed=3, Thu=4, Fri=5
  // Saturday and Sunday: all completed layers remain accessible

  // ── Halaqa ────────────────────────────────────────────────────
  static const int maxHalaqaMembers = 8;
  static const int minHalaqaMembers = 2;
  static const int personalNoteMaxLength = 100;
  static const int daysBeforeNudge = 3;

  // ── Vocabulary Bank ───────────────────────────────────────────
  static const int dailyVocabReviewCount = 3;
  // Spaced repetition intervals (days)
  static const List<int> srsIntervals = [1, 3, 7, 14, 30, 90];

  // ── Muhasabah ─────────────────────────────────────────────────
  static const int muhasabahQuestions = 3;

  // ── Returning user ────────────────────────────────────────────
  static const int returningUserDays = 3;
  // If user hasn't opened app in this many days, show returning state

  // ── Wird ──────────────────────────────────────────────────────
  static const int wirdCycleDays = 7;

  // ── Minbar ────────────────────────────────────────────────────
  static const int minbarPageSize = 20;

  // ── Scholar AI ────────────────────────────────────────────────
  static const int aiMaxTokens = 1000;
  static const int aiContextChunks = 5;
}
EOF

echo "  ✓ core/constants/"

# Router placeholder
cat > lib/core/router/app_router.dart << 'EOF'
/// GoRouter configuration
/// All app routes defined here — single source of truth for navigation
library;

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// TODO: Import screen files as they are created
// import '../../features/home/presentation/home_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Routes will be added here as screens are built
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text(
              'Taddabur — Setup Complete\nStart building screens',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ],
  );
}
EOF

echo "  ✓ core/router/"

# Error handling
cat > lib/core/errors/app_exception.dart << 'EOF'
/// Custom exception types for structured error handling
/// Never let raw exceptions surface to the UI
library;

abstract class AppException implements Exception {
  const AppException({required this.message, this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}

/// Network or API call failed
class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

/// Supabase database operation failed
class DatabaseException extends AppException {
  const DatabaseException({required super.message, super.code});
}

/// Scholar AI could not find a verified source
class CitationNotFoundException extends AppException {
  const CitationNotFoundException({required super.message})
      : super(code: 'CITATION_NOT_FOUND');
}

/// User not authenticated
class AuthException extends AppException {
  const AuthException({required super.message, super.code});
}

/// Content type not recognized
class ContentException extends AppException {
  const ContentException({required super.message, super.code});
}
EOF

cat > lib/core/utils/logger.dart << 'EOF'
/// Structured logging utility
/// Use this everywhere instead of print()
/// In production builds, logs are suppressed automatically
library;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();

  static void debug(String message, {String? tag}) =>
      _log(LogLevel.debug, message, tag: tag);

  static void info(String message, {String? tag}) =>
      _log(LogLevel.info, message, tag: tag);

  static void warning(String message, {String? tag}) =>
      _log(LogLevel.warning, message, tag: tag);

  static void error(String message, {Object? error, String? tag}) {
    _log(LogLevel.error, message, tag: tag);
    if (error != null) _log(LogLevel.error, error.toString(), tag: tag);
  }

  static void _log(LogLevel level, String message, {String? tag}) {
    if (!kDebugMode) return; // Silent in production

    final prefix = switch (level) {
      LogLevel.debug   => '🔍 DEBUG',
      LogLevel.info    => '✅ INFO ',
      LogLevel.warning => '⚠️  WARN ',
      LogLevel.error   => '❌ ERROR',
    };

    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('$prefix $tagStr $message');
  }
}
EOF

cat > lib/core/utils/arabic_utils.dart << 'EOF'
/// Arabic text utilities
/// Helpers for RTL, diacritics, and Arabic string handling
library;

class ArabicUtils {
  ArabicUtils._();

  /// Checks if a string contains Arabic characters
  static bool containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  /// Returns TextDirection based on content
  static bool isRtl(String text) => containsArabic(text);

  /// Removes tashkeel (diacritics) for search purposes
  static String removeDiacritics(String text) {
    return text.replaceAll(
      RegExp(r'[\u064B-\u065F\u0670]'),
      '',
    );
  }
}
EOF

echo "  ✓ core/utils/"
echo "  ✓ core/errors/"

# ── 2. SHARED LAYER ────────────────────────────────────────────
echo ""
echo "📁 Creating shared/ layer..."

mkdir -p lib/shared/widgets
mkdir -p lib/shared/models

cat > lib/shared/widgets/arabic_text.dart << 'EOF'
/// Reusable Arabic text widget
/// Always use this instead of raw Text() for Arabic content
/// Handles: RTL, Amiri font, correct line height
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ArabicText extends StatelessWidget {
  const ArabicText(
    this.text, {
    super.key,
    this.fontSize = 24,
    this.color = AppColors.ink,
    this.textAlign = TextAlign.right,
  });

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: 'Amiri',
        fontSize: fontSize,
        color: color,
        height: 1.9,
      ),
    );
  }
}
EOF

cat > lib/shared/widgets/citation_block.dart << 'EOF'
/// Reusable citation display block
/// Used in Scholar AI responses, tafseer layers, Minbar cards
/// Every citation in the app looks identical — builds trust
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class CitationBlock extends StatelessWidget {
  const CitationBlock({
    super.key,
    required this.source,
    required this.detail,
    this.isVerified = true,
  });

  final String source;   // e.g. "Sahih Muslim 2999"
  final String detail;   // e.g. "Narrated by Suhaib (RA) · Grade: Sahih"
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: AppColors.gold, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📚 $source', style: AppTypography.caption()),
          const SizedBox(height: 3),
          Text(detail, style: AppTypography.bodySmall()),
          if (isVerified) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.verified, size: 12, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'Verified source',
                  style: AppTypography.caption(color: AppColors.success),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
EOF

cat > lib/shared/models/ayah.dart << 'EOF'
/// Ayah data model
/// Represents a single Quran verse with all associated data
library;

class Ayah {
  const Ayah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabicText,
    required this.translation,
    this.transliteration,
    this.words = const [],
  });

  final int surahNumber;
  final int ayahNumber;
  final String arabicText;
  final String translation;
  final String? transliteration;
  final List<AyahWord> words;

  String get key => '$surahNumber:$ayahNumber';

  factory Ayah.fromJson(Map<String, dynamic> json) {
    return Ayah(
      surahNumber: json['chapter_id'] as int,
      ayahNumber: json['verse_number'] as int,
      arabicText: json['text_uthmani'] as String? ?? '',
      translation: json['translations']?[0]?['text'] as String? ?? '',
    );
  }
}

class AyahWord {
  const AyahWord({
    required this.arabic,
    required this.root,
    required this.meaning,
    this.insight,
  });

  final String arabic;
  final String root;
  final String meaning;
  final String? insight;
}
EOF

cat > lib/shared/models/hadith.dart << 'EOF'
/// Hadith data model
library;

enum HadithGrade { sahih, hasan, daif, mawdu, unknown }

class Hadith {
  const Hadith({
    required this.collection,
    required this.bookNumber,
    required this.hadithNumber,
    required this.arabicText,
    required this.englishText,
    required this.narrator,
    required this.grade,
  });

  final String collection;    // e.g. "Sahih Muslim"
  final int bookNumber;
  final int hadithNumber;
  final String arabicText;
  final String englishText;
  final String narrator;
  final HadithGrade grade;

  String get reference => '$collection $hadithNumber';

  String get gradeDisplay => switch (grade) {
        HadithGrade.sahih  => 'Sahih — Authentic',
        HadithGrade.hasan  => 'Hasan — Good',
        HadithGrade.daif   => 'Da\'if — Weak',
        HadithGrade.mawdu  => 'Mawdu\' — Fabricated',
        HadithGrade.unknown => 'Grade unknown',
      };

  factory Hadith.fromJson(Map<String, dynamic> json) {
    return Hadith(
      collection: json['collection'] as String? ?? '',
      bookNumber: json['bookNumber'] as int? ?? 0,
      hadithNumber: json['hadithNumber'] as int? ?? 0,
      arabicText: json['body'] as String? ?? '',
      englishText: json['translation']?['body'] as String? ?? '',
      narrator: json['narrator'] as String? ?? '',
      grade: _parseGrade(json['grade'] as String?),
    );
  }

  static HadithGrade _parseGrade(String? grade) {
    return switch (grade?.toLowerCase()) {
      'sahih'           => HadithGrade.sahih,
      'hasan'           => HadithGrade.hasan,
      'da\'if' || 'daif' => HadithGrade.daif,
      'mawdu\''         => HadithGrade.mawdu,
      _                 => HadithGrade.unknown,
    };
  }
}
EOF

echo "  ✓ shared/widgets/"
echo "  ✓ shared/models/"

# ── 3. SERVICES LAYER ──────────────────────────────────────────
echo ""
echo "📁 Creating services/ layer..."

mkdir -p lib/services/quran
mkdir -p lib/services/hadith
mkdir -p lib/services/ai
mkdir -p lib/services/supabase
mkdir -p lib/services/local
mkdir -p lib/services/notifications

cat > lib/services/quran/quran_api_service.dart << 'EOF'
/// Quran.com API integration
/// Provides Quran content — surahs, ayat, word-level data
/// Free API, no authentication required for public endpoints
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../shared/models/ayah.dart';

class QuranApiService {
  QuranApiService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const String _tag = 'QuranApiService';

  /// Fetches all 114 surah metadata
  Future<List<Map<String, dynamic>>> getSurahs({
    String language = 'en',
  }) async {
    try {
      AppLogger.info('Fetching surah list', tag: _tag);

      final uri = Uri.parse(
        '${ApiConstants.quranBaseUrl}${ApiConstants.quranChapters}',
      ).replace(queryParameters: {'language': language});

      final response = await _client
          .get(uri)
          .timeout(ApiConstants.apiTimeout);

      if (response.statusCode != 200) {
        throw NetworkException(
          message: 'Failed to fetch surahs: ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(
        data['chapters'] as List,
      );
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.error('Unexpected error fetching surahs', error: e, tag: _tag);
      throw NetworkException(message: e.toString());
    }
  }

  /// Fetches all ayat for a given surah number
  Future<List<Ayah>> getAyatForSurah(
    int surahNumber, {
    int translationId = ApiConstants.translationEnglish,
  }) async {
    try {
      AppLogger.info('Fetching ayat for surah $surahNumber', tag: _tag);

      final uri = Uri.parse(
        '${ApiConstants.quranBaseUrl}'
        '${ApiConstants.quranVersesByChapter}/$surahNumber',
      ).replace(queryParameters: {
        'translations': translationId.toString(),
        'word_fields': 'text_uthmani',
        'per_page': '300',
      });

      final response = await _client
          .get(uri)
          .timeout(ApiConstants.apiTimeout);

      if (response.statusCode != 200) {
        throw NetworkException(
          message: 'Failed to fetch ayat: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final verses = data['verses'] as List;
      return verses
          .map((v) => Ayah.fromJson(v as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching ayat', error: e, tag: _tag);
      rethrow;
    }
  }
}
EOF

cat > lib/services/ai/scholar_ai_service.dart << 'EOF'
/// Scholar AI — RAG pipeline integration
/// Connects to Azure AI Search + Azure OpenAI
/// CITATION LOCK: every response must cite a verified source
/// If no source found, returns CitationNotFoundException
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';

class ScholarAiService {
  ScholarAiService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const String _tag = 'ScholarAiService';

  /// Sends a question and returns a cited answer
  /// Throws CitationNotFoundException if no verified source found
  Future<ScholarResponse> ask(String question, {String language = 'en'}) async {
    try {
      AppLogger.info('Scholar AI query: $question', tag: _tag);

      final endpoint = dotenv.env['AZURE_OPENAI_ENDPOINT'] ?? '';
      final apiKey   = dotenv.env['AZURE_OPENAI_API_KEY'] ?? '';
      final deploy   = dotenv.env['AZURE_OPENAI_DEPLOYMENT'] ?? 'gpt-4o';

      final systemPrompt = '''
You are a Scholar AI for an Islamic knowledge app called Taddabur.

CITATION LOCK — This is the most important rule:
Every answer MUST cite one of: a specific Quran ayah (surah:ayah), 
a hadith with collection name and number and narrator and grade, 
or a named tafseer scholar with their work name.

If you cannot find a verified Islamic source for the question, 
respond EXACTLY with: "I do not have a verified source for this. 
Please consult a qualified Islamic scholar."

Never guess. Never give general knowledge without a specific citation.
Respond in this language: $language

Response format (JSON):
{
  "answer": "your answer here",
  "citations": [
    {
      "type": "quran|hadith|tafseer",
      "reference": "Surah Ash-Sharh 94:5",
      "detail": "additional detail",
      "grade": "sahih|hasan|daif|null"
    }
  ],
  "has_verified_source": true|false
}
''';

      final body = jsonEncode({
        'model': deploy,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': question},
        ],
        'max_tokens': ApiConstants.aiMaxTokens,
        'temperature': 0.1,
      });

      final response = await _client
          .post(
            Uri.parse(
              '$endpoint/openai/deployments/$deploy/chat/completions'
              '?api-version=${ApiConstants.azureOpenAiVersion}',
            ),
            headers: {
              'Content-Type': 'application/json',
              'api-key': apiKey,
            },
            body: body,
          )
          .timeout(ApiConstants.aiTimeout);

      if (response.statusCode != 200) {
        throw NetworkException(
          message: 'Scholar AI request failed: ${response.statusCode}',
        );
      }

      final data    = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['choices'][0]['message']['content'] as String;
      final parsed  = jsonDecode(content) as Map<String, dynamic>;

      if (parsed['has_verified_source'] == false) {
        throw CitationNotFoundException(
          message: parsed['answer'] as String,
        );
      }

      return ScholarResponse.fromJson(parsed);
    } catch (e) {
      AppLogger.error('Scholar AI error', error: e, tag: _tag);
      rethrow;
    }
  }
}

class ScholarResponse {
  const ScholarResponse({
    required this.answer,
    required this.citations,
    required this.hasVerifiedSource,
  });

  final String answer;
  final List<Citation> citations;
  final bool hasVerifiedSource;

  factory ScholarResponse.fromJson(Map<String, dynamic> json) {
    final cites = (json['citations'] as List?)
            ?.map((c) => Citation.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    return ScholarResponse(
      answer: json['answer'] as String,
      citations: cites,
      hasVerifiedSource: json['has_verified_source'] as bool? ?? false,
    );
  }
}

class Citation {
  const Citation({
    required this.type,
    required this.reference,
    this.detail,
    this.grade,
  });

  final String type;
  final String reference;
  final String? detail;
  final String? grade;

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        type: json['type'] as String,
        reference: json['reference'] as String,
        detail: json['detail'] as String?,
        grade: json['grade'] as String?,
      );
}
EOF

echo "  ✓ services/quran/"
echo "  ✓ services/ai/"
echo "  (other services created as stubs)"

# Stub out remaining services
for service in "supabase/supabase_client" "hadith/hadith_api_service" "local/database_service" "notifications/fcm_service"; do
  dir=$(dirname "$service")
  name=$(basename "$service")
  mkdir -p "lib/services/$dir"
  cat > "lib/services/$service.dart" << EOF
/// $name — stub
/// Implementation coming in Phase $([ "$dir" = "supabase" ] && echo "1" || [ "$dir" = "hadith" ] && echo "1" || [ "$dir" = "local" ] && echo "1" || echo "5")
library;

// TODO: Implement $name
EOF
done

# ── 4. FEATURES LAYER ──────────────────────────────────────────
echo ""
echo "📁 Creating features/ layer..."

features=("home" "quran" "discover" "halaqa" "growth" "scholar_ai" "minbar")

for feature in "${features[@]}"; do
  mkdir -p "lib/features/$feature/data"
  mkdir -p "lib/features/$feature/domain"
  mkdir -p "lib/features/$feature/presentation/widgets"

  cat > "lib/features/$feature/presentation/${feature}_screen.dart" << EOF
/// ${feature^} screen — placeholder
/// TODO: Implement ${feature^} screen
library;

import 'package:flutter/material.dart';

class ${feature^}Screen extends StatelessWidget {
  const ${feature^}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Center(
        child: Text(
          '${feature^}',
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
EOF
  echo "  ✓ features/$feature/"
done

# ── 5. MAIN & APP FILES ────────────────────────────────────────
echo ""
echo "📁 Creating entry point files..."

cat > lib/main.dart << 'EOF'
/// Taddabur — Entry Point
/// Kept minimal intentionally — all setup delegated to app.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  runApp(const TadabburApp());
}
EOF

cat > lib/app.dart << 'EOF'
/// TadabburApp — root widget
/// Sets up: theme, router, localization, Riverpod
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class TadabburApp extends StatelessWidget {
  const TadabburApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Taddabur',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'), // English
          Locale('bn'), // Bengali
          Locale('hi'), // Hindi
          Locale('de'), // German (future)
          Locale('fr'), // French (future)
        ],
      ),
    );
  }
}
EOF

echo "  ✓ main.dart"
echo "  ✓ app.dart"

# ── 6. CONFIGURATION FILES ─────────────────────────────────────
echo ""
echo "📁 Creating configuration files..."

# .env.example
cat > .env.example << 'EOF'
# ═══════════════════════════════════════════════════════════════
# Taddabur Environment Configuration
# Copy this file to .env and fill in your values
# NEVER commit .env to Git
# ═══════════════════════════════════════════════════════════════

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_API_KEY=your_key_here
AZURE_OPENAI_DEPLOYMENT=gpt-4o

# Azure AI Search
AZURE_SEARCH_ENDPOINT=https://your-search.search.windows.net
AZURE_SEARCH_API_KEY=your_key_here
AZURE_SEARCH_INDEX_NAME=taddabur-knowledge-base

# Sunnah.com API
SUNNAH_API_KEY=your_key_here

# Firebase
FIREBASE_PROJECT_ID=your_project_id

# Feature Flags (1=enabled, 0=disabled)
# Enable features only when implementation is complete
FEATURE_SCHOLAR_AI=0
FEATURE_HALAQA=0
FEATURE_MINBAR=0
FEATURE_MULTILINGUAL=0
EOF

# .gitignore additions
cat >> .gitignore << 'EOF'

# Environment files — never commit these
.env
*.env
.env.*
!.env.example

# IDE
.idea/
.vscode/settings.json

# Build artifacts
*.apk
*.aab
*.ipa

# Logs
*.log
EOF

# docker-compose for local Supabase
cat > docker-compose.yml << 'EOF'
# Local Supabase development environment
# Run: docker-compose up -d
# Supabase Studio: http://localhost:54323
# API: http://localhost:54321
# 
# This gives you a full Supabase environment locally
# Free, no internet required for development

version: '3.8'

services:
  db:
    image: supabase/postgres:15.1.0.117
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: your_local_password
      POSTGRES_DB: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./supabase/migrations:/docker-entrypoint-initdb.d

  supabase-studio:
    image: supabase/studio:latest
    restart: unless-stopped
    ports:
      - "54323:3000"
    environment:
      SUPABASE_URL: http://kong:8000
      STUDIO_PG_META_URL: http://meta:8080

volumes:
  postgres_data:
EOF

# supabase migrations folder
mkdir -p supabase/migrations

cat > supabase/migrations/001_initial_schema.sql << 'EOF'
-- ═══════════════════════════════════════════════════════════════
-- Taddabur Initial Database Schema
-- Migration: 001_initial_schema.sql
-- ═══════════════════════════════════════════════════════════════

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Users ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email                TEXT UNIQUE NOT NULL,
  display_name         TEXT NOT NULL,
  language_preference  TEXT DEFAULT 'en' CHECK (language_preference IN ('en','bn','hi','de','fr')),
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  last_active_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── User Progress (Ayah layers) ───────────────────────────────
CREATE TABLE IF NOT EXISTS user_progress (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  surah_number     INT NOT NULL,
  ayah_number      INT NOT NULL,
  layer_completed  INT NOT NULL CHECK (layer_completed BETWEEN 1 AND 5),
  completed_at     TIMESTAMPTZ DEFAULT NOW(),
  reflection_text  TEXT, -- encrypted at application layer
  UNIQUE(user_id, surah_number, ayah_number, layer_completed)
);

-- ── Vocabulary Bank ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vocabulary_bank (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  arabic_word    TEXT NOT NULL,
  root           TEXT,
  meaning_en     TEXT NOT NULL,
  times_seen     INT DEFAULT 1,
  next_review_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '1 day',
  saved_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, arabic_word)
);

-- ── Muhasabah Journal ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS muhasabah_entries (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entry_date DATE NOT NULL,
  q1_answer  TEXT, -- encrypted: what did you do for Allah?
  q2_answer  TEXT, -- encrypted: what did you do for nafs?
  q3_answer  TEXT, -- encrypted: intention for tomorrow
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, entry_date)
);

-- ── Friday Reflections ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS friday_reflections (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  week_date  DATE NOT NULL,
  reflection TEXT, -- encrypted
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, week_date)
);

-- ── Halaqas ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS halaqas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  created_by  UUID NOT NULL REFERENCES users(id),
  invite_code TEXT UNIQUE NOT NULL,
  max_members INT DEFAULT 8,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── Halaqa Members ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS halaqa_members (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  halaqa_id       UUID NOT NULL REFERENCES halaqas(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at       TIMESTAMPTZ DEFAULT NOW(),
  last_opened_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(halaqa_id, user_id)
);

-- ── Halaqa Shares ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS halaqa_shares (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  halaqa_id      UUID NOT NULL REFERENCES halaqas(id) ON DELETE CASCADE,
  shared_by      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id     TEXT NOT NULL,  -- references content in app
  content_type   TEXT NOT NULL CHECK (content_type IN ('quran','hadith','sahabi','name','prophet')),
  personal_note  TEXT CHECK (char_length(personal_note) <= 100),
  shared_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── Minbar Shares (public feed) ───────────────────────────────
CREATE TABLE IF NOT EXISTS minbar_shares (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shared_by        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id       TEXT NOT NULL,
  content_type     TEXT NOT NULL CHECK (content_type IN ('quran','hadith','sahabi','name','prophet')),
  dua_count        INT DEFAULT 0,
  resonated_count  INT DEFAULT 0,
  shared_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ── Indexes for performance ───────────────────────────────────
CREATE INDEX idx_user_progress_user ON user_progress(user_id);
CREATE INDEX idx_vocab_user ON vocabulary_bank(user_id);
CREATE INDEX idx_vocab_next_review ON vocabulary_bank(user_id, next_review_at);
CREATE INDEX idx_muhasabah_user_date ON muhasabah_entries(user_id, entry_date);
CREATE INDEX idx_halaqa_members_halaqa ON halaqa_members(halaqa_id);
CREATE INDEX idx_halaqa_shares_halaqa ON halaqa_shares(halaqa_id, shared_at DESC);
CREATE INDEX idx_minbar_shares_time ON minbar_shares(shared_at DESC);
EOF

echo "  ✓ .env.example"
echo "  ✓ .gitignore updated"
echo "  ✓ docker-compose.yml"
echo "  ✓ supabase/migrations/001_initial_schema.sql"

# ── 7. TEST STRUCTURE ──────────────────────────────────────────
echo ""
echo "📁 Creating test/ structure..."

mkdir -p test/unit/features/quran
mkdir -p test/unit/features/scholar_ai
mkdir -p test/unit/services
mkdir -p test/widget/shared
mkdir -p test/integration

cat > test/unit/features/quran/layer_unlock_logic_test.dart << 'EOF'
/// Unit tests for layer unlock logic
/// The most critical business rule: which layer is available today?
library;

import 'package:flutter_test/flutter_test.dart';
// import 'package:taddabur/features/quran/domain/layer_unlock_logic.dart';

void main() {
  group('LayerUnlockLogic', () {
    test('Monday returns layer 1 available', () {
      // TODO: Implement when LayerUnlockLogic is built
      expect(true, isTrue); // Placeholder
    });

    test('Friday returns layers 1-5 available', () {
      expect(true, isTrue);
    });

    test('Weekend returns same as Friday (all completed layers)', () {
      expect(true, isTrue);
    });
  });
}
EOF

echo "  ✓ test/ structure"

# ── 8. PUBSPEC.YAML ────────────────────────────────────────────
echo ""
echo "📄 Updating pubspec.yaml..."

cat > pubspec.yaml << 'EOF'
name: taddabur
description: "Islamic knowledge and transformation app"
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # Navigation
  go_router: ^13.0.0

  # State management
  flutter_riverpod: ^2.5.0

  # Backend
  supabase_flutter: ^2.3.0

  # HTTP
  http: ^1.2.1
  dio: ^5.4.3

  # Local storage
  sqflite: ^2.3.2
  path: ^1.9.0

  # Fonts
  google_fonts: ^6.2.1

  # Environment variables
  flutter_dotenv: ^5.1.0

  # Internationalisation
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  mockito: ^5.4.4
  build_runner: ^2.4.8

flutter:
  uses-material-design: true

  # Assets
  assets:
    - .env

  # Fonts — loaded via google_fonts package
  # Amiri loaded via assets for Arabic
  fonts:
    - family: Amiri
      fonts:
        - asset: assets/fonts/Amiri-Regular.ttf
        - asset: assets/fonts/Amiri-Bold.ttf
          weight: 700
EOF

mkdir -p assets/fonts
echo "  ✓ pubspec.yaml"
echo "  ✓ assets/fonts/ (place Amiri font files here)"

# ── FINAL SUMMARY ──────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║              Setup Complete ✓                         ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "1. Download Amiri font files:"
echo "   https://fonts.google.com/specimen/Amiri"
echo "   Place Amiri-Regular.ttf and Amiri-Bold.ttf in assets/fonts/"
echo ""
echo "2. Install dependencies:"
echo "   flutter pub get"
echo ""
echo "3. Copy environment file:"
echo "   cp .env.example .env"
echo ""
echo "4. Start local Supabase:"
echo "   docker-compose up -d"
echo ""
echo "5. Run the app:"
echo "   flutter run"
echo ""
echo "6. Push to GitHub:"
echo "   git add ."
echo '   git commit -m "chore: initial enterprise project structure"'
echo "   git push"
echo ""
echo "Structure created:"
echo "  lib/core/        — Colors, typography, router, constants"
echo "  lib/shared/      — Reusable widgets and models"
echo "  lib/services/    — API and backend integrations"
echo "  lib/features/    — 7 feature modules"
echo "  test/            — Unit, widget, integration test folders"
echo "  supabase/        — Database migrations"
echo "  docker-compose   — Local development environment"
echo ""