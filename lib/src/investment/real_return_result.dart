import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../percentage/percentage.dart';

/// Immutable result of a Fisher real-return calculation.
@immutable
final class RealReturnResult {
  factory RealReturnResult({
    required Percentage nominalReturn,
    required Percentage inflationRate,
    required Percentage realReturn,
  }) {
    if (nominalReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        nominalReturn,
        'nominalReturn',
        'Nominal return must not be less than -100%.',
      );
    }
    if (inflationRate.percent <= Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        inflationRate,
        'inflationRate',
        'Inflation rate must be greater than -100%.',
      );
    }
    if (realReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        realReturn,
        'realReturn',
        'Real return must not be less than -100%.',
      );
    }

    return RealReturnResult._(
      nominalReturn: nominalReturn,
      inflationRate: inflationRate,
      realReturn: realReturn,
    );
  }

  const RealReturnResult._({
    required this.nominalReturn,
    required this.inflationRate,
    required this.realReturn,
  });

  final Percentage nominalReturn;
  final Percentage inflationRate;
  final Percentage realReturn;

  bool get preservesPurchasingPower => !realReturn.isNegative;

  RealReturnResult copyWith({
    Percentage? nominalReturn,
    Percentage? inflationRate,
    Percentage? realReturn,
  }) {
    return RealReturnResult(
      nominalReturn: nominalReturn ?? this.nominalReturn,
      inflationRate: inflationRate ?? this.inflationRate,
      realReturn: realReturn ?? this.realReturn,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RealReturnResult &&
            nominalReturn == other.nominalReturn &&
            inflationRate == other.inflationRate &&
            realReturn == other.realReturn;
  }

  @override
  int get hashCode => Object.hash(nominalReturn, inflationRate, realReturn);

  @override
  String toString() {
    return 'RealReturnResult('
        'nominalReturn: $nominalReturn, '
        'inflationRate: $inflationRate, '
        'realReturn: $realReturn'
        ')';
  }
}
