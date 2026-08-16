import 'package:meta/meta.dart';

import '../percentage/percentage.dart';
import 'common_horizon_strategy_selection_input.dart';
import 'return_sensitivity_input.dart';

/// Immutable inputs for one consolidated common-horizon decision analysis.
@immutable
final class CommonHorizonDecisionAnalysisInput {
  factory CommonHorizonDecisionAnalysisInput({
    required CommonHorizonStrategySelectionInput selection,
    required Iterable<Percentage> grossAnnualReturnScenarios,
  }) {
    final strategy = selection.hybridStrategy;
    final sensitivity = ReturnSensitivityInput(
      loan: strategy.loan,
      extraCash: strategy.extraCash,
      decisionInstallment: strategy.decisionInstallment,
      annualExpenseRatio: strategy.annualExpenseRatio,
      grossAnnualReturnScenarios: grossAnnualReturnScenarios,
    );
    if (!sensitivity.grossAnnualReturnScenarios.contains(
      strategy.grossAnnualInvestmentReturn,
    )) {
      throw ArgumentError.value(
        grossAnnualReturnScenarios,
        'grossAnnualReturnScenarios',
        'Scenarios must include the selected strategy gross annual return.',
      );
    }

    return CommonHorizonDecisionAnalysisInput._(
      selection: selection,
      sensitivity: sensitivity,
    );
  }

  const CommonHorizonDecisionAnalysisInput._({
    required this.selection,
    required this.sensitivity,
  });

  final CommonHorizonStrategySelectionInput selection;
  final ReturnSensitivityInput sensitivity;

  List<Percentage> get grossAnnualReturnScenarios =>
      sensitivity.grossAnnualReturnScenarios;

  CommonHorizonDecisionAnalysisInput copyWith({
    CommonHorizonStrategySelectionInput? selection,
    Iterable<Percentage>? grossAnnualReturnScenarios,
  }) {
    final nextSelection = selection ?? this.selection;
    return CommonHorizonDecisionAnalysisInput(
      selection: nextSelection,
      grossAnnualReturnScenarios:
          grossAnnualReturnScenarios ?? this.grossAnnualReturnScenarios,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonDecisionAnalysisInput &&
            selection == other.selection &&
            sensitivity == other.sensitivity;
  }

  @override
  int get hashCode => Object.hash(selection, sensitivity);

  @override
  String toString() {
    return 'CommonHorizonDecisionAnalysisInput('
        'selection: $selection, '
        'grossAnnualReturnScenarios: $grossAnnualReturnScenarios'
        ')';
  }
}
