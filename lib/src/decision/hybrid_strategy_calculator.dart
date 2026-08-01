import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../loan/prepayment_calculator.dart';
import '../loan/scheduled_prepayment.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'calculator_configuration.dart';
import 'hybrid_strategy_input.dart';
import 'hybrid_strategy_result.dart';

/// Evaluates deterministic splits of cash between prepayment and investment.
///
/// Formula `OPT-005` ranks each split by nominal interest saved plus nominal
/// investment gain at the baseline loan payoff date.
@immutable
final class HybridStrategyCalculator {
  const HybridStrategyCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  });

  static const String formulaId = 'OPT-005';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<HybridStrategyResult> calculate(
    HybridStrategyInput input, {
    required DateTime calculatedAt,
  }) {
    validateDecisionCalculatorConfiguration(
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    );
    final currency = input.loan.principal.currency;
    final prepaymentCalculator = PrepaymentCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
    );
    final baselinePrepayment = prepaymentCalculator
        .calculate(
          input.loan,
          prepaymentPlan: PrepaymentPlan.empty(),
          calculatedAt: calculatedAt,
        )
        .value;
    if (input.decisionInstallment > baselinePrepayment.baseline.paymentCount) {
      throw ArgumentError.value(
        input.decisionInstallment,
        'decisionInstallment',
        'Decision installment occurs after the baseline loan closes.',
      );
    }

    final horizonMonths =
        baselinePrepayment.baseline.paymentCount - input.decisionInstallment;
    final grossAnnualFactor =
        Decimal.one + input.grossAnnualInvestmentReturn.fraction;
    final feeRetentionFactor = Decimal.one - input.annualExpenseRatio.fraction;
    final netAnnualFactor = grossAnnualFactor * feeRetentionFactor;
    final netAnnualReturn = Percentage.fromFraction(
      (netAnnualFactor - Decimal.one).toString(),
    );
    final monthlyFactor = horizonMonths == 0
        ? Decimal.one
        : _monthlyFactor(netAnnualFactor);
    final cumulativeFactor = _powExact(monthlyFactor, horizonMonths);

    final scenarios = <HybridStrategyScenario>[];
    for (final allocationPercent in _allocationPercentages(
      input.allocationStepPercent,
    )) {
      final requestedAmount = switch (allocationPercent) {
        0 => Decimal.zero,
        100 => input.extraCash.amount,
        _ => roundingPolicy.round(
          (input.extraCash.amount *
                  Decimal.fromInt(allocationPercent) /
                  Decimal.fromInt(100))
              .toDecimal(scaleOnInfinitePrecision: calculationScale),
          decimalPlaces: currency.decimalPlaces,
        ),
      };
      final requestedPrepayment = Money(
        amount: requestedAmount,
        currency: currency,
      );
      final loanPrepayment = requestedPrepayment.isZero
          ? baselinePrepayment
          : prepaymentCalculator
                .calculate(
                  input.loan,
                  prepaymentPlan: PrepaymentPlan(<ScheduledPrepayment>[
                    ScheduledPrepayment(
                      installmentNumber: input.decisionInstallment,
                      amount: requestedPrepayment,
                    ),
                  ]),
                  calculatedAt: calculatedAt,
                )
                .value;
      final investedAmount = input.extraCash - loanPrepayment.appliedPrepayment;
      final investmentFutureValue = Money(
        amount: roundingPolicy.round(
          investedAmount.amount * cumulativeFactor,
          decimalPlaces: currency.decimalPlaces,
        ),
        currency: currency,
      );

      scenarios.add(
        HybridStrategyScenario(
          requestedPrepaymentAllocation: Percentage.fromPercent(
            allocationPercent.toString(),
          ),
          availableCash: input.extraCash,
          requestedPrepayment: requestedPrepayment,
          loanPrepayment: loanPrepayment,
          investedAmount: investedAmount,
          investmentFutureValue: investmentFutureValue,
          investmentHorizonMonths: horizonMonths,
        ),
      );
    }

    final result = HybridStrategyResult(
      scenarios: scenarios,
      netAnnualInvestmentReturn: netAnnualReturn,
    );
    final partialCount = scenarios
        .where((scenario) => scenario.redirectedToInvestment.isPositive)
        .length;

    return CalculationResult<HybridStrategyResult>(
      value: result,
      warnings: <CalculationWarning>[
        const CalculationWarning(
          code: 'OPT-005-PROJECTION-NOT-GUARANTEED',
          message:
              'Investment returns are assumptions and are not guaranteed; '
              'the highest ranked scenario is not financial advice.',
          severity: WarningSeverity.info,
        ),
        const CalculationWarning(
          code: 'OPT-005-NOMINAL-TIMING-NOT-NORMALIZED',
          message:
              'Scenarios are ranked by nominal interest saved plus investment '
              'gain without discounting the timing of saved loan cash flows.',
          severity: WarningSeverity.caution,
        ),
        const CalculationWarning(
          code: 'OPT-005-TAX-INFLATION-RISK-EXCLUDED',
          message:
              'Taxes, inflation, liquidity needs, and investment risk are '
              'excluded and can change the preferred allocation.',
          severity: WarningSeverity.caution,
        ),
        if (partialCount > 0)
          CalculationWarning(
            code: 'OPT-005-PREPAYMENT-CAPPED',
            message:
                '$partialCount scenario(s) requested more prepayment than '
                'the loan could accept; excess cash was invested.',
            severity: WarningSeverity.info,
          ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'loanPrincipal': input.loan.principal.amount.toString(),
          'currency': currency.code,
          'loanAnnualInterestRatePercent': input.loan.annualInterestRate.percent
              .toString(),
          'loanTenureMonths': input.loan.tenureMonths,
          'extraCash': input.extraCash.amount.toString(),
          'decisionInstallment': input.decisionInstallment,
          'grossAnnualInvestmentReturnPercent': input
              .grossAnnualInvestmentReturn
              .percent
              .toString(),
          'annualExpenseRatioPercent': input.annualExpenseRatio.percent
              .toString(),
          'allocationStepPercent': input.allocationStepPercent,
        },
        assumptions: <String, Object?>{
          'prepaymentTiming': 'afterSelectedInstallment',
          'prepaymentEffect': 'reduceTenure',
          'comparisonHorizon': 'baselineLoanPayoff',
          'investmentTiming': 'afterSelectedInstallment',
          'investmentRateConvention': 'effectiveAnnualReturn',
          'feeConvention': 'endOfYearAssetBasedFee',
          'rankingObjective': 'interestSavedPlusInvestmentGain',
          'tieBreak': 'higherInvestedAmount',
          'unappliedPrepaymentTreatment': 'redirectToInvestment',
          'cashConservationRequired': true,
          'taxesIncluded': false,
          'inflationIncluded': false,
          'riskAdjusted': false,
          'cashFlowTimingNormalized': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'loanPrepaymentFormulaId': PrepaymentCalculator.formulaId,
          'scenarioCount': scenarios.length,
          'investmentHorizonMonths': horizonMonths,
          'netAnnualInvestmentReturnPercent': netAnnualReturn.percent
              .toString(),
          'monthlyNetGrowthFactor': monthlyFactor.toString(),
          'cumulativeInvestmentFactor': cumulativeFactor.toString(),
          'bestScenarioIndex': result.bestScenarioIndex,
          'bestPrepaymentAllocationPercent': result
              .bestScenario
              .requestedPrepaymentAllocation
              .percent
              .toString(),
          'bestAppliedPrepayment': result.bestScenario.appliedPrepayment.amount
              .toString(),
          'bestInvestedAmount': result.bestScenario.investedAmount.amount
              .toString(),
          'bestTotalNominalBenefit': result
              .bestScenario
              .totalNominalBenefit
              .amount
              .toString(),
          'partialPrepaymentScenarioCount': partialCount,
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
          'scenarios': scenarios
              .map(
                (scenario) => <String, Object?>{
                  'requestedPrepaymentAllocationPercent': scenario
                      .requestedPrepaymentAllocation
                      .percent
                      .toString(),
                  'requestedPrepayment': scenario.requestedPrepayment.amount
                      .toString(),
                  'appliedPrepayment': scenario.appliedPrepayment.amount
                      .toString(),
                  'redirectedToInvestment': scenario
                      .redirectedToInvestment
                      .amount
                      .toString(),
                  'investedAmount': scenario.investedAmount.amount.toString(),
                  'interestSaved': scenario.interestSaved.amount.toString(),
                  'investmentGain': scenario.investmentGain.amount.toString(),
                  'totalNominalBenefit': scenario.totalNominalBenefit.amount
                      .toString(),
                  'installmentsReduced': scenario.installmentsReduced,
                },
              )
              .toList(growable: false),
        },
      ),
    );
  }

  List<int> _allocationPercentages(int step) {
    final allocations = <int>[0];
    var allocation = step;
    while (allocation < 100) {
      allocations.add(allocation);
      allocation += step;
    }
    allocations.add(100);
    return allocations;
  }

  Decimal _monthlyFactor(Decimal annualGrowthFactor) {
    if (annualGrowthFactor == Decimal.zero) return Decimal.zero;
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
