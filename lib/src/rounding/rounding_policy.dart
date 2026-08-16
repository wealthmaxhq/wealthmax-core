import 'package:decimal/decimal.dart';

/// An explicit rounding rule for exact decimal financial calculations.
///
/// Each policy rounds [Decimal] values without converting them to binary
/// floating-point numbers.
enum RoundingPolicy {
  /// Rounds to the nearest value, with exact ties rounded away from zero.
  halfUp,

  /// Rounds to the nearest value, with exact ties rounded toward zero.
  halfDown,

  /// Rounds to the nearest value, with exact ties rounded to an even digit.
  halfEven,

  /// Rounds toward positive infinity.
  ceiling,

  /// Rounds toward negative infinity.
  floor,

  /// Rounds toward zero.
  towardZero,

  /// Rounds away from zero.
  awayFromZero;

  static final Decimal _half = Decimal.parse('0.5');

  /// Rounds [value] to [decimalPlaces] digits after the decimal point.
  ///
  /// Throws an [ArgumentError] when [decimalPlaces] is negative.
  Decimal round(Decimal value, {required int decimalPlaces}) {
    if (decimalPlaces < 0) {
      throw ArgumentError.value(
        decimalPlaces,
        'decimalPlaces',
        'Must not be negative.',
      );
    }

    return switch (this) {
      RoundingPolicy.halfUp => _roundToNearest(
        value,
        decimalPlaces: decimalPlaces,
        tieBreaker: _TieBreaker.awayFromZero,
      ),
      RoundingPolicy.halfDown => _roundToNearest(
        value,
        decimalPlaces: decimalPlaces,
        tieBreaker: _TieBreaker.towardZero,
      ),
      RoundingPolicy.halfEven => _roundToNearest(
        value,
        decimalPlaces: decimalPlaces,
        tieBreaker: _TieBreaker.toEven,
      ),
      RoundingPolicy.ceiling => value.ceil(scale: decimalPlaces),
      RoundingPolicy.floor => value.floor(scale: decimalPlaces),
      RoundingPolicy.towardZero => value.truncate(scale: decimalPlaces),
      RoundingPolicy.awayFromZero => switch (value.sign) {
        < 0 => value.floor(scale: decimalPlaces),
        > 0 => value.ceil(scale: decimalPlaces),
        _ => Decimal.zero,
      },
    };
  }

  static Decimal _roundToNearest(
    Decimal value, {
    required int decimalPlaces,
    required _TieBreaker tieBreaker,
  }) {
    final scaled = value.shift(decimalPlaces);
    final truncated = scaled.toBigInt();
    final discarded = (scaled - Decimal.fromBigInt(truncated)).abs();

    if (discarded < _half) {
      return _fromScaledInteger(truncated, decimalPlaces);
    }

    if (discarded > _half) {
      return _fromScaledInteger(
        truncated + BigInt.from(value.sign),
        decimalPlaces,
      );
    }

    final rounded = switch (tieBreaker) {
      _TieBreaker.awayFromZero => truncated + BigInt.from(value.sign),
      _TieBreaker.towardZero => truncated,
      _TieBreaker.toEven =>
        truncated.isEven ? truncated : truncated + BigInt.from(value.sign),
    };
    return _fromScaledInteger(rounded, decimalPlaces);
  }

  static Decimal _fromScaledInteger(BigInt value, int decimalPlaces) {
    return Decimal.fromBigInt(value).shift(-decimalPlaces);
  }
}

enum _TieBreaker { awayFromZero, towardZero, toEven }
