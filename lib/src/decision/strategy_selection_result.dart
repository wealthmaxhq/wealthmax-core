import 'package:meta/meta.dart';

import '../money/money.dart';
import 'hybrid_strategy_result.dart';
import 'strategy_selection_input.dart';

/// Immutable, explainable selection from a hybrid strategy grid.
@immutable
final class StrategySelectionResult {
  factory StrategySelectionResult({
    required HybridStrategyResult optimization,
    required StrategyObjective objective,
    required int selectedScenarioIndex,
  }) {
    if (selectedScenarioIndex < 0 ||
        selectedScenarioIndex >= optimization.scenarios.length) {
      throw RangeError.range(
        selectedScenarioIndex,
        0,
        optimization.scenarios.length - 1,
        'selectedScenarioIndex',
      );
    }
    return StrategySelectionResult._(
      optimization: optimization,
      objective: objective,
      selectedScenarioIndex: selectedScenarioIndex,
    );
  }

  const StrategySelectionResult._({
    required this.optimization,
    required this.objective,
    required this.selectedScenarioIndex,
  });

  final HybridStrategyResult optimization;
  final StrategyObjective objective;
  final int selectedScenarioIndex;

  HybridStrategyScenario get selectedScenario =>
      optimization.scenarios[selectedScenarioIndex];

  /// Difference from the maximum-nominal-benefit scenario.
  ///
  /// This is zero for that objective and non-positive for other objectives.
  Money get nominalBenefitDifferenceFromMaximum =>
      selectedScenario.totalNominalBenefit -
      optimization.bestScenario.totalNominalBenefit;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StrategySelectionResult &&
            optimization == other.optimization &&
            objective == other.objective &&
            selectedScenarioIndex == other.selectedScenarioIndex;
  }

  @override
  int get hashCode =>
      Object.hash(optimization, objective, selectedScenarioIndex);

  @override
  String toString() {
    return 'StrategySelectionResult('
        'objective: ${objective.name}, '
        'selectedScenarioIndex: $selectedScenarioIndex, '
        'selectedScenario: $selectedScenario, '
        'nominalBenefitDifferenceFromMaximum: '
        '$nominalBenefitDifferenceFromMaximum'
        ')';
  }
}
