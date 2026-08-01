import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../loan/amortization_schedule.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'calculator_configuration.dart';
import 'common_horizon_strategy_preparation.dart';
import 'common_horizon_strategy_result.dart';
import 'hybrid_strategy_calculator.dart';
import 'hybrid_strategy_input.dart';
import 'hybrid_strategy_result.dart';

/// Values every allocation at the baseline loan payoff installment.
///
/// Formula `OPT-007` grows the initial investment and each future scheduled
/// loan-payment saving to a shared horizon using the same net investment rate.
@immutable
final class CommonHorizonStrategyCalculator {
  const CommonHorizonStrategyCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  });

  static const String formulaId = 'OPT-007';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  /// Prepares loan-dependent scenarios once for repeated return evaluation.
  CommonHorizonStrategyPreparation prepare(
    HybridStrategyInput input, {
    required DateTime calculatedAt,
  }) {
    return CommonHorizonStrategyPreparation(
      sourceInput: input,
      template: calculate(input, calculatedAt: calculatedAt).value,
    );
  }

  /// Revalues a prepared allocation grid without rebuilding loan schedules.
  CommonHorizonStrategyResult revaluePrepared(
    CommonHorizonStrategyPreparation preparation, {
    required Percentage grossAnnualInvestmentReturn,
    required Percentage annualExpenseRatio,
  }) {
    final input = preparation.sourceInput.copyWith(
      grossAnnualInvestmentReturn: grossAnnualInvestmentReturn,
      annualExpenseRatio: annualExpenseRatio,
    );
    final commonHorizon = preparation.template.commonHorizonInstallment;
    final horizonMonths = commonHorizon - input.decisionInstallment;
    final netAnnualFactor =
        (Decimal.one + grossAnnualInvestmentReturn.fraction) *
        (Decimal.one - annualExpenseRatio.fraction);
    final netAnnualReturn = Percentage.fromFraction(
      (netAnnualFactor - Decimal.one).toString(),
    );
    final monthlyFactor = horizonMonths == 0
        ? Decimal.one
        : _monthlyFactor(netAnnualFactor);
    final cumulativeFactor = _powExact(monthlyFactor, horizonMonths);
    final currency = input.extraCash.currency;

    final allocations = preparation.template.scenarios
        .map((scenario) {
          final allocation = scenario.allocation;
          final investmentFutureValue = Money(
            amount: roundingPolicy.round(
              allocation.investedAmount.amount * cumulativeFactor,
              decimalPlaces: currency.decimalPlaces,
            ),
            currency: currency,
          );
          return HybridStrategyScenario(
            requestedPrepaymentAllocation:
                allocation.requestedPrepaymentAllocation,
            availableCash: allocation.availableCash,
            requestedPrepayment: allocation.requestedPrepayment,
            loanPrepayment: allocation.loanPrepayment,
            investedAmount: allocation.investedAmount,
            investmentFutureValue: investmentFutureValue,
            investmentHorizonMonths: horizonMonths,
          );
        })
        .toList(growable: false);
    final hybrid = HybridStrategyResult(
      scenarios: allocations,
      netAnnualInvestmentReturn: netAnnualReturn,
    );
    return CommonHorizonStrategyResult(
      scenarios: hybrid.scenarios
          .map(
            (allocation) => _normalizeScenario(
              allocation,
              decisionInstallment: input.decisionInstallment,
              commonHorizon: commonHorizon,
              monthlyFactor: monthlyFactor,
            ),
          )
          .toList(growable: false),
      netAnnualInvestmentReturn: netAnnualReturn,
      commonHorizonInstallment: commonHorizon,
    );
  }

  CalculationResult<CommonHorizonStrategyResult> calculate(
    HybridStrategyInput input, {
    required DateTime calculatedAt,
  }) {
    validateDecisionCalculatorConfiguration(
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    );
    final hybridCalculation = HybridStrategyCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    ).calculate(input, calculatedAt: calculatedAt);
    final hybrid = hybridCalculation.value;
    final commonHorizon =
        hybrid.scenarios.first.allocationLoanBaseline.paymentCount;
    final netAnnualFactor =
        Decimal.one + hybrid.netAnnualInvestmentReturn.fraction;
    final monthlyFactor = commonHorizon == input.decisionInstallment
        ? Decimal.one
        : _monthlyFactor(netAnnualFactor);

    final scenarios = hybrid.scenarios
        .map(
          (allocation) => _normalizeScenario(
            allocation,
            decisionInstallment: input.decisionInstallment,
            commonHorizon: commonHorizon,
            monthlyFactor: monthlyFactor,
          ),
        )
        .toList(growable: false);
    final result = CommonHorizonStrategyResult(
      scenarios: scenarios,
      netAnnualInvestmentReturn: hybrid.netAnnualInvestmentReturn,
      commonHorizonInstallment: commonHorizon,
    );

    return CalculationResult<CommonHorizonStrategyResult>(
      value: result,
      warnings: <CalculationWarning>[
        const CalculationWarning(
          code: 'OPT-007-PROJECTION-NOT-GUARANTEED',
          message:
              'Investment returns are assumptions and are not guaranteed; '
              'the highest common-horizon value is not financial advice.',
          severity: WarningSeverity.info,
        ),
        const CalculationWarning(
          code: 'OPT-007-REINVESTMENT-DISCIPLINE-ASSUMED',
          message:
              'Every scheduled loan-payment saving is assumed to be invested '
              'when it occurs and retained until the common horizon.',
          severity: WarningSeverity.caution,
        ),
        const CalculationWarning(
          code: 'OPT-007-TAX-INFLATION-RISK-EXCLUDED',
          message:
              'Taxes, inflation, liquidity needs, and investment risk are '
              'excluded and can change the preferred allocation.',
          severity: WarningSeverity.caution,
        ),
        if (hybridCalculation.warnings.any(
          (warning) => warning.code == 'OPT-005-PREPAYMENT-CAPPED',
        ))
          const CalculationWarning(
            code: 'OPT-007-PREPAYMENT-CAPPED',
            message:
                'One or more requested prepayments exceeded the amount the '
                'loan could accept; excess cash was invested.',
            severity: WarningSeverity.info,
          ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'loanPrincipal': input.loan.principal.amount.toString(),
          'currency': input.loan.principal.currency.code,
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
          'comparisonHorizon': 'baselineLoanPayoffInstallment',
          'commonHorizonInstallment': commonHorizon,
          'initialInvestmentTiming': 'afterDecisionInstallment',
          'savedPaymentTiming': 'endOfEachInstallment',
          'savedPaymentTreatment': 'fullyReinvestedToCommonHorizon',
          'paymentSavingDefinition':
              'baselineScheduledPaymentMinusStrategyScheduledPayment',
          'prepaymentExcludedFromSavedPayments': true,
          'paymentSavingFutureValueRounding': 'eachCashFlowAtCurrencyPrecision',
          'cashFlowTimingNormalized': true,
          'rankingObjective': 'maximumTotalFutureValueAtCommonHorizon',
          'tieBreak': 'higherInitialInvestedAmount',
          'investmentRateConvention': 'effectiveAnnualReturnAfterExpenseRatio',
          'taxesIncluded': false,
          'inflationIncluded': false,
          'riskAdjusted': false,
          'financialAdvice': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'hybridStrategyFormulaId': HybridStrategyCalculator.formulaId,
          'scenarioCount': scenarios.length,
          'netAnnualInvestmentReturnPercent': hybrid
              .netAnnualInvestmentReturn
              .percent
              .toString(),
          'monthlyNetGrowthFactor': monthlyFactor.toString(),
          'bestScenarioIndex': result.bestScenarioIndex,
          'bestPrepaymentAllocationPercent': result
              .bestScenario
              .requestedPrepaymentAllocation
              .percent
              .toString(),
          'bestTotalFutureValue': result.bestScenario.totalFutureValue.amount
              .toString(),
          'bestFutureWealthGain': result.bestScenario.futureWealthGain.amount
              .toString(),
          'bestPaymentSavingCashFlowCount':
              result.bestScenario.reinvestedPaymentSavings.length,
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
          'scenarios': scenarios
              .map(
                (scenario) => <String, Object?>{
                  'requestedPrepaymentAllocationPercent': scenario
                      .requestedPrepaymentAllocation
                      .percent
                      .toString(),
                  'appliedPrepayment': scenario
                      .allocation
                      .appliedPrepayment
                      .amount
                      .toString(),
                  'initialInvestedAmount': scenario
                      .allocation
                      .investedAmount
                      .amount
                      .toString(),
                  'initialInvestmentFutureValue': scenario
                      .initialInvestmentFutureValue
                      .amount
                      .toString(),
                  'nominalPaymentSavings': scenario.nominalPaymentSavings.amount
                      .toString(),
                  'futureValueOfPaymentSavings': scenario
                      .futureValueOfPaymentSavings
                      .amount
                      .toString(),
                  'totalFutureValue': scenario.totalFutureValue.amount
                      .toString(),
                  'futureWealthGain': scenario.futureWealthGain.amount
                      .toString(),
                  'paymentSavingCashFlowCount':
                      scenario.reinvestedPaymentSavings.length,
                },
              )
              .toList(growable: false),
        },
      ),
    );
  }

  CommonHorizonScenario _normalizeScenario(
    HybridStrategyScenario allocation, {
    required int decisionInstallment,
    required int commonHorizon,
    required Decimal monthlyFactor,
  }) {
    final baseline = allocation.allocationLoanBaseline;
    final strategy = allocation.loanPrepayment.strategy;
    final currency = allocation.availableCash.currency;
    final cashFlows = <CommonHorizonCashFlow>[];
    var futureValueOfSavings = Money.zero(currency);

    for (
      var installment = decisionInstallment;
      installment <= commonHorizon;
      installment++
    ) {
      final baselinePayment = baseline.entries[installment - 1].payment;
      final strategyPayment = installment <= strategy.paymentCount
          ? strategy.entries[installment - 1].payment
          : Money.zero(currency);
      final saving = baselinePayment - strategyPayment;
      if (saving.isNegative) {
        throw StateError(
          'Reduce-tenure strategy payment exceeds baseline payment at '
          'installment $installment.',
        );
      }
      if (saving.isZero) continue;

      final growthMonths = commonHorizon - installment;
      final futureValue = Money(
        amount: roundingPolicy.round(
          saving.amount * _powExact(monthlyFactor, growthMonths),
          decimalPlaces: currency.decimalPlaces,
        ),
        currency: currency,
      );
      final cashFlow = CommonHorizonCashFlow(
        installmentNumber: installment,
        growthMonths: growthMonths,
        paymentSaving: saving,
        futureValue: futureValue,
      );
      cashFlows.add(cashFlow);
      futureValueOfSavings += futureValue;
    }

    return CommonHorizonScenario(
      allocation: allocation,
      reinvestedPaymentSavings: cashFlows,
      futureValueOfPaymentSavings: futureValueOfSavings,
    );
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

extension on HybridStrategyScenario {
  AmortizationSchedule get allocationLoanBaseline => loanPrepayment.baseline;
}
