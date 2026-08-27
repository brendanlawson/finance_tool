import 'package:finance_tool/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('parses decimal strings into exact minor units for a 2-decimal currency', () {
      final money = Money.parse('1234.56', 'USD');
      expect(money.minorUnits, 123456);
    });

    test('parses whole numbers for a zero-decimal currency (VND)', () {
      final money = Money.parse('23000000', 'VND');
      expect(money.minorUnits, 23000000);
      expect(money.toDecimalString(), '23000000');
    });

    test('rejects more fractional digits than the currency supports', () {
      expect(() => Money.parse('1.005', 'USD'), throwsFormatException);
    });

    test('parses negative amounts', () {
      final money = Money.parse('-50.00', 'USD');
      expect(money.minorUnits, -5000);
      expect(money.isNegative, isTrue);
    });

    test('addition and subtraction are exact, never floating point', () {
      final a = Money.parse('0.10', 'USD');
      final b = Money.parse('0.20', 'USD');
      expect((a + b).toDecimalString(), '0.30');
    });

    test('arithmetic across different currencies throws', () {
      final vnd = Money(minorUnits: 1000, currencyCode: 'VND');
      final usd = Money(minorUnits: 1000, currencyCode: 'USD');
      expect(() => vnd + usd, throwsA(isA<CurrencyMismatchException>()));
    });

    test('comparison operators respect currency and magnitude', () {
      final a = Money(minorUnits: 100, currencyCode: 'USD');
      final b = Money(minorUnits: 200, currencyCode: 'USD');
      expect(a < b, isTrue);
      expect(b > a, isTrue);
      expect(a <= a, isTrue);
    });

    test('zero amount is neither positive nor negative', () {
      final zero = Money.zero('USD');
      expect(zero.isZero, isTrue);
      expect(zero.isPositive, isFalse);
      expect(zero.isNegative, isFalse);
    });
  });
}
