import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/utils/money_formatter.dart';
import '../../expenses/data/expense_model.dart';

/// Structured expense extracted by Gemini from natural language or a receipt image.
class ParsedExpenseDraft {
  const ParsedExpenseDraft({
    required this.title,
    this.amountMinor,
    required this.category,
    required this.date,
    this.note = '',
  });

  final String title;
  final int? amountMinor;
  final ExpenseCategory category;
  final DateTime date;
  final String note;

  factory ParsedExpenseDraft.fromJsonString(
    String raw, {
    DateTime? fallbackDate,
  }) {
    final decoded = _decodeJson(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return ParsedExpenseDraft.fromMap(decoded, fallbackDate: fallbackDate);
  }

  /// Parses a single JSON object, JSON array, or `{"items": [...]}` receipt response.
  static List<ParsedExpenseDraft> parseReceiptList(
    String raw, {
    DateTime? fallbackDate,
  }) {
    final decoded = _decodeJson(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => ParsedExpenseDraft.fromMap(m, fallbackDate: fallbackDate))
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final rawItems = decoded['items'];
      if (rawItems is List) {
        return rawItems
            .whereType<Map<String, dynamic>>()
            .map(
              (m) => ParsedExpenseDraft.fromMap(m, fallbackDate: fallbackDate),
            )
            .toList();
      }
      return [ParsedExpenseDraft.fromMap(decoded, fallbackDate: fallbackDate)];
    }
    throw const FormatException('Expected JSON object or items list');
  }

  static dynamic _decodeJson(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .trim();
    return jsonDecode(cleaned);
  }

  factory ParsedExpenseDraft.fromMap(
    Map<String, dynamic> decoded, {
    DateTime? fallbackDate,
  }) {

    final title = (decoded['title'] as String? ?? '').trim();
    final rawAmount = decoded['amount'];
    final amountText = rawAmount is num
        ? rawAmount.toStringAsFixed(2)
        : (rawAmount?.toString() ?? '');
    final amountMinor = MoneyFormatter.parseToMinor(amountText);

    final categoryId = (decoded['category'] as String? ?? '').toLowerCase();
    final category = ExpenseCategory.fromId(categoryId);

    final dateStr = (decoded['date'] as String? ?? '').trim();
    final parsedDate = DateTime.tryParse(dateStr);
    final baseDate = fallbackDate ?? DateTime.now();
    final resolvedDate = parsedDate != null
        ? DateTime(
            parsedDate.year,
            parsedDate.month,
            parsedDate.day,
            baseDate.hour,
            baseDate.minute,
          )
        : baseDate;

    final note = (decoded['note'] as String? ?? '').trim();

    return ParsedExpenseDraft(
      title: title,
      amountMinor: amountMinor,
      category: category,
      date: resolvedDate,
      note: note,
    );
  }
}

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
  Future<ParsedExpenseDraft> parseExpenseFromText(
    String input, {
    DateTime? now,
  });
  Future<List<ParsedExpenseDraft>> parseExpenseFromReceipt(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
    DateTime? now,
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

  @override
  Future<ParsedExpenseDraft> parseExpenseFromText(
    String input, {
    DateTime? now,
  }) async {
    final reference = now ?? DateTime.now();
    final todayIso =
        '${reference.year}-${reference.month.toString().padLeft(2, '0')}-${reference.day.toString().padLeft(2, '0')}';

    final text = await _generateJsonText(
      parts: [
        {
          'text':
              '''
Extract an expense from this user note: "$input"
Today's date is $todayIso.
Return ONLY a JSON object with:
- "title": short merchant or expense title (string)
- "amount": positive number in EGP (number, or null if not mentioned)
- "category": one of ["food", "transport", "bills", "shopping", "health", "entertainment", "other"]
- "date": ISO date "YYYY-MM-DD" (resolve "yesterday" or relative days from $todayIso)
- "note": optional extra detail (string, empty if none)
''',
        },
      ],
    );
    return ParsedExpenseDraft.fromJsonString(text, fallbackDate: reference);
  }

  @override
  Future<List<ParsedExpenseDraft>> parseExpenseFromReceipt(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
    DateTime? now,
  }) async {
    final reference = now ?? DateTime.now();
    final todayIso =
        '${reference.year}-${reference.month.toString().padLeft(2, '0')}-${reference.day.toString().padLeft(2, '0')}';

    final text = await _generateJsonText(
      parts: [
        {
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Encode(imageBytes),
          },
        },
        {
          'text':
              '''
Read this receipt image and extract EVERY purchased line item (or a single item if only a total is shown).
Today's date is $todayIso (use it if no date is visible on the receipt).
Return ONLY a JSON object with an "items" array:
{
  "items": [
    {
      "title": "item or merchant name (string)",
      "amount": 0.00,
      "category": "one of [food, transport, bills, shopping, health, entertainment, other]",
      "date": "YYYY-MM-DD",
      "note": "merchant name or optional detail (string)"
    }
  ]
}
''',
        },
      ],
    );
    final items = ParsedExpenseDraft.parseReceiptList(
      text,
      fallbackDate: reference,
    );
    if (items.isEmpty) {
      throw const GeminiFailure('No items could be read from this receipt.');
    }
    return items;
  }

  Future<String> _generateJsonText({
    required List<Map<String, dynamic>> parts,
  }) async {
    if (!isConfigured) {
      throw const GeminiFailure(
        'Gemini API key is missing. Add GEMINI_API_KEY to your .env file.',
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/models/$modelName:generateContent',
        queryParameters: {'key': _apiKey},
        data: {
          'contents': [
            {'role': 'user', 'parts': parts},
          ],
          'generationConfig': {
            'temperature': 0.1,
            'responseMimeType': 'application/json',
          },
        },
      );

      final candidates = response.data?['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const GeminiFailure('Could not extract expense details.');
      }

      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      final resParts = content?['parts'] as List<dynamic>?;
      final text = resParts != null && resParts.isNotEmpty
          ? (resParts.first as Map<String, dynamic>)['text'] as String?
          : null;

      if (text == null || text.trim().isEmpty) {
        throw const GeminiFailure('Could not extract expense details.');
      }

      return text;
    } on GeminiFailure {
      rethrow;
    } on FormatException {
      throw const GeminiFailure(
        'AI could not understand that expense. Try rephrasing or enter manually.',
      );
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
      throw const GeminiFailure('Could not parse expense details.');
    }
  }
}
