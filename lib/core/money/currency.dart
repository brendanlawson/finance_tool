/// ISO 4217 currency metadata needed for correct monetary math.
///
/// The critical fact this exists to encode: currencies do not all have
/// 2 decimal places. VND and JPY have 0 minor-unit digits; BHD/KWD/OMR have
/// 3. [Money] uses [minorUnitDigits] to convert between the integer minor
/// units it stores and a human-readable major-unit amount, so this table
/// must stay authoritative rather than assuming `100` everywhere.
abstract final class Currency {
  /// Minor-unit exponent (10^n minor units per 1 major unit) for known
  /// ISO 4217 codes. Codes not listed here fall back to 2 via
  /// [minorUnitDigitsFor], which covers the overwhelming majority of
  /// real-world currencies.
  static const Map<String, int> _zeroDecimal = {
    'VND': 0,
    'JPY': 0,
    'KRW': 0,
    'CLP': 0,
    'ISK': 0,
    'HUF': 0,
    'TWD': 0,
    'UGX': 0,
    'VUV': 0,
    'XAF': 0,
    'XOF': 0,
    'XPF': 0,
  };

  static const Map<String, int> _threeDecimal = {
    'BHD': 3,
    'IQD': 3,
    'JOD': 3,
    'KWD': 3,
    'LYD': 3,
    'OMR': 3,
    'TND': 3,
  };

  /// Number of decimal digits (minor-unit exponent) for [isoCode].
  /// Defaults to 2 for any code not explicitly listed.
  static int minorUnitDigitsFor(String isoCode) {
    final code = isoCode.toUpperCase();
    return _zeroDecimal[code] ?? _threeDecimal[code] ?? 2;
  }

  static bool isKnown(String isoCode) {
    final code = isoCode.toUpperCase();
    return _zeroDecimal.containsKey(code) ||
        _threeDecimal.containsKey(code) ||
        _commonTwoDecimal.contains(code);
  }

  static const Set<String> _commonTwoDecimal = {
    'USD', 'EUR', 'GBP', 'AUD', 'CAD', 'CHF', 'CNY', 'SGD', 'THB', 'MYR',
    'PHP', 'IDR', 'INR', 'HKD', 'NZD', 'SEK', 'NOK', 'DKK', 'PLN', 'CZK', //
  };
}
