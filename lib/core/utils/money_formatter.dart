import 'package:intl/intl.dart';

/// Utilities for converting and formatting EGP/USD amounts safely using integer piasters.
abstract final class MoneyFormatter {
  static final NumberFormat _egpFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'EGP ',
    decimalDigits: 2,
  );

  static final NumberFormat _usdFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 2,
  );

  /// Formats integer piasters as `EGP 1,245.00` (or `-EGP 64.20` when [signed] is true).
  static String formatEgp(int amountMinor, {bool signed = false}) {
    final absFormatted = _egpFormat.format(amountMinor.abs() / 100);
    if (signed && amountMinor > 0) {
      return '-$absFormatted';
    }
    if (amountMinor < 0) {
      return '-$absFormatted';
    }
    return absFormatted;
  }

  /// Formats integer piasters as plain editable decimal string, e.g. `24.50`.
  static String formatEditable(int amountMinor) {
    return (amountMinor / 100).toStringAsFixed(2);
  }

  /// Formats an approximate USD value from EGP minor units and an EGP->USD rate.
  static String formatApproxUsd(int amountMinor, double rate) {
    final usd = (amountMinor / 100) * rate;
    return _usdFormat.format(usd);
  }

  /// Parses decimal input (e.g. `"85"`, `"85.5"`, `"85.50"`) into integer piasters.
  /// Returns `null` if invalid, non-positive, or has more than 2 decimal places.
  static int? parseToMinor(String raw) {
    final cleaned = raw.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;

    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) return null;

    final whole = int.tryParse(match.group(1)!);
    if (whole == null) return null;

    final fracRaw = match.group(2) ?? '';
    final fracPadded = fracRaw.padRight(2, '0');
    final frac = int.tryParse(fracPadded) ?? 0;

    final minor = whole * 100 + frac;
    return minor > 0 ? minor : null;
  }

  /// Formats a [DateTime] into `yyyy-MM` for Firestore budget keys and Hive prefs.
  static String monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  /// Parses a `yyyy-MM` string back into a [DateTime] on the 1st of that month.
  static DateTime? parseMonthKey(String key) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month, 1);
  }
}
