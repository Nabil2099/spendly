import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/utils/money_formatter.dart';

void main() {
  group('MoneyFormatter.parseToMinor', () {
    test('parses whole and decimal EGP strings into piasters', () {
      expect(MoneyFormatter.parseToMinor('85'), 8500);
      expect(MoneyFormatter.parseToMinor('85.5'), 8550);
      expect(MoneyFormatter.parseToMinor('85.50'), 8550);
      expect(MoneyFormatter.parseToMinor('1,245.09'), 124509);
      expect(MoneyFormatter.parseToMinor('0.75'), 75);
    });

    test('rejects zero, negative, empty, and >2 decimal places', () {
      expect(MoneyFormatter.parseToMinor(''), isNull);
      expect(MoneyFormatter.parseToMinor('0'), isNull);
      expect(MoneyFormatter.parseToMinor('0.00'), isNull);
      expect(MoneyFormatter.parseToMinor('-10'), isNull);
      expect(MoneyFormatter.parseToMinor('12.345'), isNull);
      expect(MoneyFormatter.parseToMinor('abc'), isNull);
    });
  });

  group('MoneyFormatter formatting and month keys', () {
    test('formats EGP and approx USD', () {
      expect(MoneyFormatter.formatEgp(8500), 'EGP 85.00');
      expect(MoneyFormatter.formatEgp(8500, signed: true), '-EGP 85.00');
      expect(MoneyFormatter.formatApproxUsd(10000, 0.02), r'$2.00');
    });

    test('round-trips month keys', () {
      final date = DateTime(2026, 3, 15);
      final key = MoneyFormatter.monthKey(date);
      expect(key, '2026-03');
      expect(MoneyFormatter.parseMonthKey(key), DateTime(2026, 3, 1));
      expect(MoneyFormatter.parseMonthKey('invalid'), isNull);
    });
  });
}
