/// Money in minor units (halalas for SAR) to avoid float drift.
///
/// UI may still show major units via [toMajor]; storage prefers [minor].
class Money {
  /// Amount in minor units (e.g. 1 SAR = 100).
  final int minor;
  final String currency;

  const Money({required this.minor, this.currency = 'SAR'});

  factory Money.fromMajor(double major, {String currency = 'SAR'}) {
    return Money(
      minor: (major * 100).round(),
      currency: currency,
    );
  }

  factory Money.zero({String currency = 'SAR'}) =>
      Money(minor: 0, currency: currency);

  double get toMajor => minor / 100.0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minor: minor + other.minor, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minor: minor - other.minor, currency: currency);
  }

  Money operator -() => Money(minor: -minor, currency: currency);

  bool get isNegative => minor < 0;
  bool get isZero => minor == 0;
  bool get isPositive => minor > 0;

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Currency mismatch: $currency vs ${other.currency}',
      );
    }
  }

  @override
  String toString() =>
      '${toMajor.toStringAsFixed(2)} $currency';

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);
}
