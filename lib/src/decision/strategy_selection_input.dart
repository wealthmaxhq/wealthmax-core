import 'package:meta/meta.dart';

import 'hybrid_strategy_input.dart';

/// The explicit user objective used to select a hybrid strategy.
enum StrategyObjective {
  maximumNominalBenefit,
  minimumInterestCost,
  fastestDebtFree,
  maximumInvestedCapital,
}

/// Immutable inputs for objective-based strategy selection.
@immutable
final class StrategySelectionInput {
  const StrategySelectionInput({
    required this.hybridStrategy,
    required this.objective,
  });

  final HybridStrategyInput hybridStrategy;
  final StrategyObjective objective;

  StrategySelectionInput copyWith({
    HybridStrategyInput? hybridStrategy,
    StrategyObjective? objective,
  }) {
    return StrategySelectionInput(
      hybridStrategy: hybridStrategy ?? this.hybridStrategy,
      objective: objective ?? this.objective,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StrategySelectionInput &&
            hybridStrategy == other.hybridStrategy &&
            objective == other.objective;
  }

  @override
  int get hashCode => Object.hash(hybridStrategy, objective);

  @override
  String toString() {
    return 'StrategySelectionInput('
        'hybridStrategy: $hybridStrategy, '
        'objective: ${objective.name}'
        ')';
  }
}
