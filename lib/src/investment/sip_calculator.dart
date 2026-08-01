import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'sip_input.dart';
import 'sip_result.dart';

/// Projects the future value of equal monthly SIP contributions.
///
/// Formula `INV-002` derives the monthly rate `m` from the effective annual
/// assumption `a` such that `(1 + m)^12 = 1 + a`, then applies each
/// contribution according to its explicit timing.
@immutable
final class SipCalculator {
  const SipCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  });

  static const String formulaId = 'INV-002';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<SipResult> calculate(
    SipInput input, {
    required DateTime calculatedAt,
  }) {
    _validateConfiguration();
    final currency = input.monthlyContribution.currency;
    final monthlyRate = _monthlyRateFromEffectiveAnnual(
      input.expectedAnnualReturn.fraction,
    );
    final monthlyGrowthFactor = Decimal.one + monthlyRate;
    var projectedBalance = Decimal.zero;

    for (var month = 0; month < input.tenureMonths; month++) {
      if (input.contributionTiming == ContributionTiming.beginningOfPeriod) {
        projectedBalance += input.monthlyContribution.amount;
      }
      projectedBalance = _roundIntermediate(
        projectedBalance * monthlyGrowthFactor,
      );
      if (input.contributionTiming == ContributionTiming.endOfPeriod) {
        projectedBalance += input.monthlyContribution.amount;
      }
    }

    final futureValue = Money(
      amount: roundingPolicy.round(
        projectedBalance,
        decimalPlaces: currency.decimalPlaces,
      ),
      currency: currency,
    );
    final totalInvested = input.monthlyContribution.multiply(
      Decimal.fromInt(input.tenureMonths),
    );
    final totalGain = futureValue - totalInvested;
    final cumulativeReturnFraction = (totalGain.amount / totalInvested.amount)
        .toDecimal(scaleOnInfinitePrecision: calculationScale);
    final result = SipResult(
      monthlyContribution: input.monthlyContribution,
      totalInvested: totalInvested,
      futureValue: futureValue,
      monthlyEquivalentReturn: Percentage.fromFraction(monthlyRate.toString()),
      cumulativeReturn: Percentage.fromFraction(
        cumulativeReturnFraction.toString(),
      ),
      tenureMonths: input.tenureMonths,
      contributionTiming: input.contributionTiming,
    );

    return CalculationResult<SipResult>(
      value: result,
      warnings: const <CalculationWarning>[
        CalculationWarning(
          code: 'INV-002-PROJECTION-NOT-GUARANTEED',
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
          'monthlyContribution': input.monthlyContribution.amount.toString(),
          'currency': currency.code,
          'expectedAnnualReturnPercent': input.expectedAnnualReturn.percent
              .toString(),
          'tenureMonths': input.tenureMonths,
          'contributionTiming': input.contributionTiming.name,
        },
        assumptions: <String, Object?>{
          'returnConvention': 'effectiveAnnualReturn',
          'monthlyRateConversion': 'twelfthRootOfAnnualGrowthFactor',
          'contributionFrequency': 'monthly',
          'contributionAmount': 'constant',
          'feesIncluded': false,
          'taxesIncluded': false,
          'inflationIncluded': false,
          'roundingTiming': 'finalValueOnly',
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'monthlyEquivalentReturnPercent': result
              .monthlyEquivalentReturn
              .percent
              .toString(),
          'totalInvested': result.totalInvested.amount.toString(),
          'futureValue': result.futureValue.amount.toString(),
          'totalGain': result.totalGain.amount.toString(),
          'cumulativeReturnPercent': result.cumulativeReturn.percent.toString(),
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

  Decimal _monthlyRateFromEffectiveAnnual(Decimal annualRate) {
    final annualGrowthFactor = Decimal.one + annualRate;
    if (annualGrowthFactor == Decimal.zero) return -Decimal.one;
    if (annualGrowthFactor == Decimal.one) return Decimal.zero;

    var lower = annualGrowthFactor < Decimal.one ? Decimal.zero : Decimal.one;
    var upper = annualGrowthFactor < Decimal.one
        ? Decimal.one
        : annualGrowthFactor;
    final tolerance = Decimal.one.shift(-calculationScale);

    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      final midpoint = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final powered = _powAtScale(midpoint, 12);
      final difference = powered - annualGrowthFactor;
      if (difference.abs() <= tolerance || upper - lower <= tolerance) {
        return midpoint - Decimal.one;
      }
      if (difference < Decimal.zero) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
    }

    return ((lower + upper) / Decimal.fromInt(2)).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        ) -
        Decimal.one;
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
