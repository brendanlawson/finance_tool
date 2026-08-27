import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import 'currency.dart';

/// A monetary amount represented as an exact integer count of minor units
/// (e.g. cents for USD, whole units for VND) plus its ISO 4217 currency
/// code.
///
/// Financial amounts are never stored or computed as `double`/`num`: binary
/// floating point cannot represent most decimal fractions exactly, so
/// repeated addition/subtraction of amounts (which is exactly what a ledger
/// does) accumulates rounding error. Integer minor units make every
/// arithmetic operation exact.
@immutable
class Money implements Comparable<Money> {
  final int minorUnits;
  final String currencyCode;

  const Money({required this.minorUnits, required this.currencyCode});

  factory Money.zero(String currencyCode) =>
      Money(minorUnits: 0, currencyCode: currencyCode);

  /// Parses a decimal major-unit string (e.g. "1234.56") into exact minor
  /// units for [currencyCode]. Intended for user-entered text fields, not
  /// for float math. Rejects more fractional digits than the currency
  /// supports rather than silently truncating.
  factory Money.parse(String input, String currencyCode) {
    final normalized = input.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      throw FormatException('Empty amount');
    }
    final negative = normalized.startsWith('-');
    final unsigned = negative ? normalized.substring(1) : normalized;
    final parts = unsigned.split('.');
    if (parts.length > 2) {
      throw FormatException('Invalid amount: $input');
    }
    final digits = Currency.minorUnitDigitsFor(currencyCode);
    final wholePart = parts[0].isEmpty ? '0' : parts[0];
    var fractionPart = parts.length == 2 ? parts[1] : '';
    if (fractionPart.length > digits) {
      throw FormatException(
        'Amount has more precision than $currencyCode supports ($digits '
        'decimal digits): $input',
      );
    }
    fractionPart = fractionPart.padRight(digits, '0');
    final combined = BigInt.parse(wholePart) * BigInt.from(_pow10(digits)) +
        BigInt.parse(fractionPart.isEmpty ? '0' : fractionPart);
    final value = (negative ? -combined : combined).toInt();
    return Money(minorUnits: value, currencyCode: currencyCode);
  }

  static int _pow10(int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;
  bool get isPositive => minorUnits > 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(
      minorUnits: minorUnits + other.minorUnits,
      currencyCode: currencyCode,
    );
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(
      minorUnits: minorUnits - other.minorUnits,
      currencyCode: currencyCode,
    );
  }

  Money operator -() => Money(minorUnits: -minorUnits, currencyCode: currencyCode);

  Money abs() => isNegative ? -this : this;

  void _assertSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw CurrencyMismatchException(currencyCode, other.currencyCode);
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  /// Exact decimal major-unit value for display or export only. Never feed
  /// this back into storage or further arithmetic — round-trip through
  /// [Money.parse] instead so precision stays exact.
  String toDecimalString() {
    final digits = Currency.minorUnitDigitsFor(currencyCode);
    if (digits == 0) return minorUnits.toString();
    final negative = minorUnits < 0;
    final abs = minorUnits.abs().toString().padLeft(digits + 1, '0');
    final whole = abs.substring(0, abs.length - digits);
    final fraction = abs.substring(abs.length - digits);
    return '${negative ? '-' : ''}$whole.$fraction';
  }

  /// Locale-aware display string, e.g. "1.234.567 ₫" or "$12.34".
  String format({String? locale}) {
    final digits = Currency.minorUnitDigitsFor(currencyCode);
    final major = double.parse(toDecimalString());
    return NumberFormat.currency(
      locale: locale,
      name: currencyCode,
      decimalDigits: digits,
    ).format(major);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  @override
  String toString() => '${toDecimalString()} $currencyCode';
}

class CurrencyMismatchException implements Exception {
  final String expected;
  final String actual;
  CurrencyMismatchException(this.expected, this.actual);

  @override
  String toString() =>
      'CurrencyMismatchException: expected $expected but got $actual. '
      'Cross-currency arithmetic requires an explicit FX conversion step, '
      'which this app does not perform implicitly.';
}
