import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../rounding/rounding_policy.dart';
import 'calculator_configuration.dart';
import 'hybrid_strategy_calculator.dart';
import 'hybrid_strategy_result.dart';
import 'strategy_selection_input.dart';
import 'strategy_selection_result.dart';

/// Selects a hybrid strategy using an explicit, deterministic user objective.
///
/// Formula `OPT-006` introduces no weighted score. It orders scenarios by
/// objective-specific observable metrics and documented deterministic ties.
@immutable
final class StrategySelectionCalculator {
  const StrategySelectionCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  });

  static const String formulaId = 'OPT-006';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<StrategySelectionResult> calculate(
    StrategySelectionInput input, {
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
    ).calculate(input.hybridStrategy, calculatedAt: calculatedAt);
    final optimization = hybridCalculation.value;
    final selectedIndex = _selectIndex(optimization, input.objective);
    final result = StrategySelectionResult(
      optimization: optimization,
      objective: input.objective,
      selectedScenarioIndex: selectedIndex,
    );

    return CalculationResult<StrategySelectionResult>(
      value: result,
      warnings: <CalculationWarning>[
        ...hybridCalculation.warnings,
        const CalculationWarning(
          code: 'OPT-006-OBJECTIVE-DEPENDENT',
          message:
              'The selected strategy depends on the user-selected objective; '
              'changing the objective can change the result.',
          severity: WarningSeverity.info,
        ),
        if (input.objective == StrategyObjective.maximumInvestedCapital)
          const CalculationWarning(
            code: 'OPT-006-LIQUIDITY-NOT-INFERRED',
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
          'financialAdvice': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'hybridStrategyFormulaId': HybridStrategyCalculator.formulaId,
          'scenarioCount': optimization.scenarios.length,
          'selectedScenarioIndex': selectedIndex,
          'selectedPrepaymentAllocationPercent': result
              .selectedScenario
              .requestedPrepaymentAllocation
              .percent
              .toString(),
          'selectedAppliedPrepayment': result
              .selectedScenario
              .appliedPrepayment
              .amount
              .toString(),
          'selectedInvestedAmount': result
              .selectedScenario
              .investedAmount
              .amount
              .toString(),
          'selectedInterestSaved': result.selectedScenario.interestSaved.amount
              .toString(),
          'selectedInvestmentGain': result
              .selectedScenario
              .investmentGain
              .amount
              .toString(),
          'selectedTotalNominalBenefit': result
              .selectedScenario
              .totalNominalBenefit
              .amount
              .toString(),
          'selectedInstallmentsReduced':
              result.selectedScenario.installmentsReduced,
          'maximumNominalBenefit': optimization
              .bestScenario
              .totalNominalBenefit
              .amount
              .toString(),
          'nominalBenefitDifferenceFromMaximum': result
              .nominalBenefitDifferenceFromMaximum
              .amount
              .toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }

  int _selectIndex(
    HybridStrategyResult optimization,
    StrategyObjective objective,
  ) {
    if (objective == StrategyObjective.maximumNominalBenefit) {
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
    HybridStrategyScenario candidate,
    HybridStrategyScenario current,
    StrategyObjective objective,
  ) {
    final comparisons = switch (objective) {
      StrategyObjective.maximumNominalBenefit => <int>[
        candidate.totalNominalBenefit.compareTo(current.totalNominalBenefit),
        candidate.investedAmount.compareTo(current.investedAmount),
      ],
      StrategyObjective.minimumInterestCost => <int>[
        candidate.interestSaved.compareTo(current.interestSaved),
        candidate.installmentsReduced.compareTo(current.installmentsReduced),
        candidate.investedAmount.compareTo(current.investedAmount),
      ],
      StrategyObjective.fastestDebtFree => <int>[
        candidate.installmentsReduced.compareTo(current.installmentsReduced),
        candidate.interestSaved.compareTo(current.interestSaved),
        candidate.investedAmount.compareTo(current.investedAmount),
      ],
      StrategyObjective.maximumInvestedCapital => <int>[
        candidate.investedAmount.compareTo(current.investedAmount),
        candidate.totalNominalBenefit.compareTo(current.totalNominalBenefit),
      ],
    };
    for (final comparison in comparisons) {
      if (comparison != 0) return comparison;
    }

    // Scenarios are ordered by ascending prepayment allocation, so retaining
    // the current scenario applies the documented lower-allocation tie-break.
    return 0;
  }

  List<String> _objectiveRules(StrategyObjective objective) {
    return switch (objective) {
      StrategyObjective.maximumNominalBenefit => <String>[
        'maximizeTotalNominalBenefit',
        'maximizeInvestedAmount',
        'minimizeRequestedPrepaymentAllocation',
      ],
      StrategyObjective.minimumInterestCost => <String>[
        'maximizeInterestSaved',
        'maximizeInstallmentsReduced',
        'maximizeInvestedAmount',
        'minimizeRequestedPrepaymentAllocation',
      ],
      StrategyObjective.fastestDebtFree => <String>[
        'maximizeInstallmentsReduced',
        'maximizeInterestSaved',
        'maximizeInvestedAmount',
        'minimizeRequestedPrepaymentAllocation',
      ],
      StrategyObjective.maximumInvestedCapital => <String>[
        'maximizeInvestedAmount',
        'maximizeTotalNominalBenefit',
        'minimizeRequestedPrepaymentAllocation',
      ],
    };
  }
}
