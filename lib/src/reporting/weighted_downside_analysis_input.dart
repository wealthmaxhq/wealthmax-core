import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import 'weighted_decision_analysis_calculator.dart';
import 'weighted_decision_analysis_result.dart';

/// Inputs for measuring downside against a real after-tax value target.
@immutable
final class WeightedDownsideAnalysisInput {
  factory WeightedDownsideAnalysisInput({
    required CalculationResult<WeightedDecisionAnalysisResult> analysis,
    required Money targetRealAfterTaxFutureValue,
  }) {
    if (analysis.metadata.formulaId !=
        WeightedDecisionAnalysisCalculator.formulaId) {
      throw ArgumentError.value(
        analysis.metadata.formulaId,
        'analysis',
        'Downside analysis requires a REP-003 calculation result.',
      );
    }
    final currency = analysis.value.expectedRealAfterTaxFutureValue.currency;
    if (targetRealAfterTaxFutureValue.currency != currency ||
        targetRealAfterTaxFutureValue.isNegative) {
      throw ArgumentError.value(
        targetRealAfterTaxFutureValue,
        'targetRealAfterTaxFutureValue',
        'Target must be non-negative and use ${currency.code}.',
      );
    }
    return WeightedDownsideAnalysisInput._(
      analysis: analysis,
      targetRealAfterTaxFutureValue: targetRealAfterTaxFutureValue,
    );
  }

  const WeightedDownsideAnalysisInput._({
    required this.analysis,
    required this.targetRealAfterTaxFutureValue,
  });

  final CalculationResult<WeightedDecisionAnalysisResult> analysis;
  final Money targetRealAfterTaxFutureValue;

  WeightedDownsideAnalysisInput copyWith({
    CalculationResult<WeightedDecisionAnalysisResult>? analysis,
    Money? targetRealAfterTaxFutureValue,
  }) => WeightedDownsideAnalysisInput(
    analysis: analysis ?? this.analysis,
    targetRealAfterTaxFutureValue:
        targetRealAfterTaxFutureValue ?? this.targetRealAfterTaxFutureValue,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightedDownsideAnalysisInput &&
          analysis == other.analysis &&
          targetRealAfterTaxFutureValue == other.targetRealAfterTaxFutureValue;

  @override
  int get hashCode => Object.hash(analysis, targetRealAfterTaxFutureValue);

  @override
  String toString() =>
      'WeightedDownsideAnalysisInput('
      'targetRealAfterTaxFutureValue: $targetRealAfterTaxFutureValue)';
}
