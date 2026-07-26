import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../rounding/rounding_policy.dart';
import 'common_horizon_strategy_calculator.dart';
import 'common_horizon_strategy_result.dart';
import 'common_horizon_strategy_selection_input.dart';
import 'common_horizon_strategy_selection_result.dart';

/// Selects a normalized allocation using an explicit deterministic objective.
///
/// Formula `OPT-010` uses lexicographic observable metrics and documented
/// tie-breaks. It never combines unlike financial dimensions into a score.
@immutable
final class CommonHorizonStrategySelectionCalculator {
  const CommonHorizonStrategySelectionCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'OPT-010';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<CommonHorizonStrategySelectionResult> calculate(
    CommonHorizonStrategySelectionInput input, {
    required DateTime calculatedAt,
  }) {
    final strategyCalculation = CommonHorizonStrategyCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    ).calculate(input.hybridStrategy, calculatedAt: calculatedAt);
    final optimization = strategyCalculation.value;
    final result = selectFrom(optimization, input.objective);
    final selectedIndex = result.selectedScenarioIndex;

    return CalculationResult<CommonHorizonStrategySelectionResult>(
      value: result,
      warnings: <CalculationWarning>[
        ...strategyCalculation.warnings,
        const CalculationWarning(
          code: 'OPT-010-OBJECTIVE-DEPENDENT',
          message:
              'The selected strategy depends on the explicit user objective; '
              'changing the objective can change the result.',
          severity: WarningSeverity.info,
        ),
        if (input.objective ==
            CommonHorizonStrategyObjective.maximumInvestedCapital)
          const CalculationWarning(
            code: 'OPT-010-LIQUIDITY-NOT-INFERRED',
            message:
                'Invested capital is not necessarily liquid; lock-ins, exit '
                'loads, and market conditions are not modeled.',
            severity: WarningSeverity.caution,
          ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'objective': input.objective.name,
          'loanPrincipal': input.hybridStrategy.loan.principal.amount
              .toString(),
          'currency': input.hybridStrategy.loan.principal.currency.code,
          'extraCash': input.hybridStrategy.extraCash.amount.toString(),
          'decisionInstallment': input.hybridStrategy.decisionInstallment,
          'grossAnnualInvestmentReturnPercent': input
              .hybridStrategy
              .grossAnnualInvestmentReturn
              .percent
              .toString(),
          'annualExpenseRatioPercent': input
              .hybridStrategy
              .annualExpenseRatio
              .percent
              .toString(),
          'allocationStepPercent': input.hybridStrategy.allocationStepPercent,
        },
        assumptions: <String, Object?>{
          'selectionMethod': 'lexicographicObjectiveMetrics',
          'weightedScoreUsed': false,
          'objectiveRules': _objectiveRules(input.objective),
          'finalTieBreak': 'lowerRequestedPrepaymentAllocation',
          'comparisonHorizon': 'baselineLoanPayoffInstallment',
          'cashFlowTimingNormalized': true,
          'savedPaymentTreatment': 'fullyReinvestedToCommonHorizon',
          'taxesIncluded': false,
          'inflationIncluded': false,
          'investmentRiskAdjusted': false,
          'financialAdvice': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'commonHorizonStrategyFormulaId':
              CommonHorizonStrategyCalculator.formulaId,
          'scenarioCount': optimization.scenarios.length,
          'commonHorizonInstallment': optimization.commonHorizonInstallment,
          'selectedScenarioIndex': selectedIndex,
          'selectedPrepaymentAllocationPercent': result
              .selectedScenario
              .requestedPrepaymentAllocation
              .percent
              .toString(),
          'selectedAppliedPrepayment': result
              .selectedScenario
              .allocation
              .appliedPrepayment
              .amount
              .toString(),
          'selectedInvestedAmount': result
              .selectedScenario
              .allocation
              .investedAmount
              .amount
              .toString(),
          'selectedInterestSaved': result
              .selectedScenario
              .allocation
              .interestSaved
              .amount
              .toString(),
          'selectedInstallmentsReduced':
              result.selectedScenario.allocation.installmentsReduced,
          'selectedFutureValue': result.selectedScenario.totalFutureValue.amount
              .toString(),
          'maximumFutureValue': optimization
              .bestScenario
              .totalFutureValue
              .amount
              .toString(),
          'futureValueDifferenceFromMaximum': result
              .futureValueDifferenceFromMaximum
              .amount
              .toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }

  /// Applies the documented objective rules to an already evaluated grid.
  ///
  /// This allows higher-level analyses to reuse a common-horizon strategy
  /// calculation instead of recalculating identical scenarios.
  CommonHorizonStrategySelectionResult selectFrom(
    CommonHorizonStrategyResult optimization,
    CommonHorizonStrategyObjective objective,
  ) {
    return CommonHorizonStrategySelectionResult(
      optimization: optimization,
      objective: objective,
      selectedScenarioIndex: _selectIndex(optimization, objective),
    );
  }

  int _selectIndex(
    CommonHorizonStrategyResult optimization,
    CommonHorizonStrategyObjective objective,
  ) {
    if (objective == CommonHorizonStrategyObjective.maximumFutureValue) {
      return optimization.bestScenarioIndex;
    }

    var selectedIndex = 0;
    for (var index = 1; index < optimization.scenarios.length; index++) {
      if (_compare(
            optimization.scenarios[index],
            optimization.scenarios[selectedIndex],
            objective,
          ) >
          0) {
        selectedIndex = index;
      }
    }
    return selectedIndex;
  }

  int _compare(
    CommonHorizonScenario candidate,
    CommonHorizonScenario current,
    CommonHorizonStrategyObjective objective,
  ) {
    final candidateAllocation = candidate.allocation;
    final currentAllocation = current.allocation;
    final comparisons = switch (objective) {
      CommonHorizonStrategyObjective.maximumFutureValue => <int>[
        candidate.totalFutureValue.compareTo(current.totalFutureValue),
        candidateAllocation.investedAmount.compareTo(
          currentAllocation.investedAmount,
        ),
      ],
      CommonHorizonStrategyObjective.minimumInterestCost => <int>[
        candidateAllocation.interestSaved.compareTo(
          currentAllocation.interestSaved,
        ),
        candidateAllocation.installmentsReduced.compareTo(
          currentAllocation.installmentsReduced,
        ),
        candidate.totalFutureValue.compareTo(current.totalFutureValue),
        candidateAllocation.investedAmount.compareTo(
          currentAllocation.investedAmount,
        ),
      ],
      CommonHorizonStrategyObjective.fastestDebtFree => <int>[
        candidateAllocation.installmentsReduced.compareTo(
          currentAllocation.installmentsReduced,
        ),
        candidateAllocation.interestSaved.compareTo(
          currentAllocation.interestSaved,
        ),
        candidate.totalFutureValue.compareTo(current.totalFutureValue),
        candidateAllocation.investedAmount.compareTo(
          currentAllocation.investedAmount,
        ),
      ],
      CommonHorizonStrategyObjective.maximumInvestedCapital => <int>[
        candidateAllocation.investedAmount.compareTo(
          currentAllocation.investedAmount,
        ),
        candidate.totalFutureValue.compareTo(current.totalFutureValue),
      ],
    };
    for (final comparison in comparisons) {
      if (comparison != 0) return comparison;
    }

    // Scenarios are ordered by ascending prepayment allocation, so retaining
    // the current scenario applies the documented lower-allocation tie-break.
    return 0;
  }

  List<String> _objectiveRules(CommonHorizonStrategyObjective objective) {
    return switch (objective) {
      CommonHorizonStrategyObjective.maximumFutureValue => <String>[
        'maximizeCommonHorizonFutureValue',
        'maximizeInvestedAmount',
        'minimizeRequestedPrepaymentAllocation',
      ],
      CommonHorizonStrategyObjective.minimumInterestCost => <String>[
        'maximizeInterestSaved',
        'maximizeInstallmentsReduced',
        'maximizeCommonHorizonFutureValue',
        'maximizeInvestedAmount',
        'minimizeRequestedPrepaymentAllocation',
      ],
      CommonHorizonStrategyObjective.fastestDebtFree => <String>[
        'maximizeInstallmentsReduced',
        'maximizeInterestSaved',
        'maximizeCommonHorizonFutureValue',
        'maximizeInvestedAmount',
        'minimizeRequestedPrepaymentAllocation',
      ],
      CommonHorizonStrategyObjective.maximumInvestedCapital => <String>[
        'maximizeInvestedAmount',
        'maximizeCommonHorizonFutureValue',
        'minimizeRequestedPrepaymentAllocation',
      ],
    };
  }
}
