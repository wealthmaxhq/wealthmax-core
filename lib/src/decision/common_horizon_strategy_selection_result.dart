import 'package:meta/meta.dart';

import '../money/money.dart';
import 'common_horizon_strategy_result.dart';
import 'common_horizon_strategy_selection_input.dart';

/// Immutable, explainable selection from a common-horizon allocation grid.
@immutable
final class CommonHorizonStrategySelectionResult {
  factory CommonHorizonStrategySelectionResult({
    required CommonHorizonStrategyResult optimization,
    required CommonHorizonStrategyObjective objective,
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
    return CommonHorizonStrategySelectionResult._(
      optimization: optimization,
      objective: objective,
      selectedScenarioIndex: selectedScenarioIndex,
    );
  }

  const CommonHorizonStrategySelectionResult._({
    required this.optimization,
    required this.objective,
    required this.selectedScenarioIndex,
  });

  final CommonHorizonStrategyResult optimization;
  final CommonHorizonStrategyObjective objective;
  final int selectedScenarioIndex;

  CommonHorizonScenario get selectedScenario =>
      optimization.scenarios[selectedScenarioIndex];

  /// Difference from the maximum-future-value scenario.
  ///
  /// This is zero for that objective and non-positive for other objectives.
  Money get futureValueDifferenceFromMaximum =>
      selectedScenario.totalFutureValue -
      optimization.bestScenario.totalFutureValue;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonStrategySelectionResult &&
            optimization == other.optimization &&
            objective == other.objective &&
            selectedScenarioIndex == other.selectedScenarioIndex;
  }

  @override
  int get hashCode =>
      Object.hash(optimization, objective, selectedScenarioIndex);

  @override
  String toString() {
    return 'CommonHorizonStrategySelectionResult('
        'objective: ${objective.name}, '
        'selectedScenarioIndex: $selectedScenarioIndex, '
        'selectedScenario: $selectedScenario, '
        'futureValueDifferenceFromMaximum: '
        '$futureValueDifferenceFromMaximum'
        ')';
  }
}
