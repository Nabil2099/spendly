import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Single message in the Spendly AI advisor conversation.
class ChatMessage {
  const ChatMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
  });

  final bool isUser;
  final String text;
  final DateTime timestamp;
}

class GeminiFailure implements Exception {
  const GeminiFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Contract for sending financial advisor prompts to Gemini.
abstract class GeminiChatService {
  bool get isConfigured;
  String get modelName;
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String systemContext,
  });
}

/// Dio REST client for Google Gemini (`gemini-3.5-flash-lite` by default).
class HttpGeminiChatService implements GeminiChatService {
  HttpGeminiChatService({Dio? dio, String? apiKey, String? model})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 25),
            ),
          ),
      _overrideApiKey = apiKey,
      _overrideModel = model;

  static const String defaultModel = 'gemini-3.5-flash-lite';

  final Dio _dio;
  final String? _overrideApiKey;
  final String? _overrideModel;

  String get _apiKey =>
      (_overrideApiKey ?? _safeEnv('GEMINI_API_KEY') ?? '').trim();

  @override
  String get modelName {
    final envModel = (_overrideModel ?? _safeEnv('GEMINI_MODEL') ?? '').trim();
    return envModel.isNotEmpty ? envModel : defaultModel;
  }

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  String? _safeEnv(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key];
  }

  @override
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String systemContext,
  }) async {
    if (!isConfigured) {
      throw const GeminiFailure(
        'Gemini API key is missing. Add GEMINI_API_KEY to your .env file.',
      );
    }

    try {
      final contents = history.map((msg) {
        return {
          'role': msg.isUser ? 'user' : 'model',
          'parts': [
            {'text': msg.text},
          ],
        };
      }).toList();

      final response = await _dio.post<Map<String, dynamic>>(
        '/models/$modelName:generateContent',
        queryParameters: {'key': _apiKey},
        data: {
          'system_instruction': {
            'parts': [
              {'text': systemContext},
            ],
          },
          'contents': contents,
          'generationConfig': {'temperature': 0.5, 'maxOutputTokens': 512},
        },
      );

      final data = response.data;
      final candidates = data?['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const GeminiFailure('AI returned an empty response. Try again.');
      }

      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = parts != null && parts.isNotEmpty
          ? (parts.first as Map<String, dynamic>)['text'] as String?
          : null;

      if (text == null || text.trim().isEmpty) {
        throw const GeminiFailure('AI returned an empty response. Try again.');
      }

      return text.trim();
    } on GeminiFailure {
      rethrow;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 403) {
        throw const GeminiFailure(
          'Invalid Gemini API key or model. Check GEMINI_API_KEY in .env.',
        );
      }
      if (status == 429) {
        throw const GeminiFailure(
          'Gemini rate limit reached. Please wait a moment and try again.',
        );
      }
      throw const GeminiFailure(
        'Could not reach Gemini AI. Check your internet connection.',
      );
    } catch (_) {
      throw const GeminiFailure('Something went wrong talking to Gemini AI.');
    }
  }
}
