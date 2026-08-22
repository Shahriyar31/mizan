/// MP3Quran API v3 — https://mp3quran.net/api
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../shared/models/reciter.dart';

class Mp3QuranService {
  Mp3QuranService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _tag = 'Mp3QuranService';
  static const String _base = 'https://mp3quran.net/api/v3';

  Future<List<Reciter>> getReciters({String language = 'eng'}) async {
    try {
      final uri =
          Uri.parse('$_base/reciters').replace(queryParameters: {'language': language});
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw NetworkException(
          message: 'MP3Quran API returned ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['reciters'] as List? ?? [];
      return list
          .map((r) => Reciter.fromJson(r as Map<String, dynamic>))
          .toList();
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.error('Failed to fetch reciters', error: e, tag: _tag);
      throw NetworkException(message: 'Could not reach MP3Quran: $e');
    }
  }
}
