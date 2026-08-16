import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'lump_sum_input.dart';
import 'lump_sum_result.dart';

/// Projects the future value of one initial investment.
///
/// Formula `INV-001`: `FV = P * (1 + r)^n`, where `r` is an effective annual
/// return assumption and `n` is a whole number of years.
@immutable
final class LumpSumCalculator {
  const LumpSumCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
  });

  static const String formulaId = 'INV-001';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;

  CalculationResult<LumpSumResult> calculate(
    LumpSumInput input, {
    required DateTime calculatedAt,
  }) {
    if (calculationScale <= 0) {
      throw ArgumentError.value(
        calculationScale,
        'calculationScale',
        'Must be greater than zero.',
      );
    }

    final currency = input.initialInvestment.currency;
    final growthFactor = Decimal.one + input.expectedAnnualReturn.fraction;
    final compounded = _powAtScale(growthFactor, input.tenureYears);
    final rawFutureValue = input.initialInvestment.amount * compounded;
    final futureValue = Money(
      amount: roundingPolicy.round(
        rawFutureValue,
        decimalPlaces: currency.decimalPlaces,
      ),
      currency: currency,
    );
    final totalGain = futureValue - input.initialInvestment;
    final cumulativeReturnFraction =
        (totalGain.amount / input.initialInvestment.amount).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        );
    final result = LumpSumResult(
      initialInvestment: input.initialInvestment,
      futureValue: futureValue,
      cumulativeReturn: Percentage.fromFraction(
        cumulativeReturnFraction.toString(),
      ),
      tenureYears: input.tenureYears,
    );

    return CalculationResult<LumpSumResult>(
      value: result,
      warnings: const <CalculationWarning>[
        CalculationWarning(
          code: 'INV-001-PROJECTION-NOT-GUARANTEED',
          message:
              'Future value is a projection based on the supplied return '
              'assumption and is not guaranteed.',
          severity: WarningSeverity.info,
        ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'initialInvestment': input.initialInvestment.amount.toString(),
          'currency': currency.code,
          'expectedAnnualReturnPercent': input.expectedAnnualReturn.percent
              .toString(),
          'tenureYears': input.tenureYears,
        },
        assumptions: <String, Object?>{
          'returnConvention': 'effectiveAnnualReturn',
          'compoundingFrequency': 'annual',
          'cashFlowTiming': 'initialInvestmentAtStart',
          'additionalContributions': false,
          'feesIncluded': false,
          'taxesIncluded': false,
          'inflationIncluded': false,
          'roundingTiming': 'finalValueOnly',
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'futureValue': result.futureValue.amount.toString(),
          'totalGain': result.totalGain.amount.toString(),
          'cumulativeReturnPercent': result.cumulativeReturn.percent.toString(),
          'calculationScale': calculationScale,
          'currencyDecimalPlaces': currency.decimalPlaces,
        },
      ),
    );
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
