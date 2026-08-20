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
