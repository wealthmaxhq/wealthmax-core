import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../rounding/rounding_policy.dart';
import 'break_even_return_input.dart';
import 'calculator_configuration.dart';
import 'common_horizon_break_even_calculator.dart';
import 'common_horizon_decision_analysis_input.dart';
import 'common_horizon_decision_analysis_result.dart';
import 'common_horizon_sensitivity_result.dart';
import 'common_horizon_strategy_calculator.dart';
import 'common_horizon_strategy_result.dart';
import 'common_horizon_strategy_selection_calculator.dart';
import 'hybrid_strategy_input.dart';

/// Produces one consolidated, cash-flow-normalized decision analysis.
///
/// Formula `OPT-011` calculates the selected-return allocation grid once and
/// reuses its endpoint scenarios in the sensitivity grid. This avoids the
/// duplicate strategy evaluation performed by separate OPT-009 and OPT-010
/// calls while preserving their result contracts.
@immutable
final class CommonHorizonDecisionAnalysisCalculator {
  const CommonHorizonDecisionAnalysisCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  });

  static const String formulaId = 'OPT-011';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<CommonHorizonDecisionAnalysisResult> calculate(
    CommonHorizonDecisionAnalysisInput input, {
    required DateTime calculatedAt,
  }) {
    validateDecisionCalculatorConfiguration(
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    );
    final strategy = input.selection.hybridStrategy;
    final strategyCalculator = CommonHorizonStrategyCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    );
    final selectedReturnCalculation = strategyCalculator.calculate(
      strategy,
      calculatedAt: calculatedAt,
    );
    final selection = CommonHorizonStrategySelectionCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    ).selectFrom(selectedReturnCalculation.value, input.selection.objective);

    final breakEvenCalculation =
        CommonHorizonBreakEvenCalculator(
          roundingPolicy: roundingPolicy,
          calculationScale: calculationScale,
          maximumIterations: maximumIterations,
        ).calculate(
          BreakEvenReturnInput(
            loan: strategy.loan,
            extraCash: strategy.extraCash,
            decisionInstallment: strategy.decisionInstallment,
            annualExpenseRatio: strategy.annualExpenseRatio,
          ),
          calculatedAt: calculatedAt,
        );

    final points = input.grossAnnualReturnScenarios
        .map(
          (scenario) => CommonHorizonSensitivityPoint(
            grossAnnualReturn: scenario,
            comparison: scenario == strategy.grossAnnualInvestmentReturn
                ? _endpointComparison(selectedReturnCalculation.value)
                : strategyCalculator
                      .calculate(
                        HybridStrategyInput(
                          loan: strategy.loan,
                          extraCash: strategy.extraCash,
                          decisionInstallment: strategy.decisionInstallment,
                          grossAnnualInvestmentReturn: scenario,
                          annualExpenseRatio: strategy.annualExpenseRatio,
                          allocationStepPercent: 100,
                        ),
                        calculatedAt: calculatedAt,
                      )
                      .value,
          ),
        )
        .toList(growable: false);
    final sensitivity = CommonHorizonSensitivityResult(
      breakEven: breakEvenCalculation.value,
      annualExpenseRatio: strategy.annualExpenseRatio,
      points: points,
    );
    final result = CommonHorizonDecisionAnalysisResult(
      selection: selection,
      sensitivity: sensitivity,
      selectedGrossAnnualReturn: strategy.grossAnnualInvestmentReturn,
      uniqueStrategyEvaluationCount: points.length,
      avoidedStrategyEvaluationCount: 1,
    );

    final warningsByCode = <String, CalculationWarning>{
      for (final warning in selectedReturnCalculation.warnings)
        warning.code: warning,
      for (final warning in breakEvenCalculation.warnings)
        warning.code: warning,
      'OPT-011-CONSOLIDATED-ANALYSIS': const CalculationWarning(
        code: 'OPT-011-CONSOLIDATED-ANALYSIS',
        message:
            'The recommendation, threshold, and sensitivity grid share one '
            'cash-flow-normalized valuation framework.',
        severity: WarningSeverity.info,
      ),
      'OPT-011-OBJECTIVE-DEPENDENT': const CalculationWarning(
        code: 'OPT-011-OBJECTIVE-DEPENDENT',
        message:
            'The selected allocation depends on the explicit user objective; '
            'changing the objective can change the recommendation.',
        severity: WarningSeverity.info,
      ),
      'OPT-011-SCENARIOS-NOT-PROBABILITIES': const CalculationWarning(
        code: 'OPT-011-SCENARIOS-NOT-PROBABILITIES',
        message:
            'Return scenarios are deterministic assumptions, not '
            'probabilities, forecasts, or guarantees.',
        severity: WarningSeverity.caution,
      ),
    };

    return CalculationResult<CommonHorizonDecisionAnalysisResult>(
      value: result,
      warnings: warningsByCode.values,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'objective': input.selection.objective.name,
          'loanPrincipal': strategy.loan.principal.amount.toString(),
          'currency': strategy.loan.principal.currency.code,
          'loanAnnualInterestRatePercent': strategy
              .loan
              .annualInterestRate
              .percent
              .toString(),
          'loanTenureMonths': strategy.loan.tenureMonths,
          'extraCash': strategy.extraCash.amount.toString(),
          'decisionInstallment': strategy.decisionInstallment,
          'selectedGrossAnnualReturnPercent': strategy
              .grossAnnualInvestmentReturn
              .percent
              .toString(),
          'annualExpenseRatioPercent': strategy.annualExpenseRatio.percent
              .toString(),
          'allocationStepPercent': strategy.allocationStepPercent,
          'grossAnnualReturnScenariosPercent': input.grossAnnualReturnScenarios
              .map((scenario) => scenario.percent.toString())
              .toList(growable: false),
        },
        assumptions: <String, Object?>{
          'comparisonHorizon': 'baselineLoanPayoffInstallment',
          'cashFlowTimingNormalized': true,
          'savedPaymentTreatment': 'fullyReinvestedToCommonHorizon',
          'selectionMethod': 'lexicographicObjectiveMetrics',
          'weightedScoreUsed': false,
          'scenarioMeaning': 'deterministicReturnAssumptions',
          'selectedReturnEndpointsReused': true,
          'feeConvention': 'endOfYearAssetBasedFee',
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
          'commonHorizonBreakEvenFormulaId':
              CommonHorizonBreakEvenCalculator.formulaId,
          'commonHorizonSelectionFormulaId':
              CommonHorizonStrategySelectionCalculator.formulaId,
          'commonHorizonInstallment':
              result.optimization.commonHorizonInstallment,
          'selectedScenarioIndex': result.selection.selectedScenarioIndex,
          'selectedPrepaymentAllocationPercent': result
              .selection
              .selectedScenario
              .requestedPrepaymentAllocation
              .percent
              .toString(),
          'selectedFutureValue': result
              .selection
              .selectedScenario
              .totalFutureValue
              .amount
              .toString(),
          'breakEvenGrossAnnualReturnPercent': result
              .sensitivity
              .breakEven
              .breakEvenGrossAnnualReturn
              .percent
              .toString(),
          'scenarioCount': points.length,
          'uniqueStrategyEvaluationCount': result.uniqueStrategyEvaluationCount,
          'standaloneStrategyEvaluationCount': points.length + 1,
          'avoidedStrategyEvaluationCount':
              result.avoidedStrategyEvaluationCount,
          'reusedScenarioGrossAnnualReturnPercent': result
              .selectedGrossAnnualReturn
              .percent
              .toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }

  CommonHorizonStrategyResult _endpointComparison(
    CommonHorizonStrategyResult optimization,
  ) {
    return CommonHorizonStrategyResult(
      scenarios: <CommonHorizonScenario>[
        optimization.allInvestScenario,
        optimization.allPrepayScenario,
      ],
      netAnnualInvestmentReturn: optimization.netAnnualInvestmentReturn,
      commonHorizonInstallment: optimization.commonHorizonInstallment,
    );
  }
}
