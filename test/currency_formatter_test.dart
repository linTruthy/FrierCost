// test/currency_formatter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:frier_cost/currency_formatter.dart';

void main() {
  final fmt = CurrencyFormatter();

  group('CurrencyFormatter', () {
    test('format & parse inverse', () {
      final original = 1234567;
      final formatted = fmt.format(original);
      expect(fmt.parse(formatted), original);
    });

    test('formatWithoutSymbol', () {
      expect(fmt.formatWithoutSymbol(10000), '10,000');
    });

    test('formatCompact for thousands', () {
      // e.g. 1500 → USh1.5K
      final compact = fmt.formatCompact(1500);
      expect(compact.contains('1.5'), isTrue);
    });

    test('formatWithPrecision respects decimalDigits', () {
      expect(fmt.formatWithPrecision(1234.56, 2), contains('.56'));
    });

    test('formatWithSign prefixes "+" for positive amounts', () {
      final signed = fmt.formatWithSign(500);
      expect(signed.startsWith('+'), isTrue);
    });

    test('currencySymbol is USh', () {
      expect(fmt.currencySymbol, 'USh');
    });

    test('extension toUgx and toUgxCompact', () {
      expect((2000).toUgx().contains('2,000'), isTrue);
      expect((2000).toUgxCompact().contains('2.0'), isTrue);
    });
  });
}
