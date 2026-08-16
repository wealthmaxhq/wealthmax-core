import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// An immutable percentage represented with exact decimal arithmetic.
///
/// Use [Percentage.fromPercent] when the input is expressed in percentage
/// points, such as `12.5` for 12.5%. Use [Percentage.fromFraction] when the
/// input is expressed as a fraction, such as `0.125` for 12.5%.
///
/// Values are not automatically clamped, so negative percentages and values
/// greater than 100% remain valid domain values.
@immutable
final class Percentage implements Comparable<Percentage> {
  Percentage._(this._percent);

  /// Creates a percentage from percentage points.
  ///
  /// For example, `Percentage.fromPercent('12.5')` represents 12.5%.
  factory Percentage.fromPercent(String value) {
    return Percentage._(Decimal.parse(value));
  }

  /// Creates a percentage from a fractional value.
  ///
  /// For example, `Percentage.fromFraction('0.125')` represents 12.5%.
  factory Percentage.fromFraction(String value) {
    return Percentage._(Decimal.parse(value) * _oneHundred);
  }

  static final Decimal _oneHundred = Decimal.fromInt(100);

  final Decimal _percent;

  /// This value expressed in percentage points.
  Decimal get percent => _percent;

  /// This value expressed as a fraction.
  Decimal get fraction => (_percent / _oneHundred).toDecimal();

  /// Whether this percentage is exactly zero.
  bool get isZero => _percent == Decimal.zero;

  /// Whether this percentage is greater than zero.
  bool get isPositive => _percent > Decimal.zero;

  /// Whether this percentage is less than zero.
  bool get isNegative => _percent < Decimal.zero;

  /// Adds two percentages in percentage-point terms.
  Percentage operator +(Percentage other) {
    return Percentage._(_percent + other._percent);
  }

  /// Subtracts [other] in percentage-point terms.
  Percentage operator -(Percentage other) {
    return Percentage._(_percent - other._percent);
  }

  /// Multiplies this percentage by an exact decimal [factor].
  Percentage operator *(Decimal factor) {
    return Percentage._(_percent * factor);
  }

  /// Multiplies this percentage by an exact decimal [factor].
  Percentage multiply(Decimal factor) => this * factor;

  @override
  int compareTo(Percentage other) => _percent.compareTo(other._percent);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Percentage && _percent == other._percent;
  }

  @override
  int get hashCode => _percent.hashCode;

  /// Returns the percentage-point value followed by `%`.
  @override
  String toString() => '$_percent%';
}
