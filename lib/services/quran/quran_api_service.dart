/// Quran.com API integration — updated with word-level data
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../shared/models/ayah.dart';

class QuranApiService {
  QuranApiService({http.Client? client}) : _client = client ?? http.Client();

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

      final response = await _client.get(uri).timeout(ApiConstants.apiTimeout);

      if (response.statusCode != 200) {
        throw NetworkException(
          message: 'Failed to fetch surahs: ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['chapters'] as List);
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.error('Unexpected error fetching surahs', error: e, tag: _tag);
      throw NetworkException(message: e.toString());
    }
  }

  /// Fetches all ayat for a surah WITH word-level data
  /// 
  /// words=true — includes individual word objects
  /// word_fields — which data to include per word
  /// fields=text_uthmani — include full Arabic text per verse
  /// translations — English translation per verse
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
        'fields': 'text_uthmani',
        'words': 'true',
        'word_fields': 'text_uthmani,translation,transliteration',
        'per_page': '300',
      });

      final response = await _client.get(uri).timeout(ApiConstants.apiTimeout);

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
