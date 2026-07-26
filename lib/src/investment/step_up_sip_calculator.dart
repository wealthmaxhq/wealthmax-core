import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'sip_input.dart';
import 'step_up_sip_input.dart';
import 'step_up_sip_result.dart';

/// Projects a monthly SIP whose contribution changes after every 12 months.
///
/// Formula `INV-003` converts an effective annual return to its equivalent
/// monthly rate, then applies the annual step-up schedule and explicit monthly
/// contribution timing.
@immutable
final class StepUpSipCalculator {
  const StepUpSipCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'INV-003';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<StepUpSipResult> calculate(
    StepUpSipInput input, {
    required DateTime calculatedAt,
  }) {
    final currency = input.initialMonthlyContribution.currency;
    final monthlyRate = _monthlyRateFromEffectiveAnnual(
      input.expectedAnnualReturn.fraction,
    );
    final monthlyGrowthFactor = Decimal.one + monthlyRate;
    final annualContributionFactor = Decimal.one + input.annualStepUp.fraction;
    var projectedBalance = Decimal.zero;
    var totalInvestedAmount = Decimal.zero;
    var currentContribution = input.initialMonthlyContribution.amount;

    for (var month = 0; month < input.tenureMonths; month++) {
      if (month % 12 == 0) {
        final completedYears = month ~/ 12;
        currentContribution = completedYears == 0
            ? input.initialMonthlyContribution.amount
            : roundingPolicy.round(
                input.initialMonthlyContribution.amount *
                    _powAtScale(annualContributionFactor, completedYears),
                decimalPlaces: currency.decimalPlaces,
              );
      }

      totalInvestedAmount += currentContribution;
      if (input.contributionTiming == ContributionTiming.beginningOfPeriod) {
        projectedBalance += currentContribution;
      }
      projectedBalance = _roundIntermediate(
        projectedBalance * monthlyGrowthFactor,
      );
      if (input.contributionTiming == ContributionTiming.endOfPeriod) {
        projectedBalance += currentContribution;
      }
    }

    final totalInvested = Money(
      amount: totalInvestedAmount,
      currency: currency,
    );
    final futureValue = Money(
      amount: roundingPolicy.round(
        projectedBalance,
        decimalPlaces: currency.decimalPlaces,
      ),
      currency: currency,
    );
    final totalGain = futureValue - totalInvested;
    final cumulativeReturnFraction = (totalGain.amount / totalInvested.amount)
        .toDecimal(scaleOnInfinitePrecision: calculationScale);
    final result = StepUpSipResult(
      initialMonthlyContribution: input.initialMonthlyContribution,
      finalMonthlyContribution: Money(
        amount: currentContribution,
        currency: currency,
      ),
      totalInvested: totalInvested,
      futureValue: futureValue,
      monthlyEquivalentReturn: Percentage.fromFraction(monthlyRate.toString()),
      cumulativeReturn: Percentage.fromFraction(
        cumulativeReturnFraction.toString(),
      ),
      annualStepUp: input.annualStepUp,
      tenureMonths: input.tenureMonths,
      contributionTiming: input.contributionTiming,
    );

    return CalculationResult<StepUpSipResult>(
      value: result,
      warnings: const <CalculationWarning>[
        CalculationWarning(
          code: 'INV-003-PROJECTION-NOT-GUARANTEED',
          message:
              'Future value is a projection based on supplied return and '
              'contribution-growth assumptions and is not guaranteed.',
          severity: WarningSeverity.info,
        ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'initialMonthlyContribution': input.initialMonthlyContribution.amount
              .toString(),
          'currency': currency.code,
          'expectedAnnualReturnPercent': input.expectedAnnualReturn.percent
              .toString(),
          'annualStepUpPercent': input.annualStepUp.percent.toString(),
          'tenureMonths': input.tenureMonths,
          'contributionTiming': input.contributionTiming.name,
        },
        assumptions: <String, Object?>{
          'returnConvention': 'effectiveAnnualReturn',
          'monthlyRateConversion': 'twelfthRootOfAnnualGrowthFactor',
          'contributionFrequency': 'monthly',
          'stepUpFrequency': 'afterEachCompletedTwelveMonthBlock',
          'stepUpBasis': 'initialContributionTimesAnnualFactorPower',
          'stepUpContributionRounding': 'atEachAnnualRevision',
          'feesIncluded': false,
          'taxesIncluded': false,
          'inflationIncluded': false,
          'futureValueRounding': 'finalValueOnly',
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'monthlyEquivalentReturnPercent': result
              .monthlyEquivalentReturn
              .percent
              .toString(),
          'finalMonthlyContribution': result.finalMonthlyContribution.amount
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
