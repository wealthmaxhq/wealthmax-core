import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../decision/adjusted_decision_analysis_calculator.dart';
import '../rounding/rounding_policy.dart';
import 'decision_analysis_report_input.dart';
import 'decision_analysis_report_result.dart';

/// Evaluates and aggregates named adjusted decision-analysis cases.
///
/// Formula `REP-001` retains every case's complete OPT-012 calculation result
/// while adding same-currency range, warning, and selection-change summaries.
@immutable
final class DecisionAnalysisReportCalculator {
  const DecisionAnalysisReportCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'REP-001';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<DecisionAnalysisReportResult> calculate(
    DecisionAnalysisReportInput input, {
    required DateTime calculatedAt,
  }) {
    final calculator = AdjustedDecisionAnalysisCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    );
    final cases = input.cases
        .map(
          (reportCase) => DecisionAnalysisReportCase(
            id: reportCase.id,
            label: reportCase.label,
            calculation: calculator.calculate(
              reportCase.analysis,
              calculatedAt: calculatedAt,
            ),
          ),
        )
        .toList(growable: false);
    final result = DecisionAnalysisReportResult(
      title: input.title,
      cases: cases,
    );

    return CalculationResult<DecisionAnalysisReportResult>(
      value: result,
      warnings: <CalculationWarning>[
        const CalculationWarning(
          code: 'REP-001-CASES-NOT-PROBABILITIES',
          message:
              'Report cases are named deterministic assumptions, not '
              'probability-weighted forecasts.',
          severity: WarningSeverity.caution,
        ),
        const CalculationWarning(
          code: 'REP-001-CROSS-CASE-RANGE',
          message:
              'The selected-value range summarizes supplied cases and does '
              'not represent a statistical confidence interval.',
          severity: WarningSeverity.info,
        ),
        if (result.criticalWarningCaseCount > 0)
          CalculationWarning(
            code: 'REP-001-CRITICAL-CASE-WARNINGS',
            message:
                '${result.criticalWarningCaseCount} report case(s) contain '
                'critical calculation warnings and require review.',
            severity: WarningSeverity.critical,
          ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'title': input.title,
          'caseIds': input.cases.map((reportCase) => reportCase.id).toList(),
          'caseCount': input.cases.length,
        },
        assumptions: <String, Object?>{
          'caseMeaning': 'deterministicNamedAssumptions',
          'probabilityWeighted': false,
          'casesEvaluatedAtSameTimestamp': true,
          'crossCaseCurrencyRequired': true,
          'caseCalculationProvenanceRetained': true,
          'financialAdvice': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'caseFormulaId': AdjustedDecisionAnalysisCalculator.formulaId,
          'minimumSelectedValueCaseId': result.minimumSelectedValueCase.id,
          'maximumSelectedValueCaseId': result.maximumSelectedValueCase.id,
          'selectedRealValueRange': result.selectedRealValueRange.amount
              .toString(),
          'currency': result.selectedRealValueRange.currency.code,
          'taxChangedSelectionCount': result.taxChangedSelectionCount,
          'criticalWarningCaseCount': result.criticalWarningCaseCount,
          'cases': cases
              .map(
                (reportCase) => <String, Object?>{
                  'id': reportCase.id,
                  'label': reportCase.label,
                  'formulaId': reportCase.calculation.metadata.formulaId,
                  'selectedRealAfterTaxFutureValue': reportCase
                      .selectedRealAfterTaxFutureValue
                      .amount
                      .toString(),
                  'selectedPrepaymentAllocationPercent': reportCase
                      .analysis
                      .selectedScenario
                      .nominalScenario
                      .requestedPrepaymentAllocation
                      .percent
                      .toString(),
                  'warningCount': reportCase.calculation.warningCount,
                  'hasCriticalWarnings':
                      reportCase.calculation.hasCriticalWarnings,
                },
              )
              .toList(growable: false),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }
}
