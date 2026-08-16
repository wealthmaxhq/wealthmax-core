import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'inflation_adjustment_input.dart';

/// Immutable purchasing-power result for a nominal future value.
@immutable
final class InflationAdjustmentResult {
  factory InflationAdjustmentResult({
    required Money nominalFutureValue,
    required Money realValue,
    required Percentage annualInflationRate,
    required Percentage cumulativeInflation,
    required int horizonMonths,
  }) {
    if (nominalFutureValue.isNegative || realValue.isNegative) {
      throw ArgumentError('Nominal and real values must not be negative.');
    }
    if (realValue.currency != nominalFutureValue.currency) {
      throw ArgumentError.value(
        realValue,
        'realValue',
        'Currency must match nominal future value currency '
            '${nominalFutureValue.currency.code}.',
      );
    }
    if (annualInflationRate.percent <= Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        annualInflationRate,
        'annualInflationRate',
        'Annual inflation rate must be greater than -100%.',
      );
    }
    if (cumulativeInflation.percent <= Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        cumulativeInflation,
        'cumulativeInflation',
        'Cumulative inflation must be greater than -100%.',
      );
    }
    if (horizonMonths < 0 ||
        horizonMonths > InflationAdjustmentCalculatorLimits.maximumMonths) {
      throw ArgumentError.value(
        horizonMonths,
        'horizonMonths',
        'Horizon must be between zero and '
            '${InflationAdjustmentCalculatorLimits.maximumMonths} months.',
      );
    }

    return InflationAdjustmentResult._(
      nominalFutureValue: nominalFutureValue,
      realValue: realValue,
      annualInflationRate: annualInflationRate,
      cumulativeInflation: cumulativeInflation,
      horizonMonths: horizonMonths,
    );
  }

  const InflationAdjustmentResult._({
    required this.nominalFutureValue,
    required this.realValue,
    required this.annualInflationRate,
    required this.cumulativeInflation,
    required this.horizonMonths,
  });

  final Money nominalFutureValue;
  final Money realValue;
  final Percentage annualInflationRate;
  final Percentage cumulativeInflation;
  final int horizonMonths;

  Money get purchasingPowerDifference => nominalFutureValue - realValue;
  bool get hasErosion => purchasingPowerDifference.isPositive;
  bool get hasDeflationGain => purchasingPowerDifference.isNegative;

  InflationAdjustmentResult copyWith({
    Money? nominalFutureValue,
    Money? realValue,
    Percentage? annualInflationRate,
    Percentage? cumulativeInflation,
    int? horizonMonths,
  }) {
    return InflationAdjustmentResult(
      nominalFutureValue: nominalFutureValue ?? this.nominalFutureValue,
      realValue: realValue ?? this.realValue,
      annualInflationRate: annualInflationRate ?? this.annualInflationRate,
      cumulativeInflation: cumulativeInflation ?? this.cumulativeInflation,
      horizonMonths: horizonMonths ?? this.horizonMonths,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InflationAdjustmentResult &&
            nominalFutureValue == other.nominalFutureValue &&
            realValue == other.realValue &&
            annualInflationRate == other.annualInflationRate &&
            cumulativeInflation == other.cumulativeInflation &&
            horizonMonths == other.horizonMonths;
  }

  @override
  int get hashCode => Object.hash(
    nominalFutureValue,
    realValue,
    annualInflationRate,
    cumulativeInflation,
    horizonMonths,
  );

  @override
  String toString() {
    return 'InflationAdjustmentResult('
        'nominalFutureValue: $nominalFutureValue, '
        'realValue: $realValue, '
        'purchasingPowerDifference: $purchasingPowerDifference, '
        'annualInflationRate: $annualInflationRate, '
        'cumulativeInflation: $cumulativeInflation, '
        'horizonMonths: $horizonMonths'
        ')';
  }
}
