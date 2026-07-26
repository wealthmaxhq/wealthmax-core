import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable inputs for converting a future nominal value to today's money.
@immutable
final class InflationAdjustmentInput {
  factory InflationAdjustmentInput({
    required Money nominalFutureValue,
    required Percentage annualInflationRate,
    required int horizonMonths,
  }) {
    if (nominalFutureValue.isNegative) {
      throw ArgumentError.value(
        nominalFutureValue,
        'nominalFutureValue',
        'Nominal future value must not be negative.',
      );
    }
    if (annualInflationRate.percent <= Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        annualInflationRate,
        'annualInflationRate',
        'Annual inflation rate must be greater than -100%.',
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

    return InflationAdjustmentInput._(
      nominalFutureValue: nominalFutureValue,
      annualInflationRate: annualInflationRate,
      horizonMonths: horizonMonths,
    );
  }

  const InflationAdjustmentInput._({
    required this.nominalFutureValue,
    required this.annualInflationRate,
    required this.horizonMonths,
  });

  final Money nominalFutureValue;
  final Percentage annualInflationRate;
  final int horizonMonths;

  InflationAdjustmentInput copyWith({
    Money? nominalFutureValue,
    Percentage? annualInflationRate,
    int? horizonMonths,
  }) {
    return InflationAdjustmentInput(
      nominalFutureValue: nominalFutureValue ?? this.nominalFutureValue,
      annualInflationRate: annualInflationRate ?? this.annualInflationRate,
      horizonMonths: horizonMonths ?? this.horizonMonths,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InflationAdjustmentInput &&
            nominalFutureValue == other.nominalFutureValue &&
            annualInflationRate == other.annualInflationRate &&
            horizonMonths == other.horizonMonths;
  }

  @override
  int get hashCode =>
      Object.hash(nominalFutureValue, annualInflationRate, horizonMonths);

  @override
  String toString() {
    return 'InflationAdjustmentInput('
        'nominalFutureValue: $nominalFutureValue, '
        'annualInflationRate: $annualInflationRate, '
        'horizonMonths: $horizonMonths'
        ')';
  }
}

/// Public limits used by the purchasing-power projection.
abstract final class InflationAdjustmentCalculatorLimits {
  static const int maximumMonths = 1200;
}
