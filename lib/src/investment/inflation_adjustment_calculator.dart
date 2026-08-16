import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'inflation_adjustment_input.dart';
import 'inflation_adjustment_result.dart';

/// Converts a future nominal amount to present purchasing power.
///
/// Formula `INV-008`: `realValue = nominalValue / (1 + inflation)^(m/12)`.
@immutable
final class InflationAdjustmentCalculator {
  const InflationAdjustmentCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  });

  static const String formulaId = 'INV-008';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<InflationAdjustmentResult> calculate(
    InflationAdjustmentInput input, {
    required DateTime calculatedAt,
  }) {
    _validateConfiguration();
    final currency = input.nominalFutureValue.currency;
    final annualGrowthFactor = Decimal.one + input.annualInflationRate.fraction;
    final monthlyGrowthFactor = input.horizonMonths == 0
        ? Decimal.one
        : _monthlyFactor(annualGrowthFactor);
    final cumulativeGrowthFactor = _powExact(
      monthlyGrowthFactor,
      input.horizonMonths,
    );
    final rawRealValue = input.nominalFutureValue.isZero
        ? Decimal.zero
        : (input.nominalFutureValue.amount / cumulativeGrowthFactor).toDecimal(
            scaleOnInfinitePrecision: calculationScale,
          );
    final realValue = Money(
      amount: roundingPolicy.round(
        rawRealValue,
        decimalPlaces: currency.decimalPlaces,
      ),
      currency: currency,
    );
    final cumulativeInflation = Percentage.fromFraction(
      (cumulativeGrowthFactor - Decimal.one).toString(),
    );
    final result = InflationAdjustmentResult(
      nominalFutureValue: input.nominalFutureValue,
      realValue: realValue,
      annualInflationRate: input.annualInflationRate,
      cumulativeInflation: cumulativeInflation,
      horizonMonths: input.horizonMonths,
    );

    return CalculationResult<InflationAdjustmentResult>(
      value: result,
      warnings: <CalculationWarning>[
        const CalculationWarning(
          code: 'INV-008-INFLATION-ASSUMPTION',
          message:
              'Purchasing power is projected from the supplied inflation '
              'assumption and actual inflation may differ.',
          severity: WarningSeverity.info,
        ),
        if (input.horizonMonths > 360)
          const CalculationWarning(
            code: 'INV-008-LONG-HORIZON',
            message:
                'Inflation projections beyond 30 years are highly sensitive '
                'to small changes in the assumed rate.',
            severity: WarningSeverity.caution,
          ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'nominalFutureValue': input.nominalFutureValue.amount.toString(),
          'currency': currency.code,
          'annualInflationRatePercent': input.annualInflationRate.percent
              .toString(),
          'horizonMonths': input.horizonMonths,
        },
        assumptions: <String, Object?>{
          'inflationConvention': 'effectiveAnnualRate',
          'monthlyFactorConversion': 'twelfthRootOfAnnualGrowthFactor',
          'inflationRateConstant': true,
          'roundingTiming': 'finalValueOnly',
          'roundingPolicy': roundingPolicy.name,
          'taxesIncluded': false,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'monthlyInflationFactor': monthlyGrowthFactor.toString(),
          'cumulativeInflationFactor': cumulativeGrowthFactor.toString(),
          'cumulativeInflationPercent': result.cumulativeInflation.percent
              .toString(),
          'realValue': result.realValue.amount.toString(),
          'purchasingPowerDifference': result.purchasingPowerDifference.amount
              .toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
          'currencyDecimalPlaces': currency.decimalPlaces,
        },
      ),
    );
  }

  void _validateConfiguration() {
    if (calculationScale <= 0) {
      throw ArgumentError.value(
        calculationScale,
        'calculationScale',
        'Must be greater than zero.',
      );
    }
    if (maximumIterations <= 0) {
      throw ArgumentError.value(
        maximumIterations,
        'maximumIterations',
        'Must be greater than zero.',
      );
    }
  }

  Decimal _monthlyFactor(Decimal annualGrowthFactor) {
    if (annualGrowthFactor == Decimal.one) return Decimal.one;

    var lower = annualGrowthFactor < Decimal.one ? Decimal.zero : Decimal.one;
    var upper = annualGrowthFactor < Decimal.one
        ? Decimal.one
        : annualGrowthFactor;
    final tolerance = Decimal.one.shift(-calculationScale);

    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      final midpoint = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final difference = _powExact(midpoint, 12) - annualGrowthFactor;
      if (difference.abs() <= tolerance || upper - lower <= tolerance) {
        return midpoint;
      }
      if (difference < Decimal.zero) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
    }

    return ((lower + upper) / Decimal.fromInt(2)).toDecimal(
      scaleOnInfinitePrecision: calculationScale,
    );
  }

  Decimal _powExact(Decimal base, int exponent) {
    var result = Decimal.one;
    var factor = base;
    var remainingExponent = exponent;

    while (remainingExponent > 0) {
      if (remainingExponent.isOdd) result *= factor;
      remainingExponent ~/= 2;
      if (remainingExponent > 0) factor *= factor;
    }
    return result;
  }
}
