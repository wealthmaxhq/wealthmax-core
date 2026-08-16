import 'package:meta/meta.dart';

import '../percentage/percentage.dart';
import 'common_horizon_sensitivity_result.dart';
import 'common_horizon_strategy_result.dart';
import 'common_horizon_strategy_selection_result.dart';

/// Consolidated normalized recommendation, threshold, and sensitivity grid.
@immutable
final class CommonHorizonDecisionAnalysisResult {
  factory CommonHorizonDecisionAnalysisResult({
    required CommonHorizonStrategySelectionResult selection,
    required CommonHorizonSensitivityResult sensitivity,
    required Percentage selectedGrossAnnualReturn,
    required int uniqueStrategyEvaluationCount,
    required int avoidedStrategyEvaluationCount,
  }) {
    if (uniqueStrategyEvaluationCount <= 0) {
      throw ArgumentError.value(
        uniqueStrategyEvaluationCount,
        'uniqueStrategyEvaluationCount',
        'At least one strategy evaluation is required.',
      );
    }
    if (avoidedStrategyEvaluationCount <= 0) {
      throw ArgumentError.value(
        avoidedStrategyEvaluationCount,
        'avoidedStrategyEvaluationCount',
        'At least one duplicate evaluation must be avoided.',
      );
    }

    CommonHorizonSensitivityPoint? reusedPoint;
    for (final point in sensitivity.points) {
      if (point.grossAnnualReturn == selectedGrossAnnualReturn) {
        reusedPoint = point;
        break;
      }
    }
    if (reusedPoint == null) {
      throw ArgumentError(
        'Sensitivity points must include the selected gross annual return.',
      );
    }

    final optimization = selection.optimization;
    if (optimization.commonHorizonInstallment !=
        sensitivity.breakEven.comparison.commonHorizonInstallment) {
      throw ArgumentError(
        'Selection and sensitivity must use the same common horizon.',
      );
    }
    if (optimization.netAnnualInvestmentReturn !=
        reusedPoint.comparison.netAnnualInvestmentReturn) {
      throw ArgumentError(
        'The reused selection and sensitivity returns must match.',
      );
    }
    if (optimization.allInvestScenario !=
            reusedPoint.comparison.allInvestScenario ||
        optimization.allPrepayScenario !=
            reusedPoint.comparison.allPrepayScenario) {
      throw ArgumentError(
        'The sensitivity point must reuse the selection endpoint scenarios.',
      );
    }
    if (uniqueStrategyEvaluationCount != sensitivity.points.length) {
      throw ArgumentError(
        'Unique strategy evaluation count must equal the scenario count.',
      );
    }

    return CommonHorizonDecisionAnalysisResult._(
      selection: selection,
      sensitivity: sensitivity,
      selectedGrossAnnualReturn: selectedGrossAnnualReturn,
      uniqueStrategyEvaluationCount: uniqueStrategyEvaluationCount,
      avoidedStrategyEvaluationCount: avoidedStrategyEvaluationCount,
    );
  }

  const CommonHorizonDecisionAnalysisResult._({
    required this.selection,
    required this.sensitivity,
    required this.selectedGrossAnnualReturn,
    required this.uniqueStrategyEvaluationCount,
    required this.avoidedStrategyEvaluationCount,
  });

  final CommonHorizonStrategySelectionResult selection;
  final CommonHorizonSensitivityResult sensitivity;
  final Percentage selectedGrossAnnualReturn;
  final int uniqueStrategyEvaluationCount;
  final int avoidedStrategyEvaluationCount;

  CommonHorizonStrategyResult get optimization => selection.optimization;
  CommonHorizonSensitivityPoint get selectedReturnSensitivityPoint =>
      sensitivity.points.firstWhere(
        (point) => point.grossAnnualReturn == selectedGrossAnnualReturn,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonDecisionAnalysisResult &&
            selection == other.selection &&
            sensitivity == other.sensitivity &&
            selectedGrossAnnualReturn == other.selectedGrossAnnualReturn &&
            uniqueStrategyEvaluationCount ==
                other.uniqueStrategyEvaluationCount &&
            avoidedStrategyEvaluationCount ==
                other.avoidedStrategyEvaluationCount;
  }

  @override
  int get hashCode => Object.hash(
    selection,
    sensitivity,
    selectedGrossAnnualReturn,
    uniqueStrategyEvaluationCount,
    avoidedStrategyEvaluationCount,
  );

  @override
  String toString() {
    return 'CommonHorizonDecisionAnalysisResult('
        'objective: ${selection.objective.name}, '
        'selectedGrossAnnualReturn: $selectedGrossAnnualReturn, '
        'selectedScenario: ${selection.selectedScenario}, '
        'breakEvenGrossAnnualReturn: '
        '${sensitivity.breakEven.breakEvenGrossAnnualReturn}, '
        'uniqueStrategyEvaluationCount: $uniqueStrategyEvaluationCount, '
        'avoidedStrategyEvaluationCount: $avoidedStrategyEvaluationCount'
        ')';
  }
}
