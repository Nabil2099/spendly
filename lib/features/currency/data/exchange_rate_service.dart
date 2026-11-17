import 'package:dio/dio.dart';

/// Exchange rate snapshot from Frankfurter v2 (`EGP -> USD`).
class ExchangeRate {
  const ExchangeRate({required this.rate, required this.date});

  final double rate;
  final String date;
}

/// Fetches the latest EGP -> USD reference exchange rate via Dio.
/// Returns `null` when offline or unavailable so expense flows are never blocked.
class ExchangeRateService {
  ExchangeRateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.frankfurter.dev',
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
            ),
          );

  final Dio _dio;
  ExchangeRate? _cached;

  Future<ExchangeRate?> getEgpToUsd({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached;

    try {
      final response = await _dio.get<Map<String, dynamic>>('/v2/rate/EGP/USD');
      final data = response.data;
      if (data == null) return null;

      final rate = (data['rate'] as num?)?.toDouble();
      final date = data['date'] as String?;
      if (rate == null || rate <= 0 || date == null || date.isEmpty) {
        return null;
      }

      _cached = ExchangeRate(rate: rate, date: date);
      return _cached;
    } catch (_) {
      return _cached;
    }
  }
}
