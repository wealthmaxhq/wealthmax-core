import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'cagr_input.dart';
import 'cagr_result.dart';

/// Calculates compound annual growth using the actual/365 convention.
///
/// Formula `INV-005`: `CAGR = (FV / PV)^(365 / days) - 1`.
/// Fractional exponentiation is evaluated using exact decimal integer powers
/// and bisection rather than binary floating-point arithmetic.
@immutable
final class CagrCalculator {
  const CagrCalculator({
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'INV-005';
  static const String formulaVersion = '1.0.0';
  static const int daysPerYear = 365;

  final int calculationScale;
  final int maximumIterations;

  CalculationResult<CagrResult> calculate(
    CagrInput input, {
    required DateTime calculatedAt,
  }) {
    final valueRatio = (input.finalValue.amount / input.initialValue.amount)
        .toDecimal(scaleOnInfinitePrecision: calculationScale);
    final totalReturnFraction = valueRatio - Decimal.one;
    final annualizedFraction = input.finalValue.isZero
        ? -Decimal.one
        : _annualize(valueRatio, input.holdingPeriodDays) - Decimal.one;
    final result = CagrResult(
      initialValue: input.initialValue,
      finalValue: input.finalValue,
      totalReturn: Percentage.fromFraction(totalReturnFraction.toString()),
      annualizedReturn: Percentage.fromFraction(annualizedFraction.toString()),
      holdingPeriodDays: input.holdingPeriodDays,
    );

    return CalculationResult<CagrResult>(
      value: result,
      warnings: <CalculationWarning>[
        if (input.holdingPeriodDays < daysPerYear)
          const CalculationWarning(
            code: 'INV-005-SHORT-PERIOD-ANNUALIZATION',
            message:
                'Annualizing a holding period shorter than one year can '
                'magnify short-term performance.',
            severity: WarningSeverity.caution,
          ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'initialValue': input.initialValue.amount.toString(),
          'finalValue': input.finalValue.amount.toString(),
          'currency': input.initialValue.currency.code,
          'holdingPeriodDays': input.holdingPeriodDays,
        },
        assumptions: const <String, Object?>{
          'dayCountConvention': 'actual/365',
          'cashFlowsDuringHoldingPeriod': false,
          'feesIncluded': 'onlyIfReflectedInValues',
          'taxesIncluded': 'onlyIfReflectedInValues',
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'absoluteGain': result.absoluteGain.amount.toString(),
          'totalReturnPercent': result.totalReturn.percent.toString(),
          'annualizedReturnPercent': result.annualizedReturn.percent.toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }

  Decimal _annualize(Decimal valueRatio, int holdingPeriodDays) {
    if (valueRatio == Decimal.one) return Decimal.one;

    var lower = valueRatio < Decimal.one ? Decimal.zero : Decimal.one;
    var upper = valueRatio < Decimal.one ? Decimal.one : valueRatio;
    final tolerance = Decimal.one.shift(-calculationScale);
    Decimal dailyGrowthFactor = Decimal.one;

    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      final midpoint = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final powered = _powAtScale(midpoint, holdingPeriodDays);
      final difference = powered - valueRatio;
      if (difference.abs() <= tolerance || upper - lower <= tolerance) {
        dailyGrowthFactor = midpoint;
        break;
      }
      if (difference < Decimal.zero) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
      dailyGrowthFactor = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
    }

    return _powAtScale(dailyGrowthFactor, daysPerYear);
  }

  Decimal _powAtScale(Decimal base, int exponent) {
    var result = Decimal.one;
    var factor = base;
    var remainingExponent = exponent;

    while (remainingExponent > 0) {
      if (remainingExponent.isOdd) {
        result = _roundIntermediate(result * factor);
      }
      remainingExponent ~/= 2;
      if (remainingExponent > 0) {
        factor = _roundIntermediate(factor * factor);
      }
    }
    return result;
  }

  Decimal _roundIntermediate(Decimal value) {
    return RoundingPolicy.halfEven.round(
      value,
      decimalPlaces: calculationScale,
    );
  }
}
