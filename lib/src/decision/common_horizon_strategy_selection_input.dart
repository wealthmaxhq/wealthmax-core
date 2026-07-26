import 'package:meta/meta.dart';

import 'hybrid_strategy_input.dart';

/// An explicit objective for selecting a cash-flow-normalized allocation.
enum CommonHorizonStrategyObjective {
  maximumFutureValue,
  minimumInterestCost,
  fastestDebtFree,
  maximumInvestedCapital,
}

/// Immutable inputs for objective selection at a common valuation horizon.
@immutable
final class CommonHorizonStrategySelectionInput {
  const CommonHorizonStrategySelectionInput({
    required this.hybridStrategy,
    required this.objective,
  });

  final HybridStrategyInput hybridStrategy;
  final CommonHorizonStrategyObjective objective;

  CommonHorizonStrategySelectionInput copyWith({
    HybridStrategyInput? hybridStrategy,
    CommonHorizonStrategyObjective? objective,
  }) {
    return CommonHorizonStrategySelectionInput(
      hybridStrategy: hybridStrategy ?? this.hybridStrategy,
      objective: objective ?? this.objective,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonStrategySelectionInput &&
            hybridStrategy == other.hybridStrategy &&
            objective == other.objective;
  }

  @override
  int get hashCode => Object.hash(hybridStrategy, objective);

  @override
  String toString() {
    return 'CommonHorizonStrategySelectionInput('
        'hybridStrategy: $hybridStrategy, '
        'objective: ${objective.name}'
        ')';
  }
}
