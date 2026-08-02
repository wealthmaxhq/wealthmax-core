import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'weighted_downside_analysis_input.dart';

/// Probability-weighted downside metrics for a real after-tax value target.
@immutable
final class WeightedDownsideAnalysisResult {
  factory WeightedDownsideAnalysisResult({
    required WeightedDownsideAnalysisInput input,
    required Percentage probabilityBelowTarget,
    required Percentage probabilityAtOrAboveTarget,
    required Money expectedShortfall,
  }) {
    final currency = input.targetRealAfterTaxFutureValue.currency;
    if (probabilityBelowTarget.isNegative ||
        probabilityAtOrAboveTarget.isNegative ||
        probabilityBelowTarget.percent + probabilityAtOrAboveTarget.percent !=
            Percentage.fromPercent('100').percent) {
      throw ArgumentError('Downside probabilities must total exactly 100%.');
    }
    if (expectedShortfall.currency != currency ||
        expectedShortfall.isNegative) {
      throw ArgumentError(
        'Expected shortfall must be non-negative and use ${currency.code}.',
      );
    }
    return WeightedDownsideAnalysisResult._(
      input: input,
      probabilityBelowTarget: probabilityBelowTarget,
      probabilityAtOrAboveTarget: probabilityAtOrAboveTarget,
      expectedShortfall: expectedShortfall,
    );
  }

  const WeightedDownsideAnalysisResult._({
    required this.input,
    required this.probabilityBelowTarget,
    required this.probabilityAtOrAboveTarget,
    required this.expectedShortfall,
  });

  final WeightedDownsideAnalysisInput input;
  final Percentage probabilityBelowTarget;
  final Percentage probabilityAtOrAboveTarget;

  /// Unconditional probability-weighted shortfall across all cases.
  final Money expectedShortfall;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightedDownsideAnalysisResult &&
          input == other.input &&
          probabilityBelowTarget == other.probabilityBelowTarget &&
          probabilityAtOrAboveTarget == other.probabilityAtOrAboveTarget &&
          expectedShortfall == other.expectedShortfall;

  @override
  int get hashCode => Object.hash(
    input,
    probabilityBelowTarget,
    probabilityAtOrAboveTarget,
    expectedShortfall,
  );

  @override
  String toString() =>
      'WeightedDownsideAnalysisResult('
      'probabilityBelowTarget: $probabilityBelowTarget, '
      'probabilityAtOrAboveTarget: $probabilityAtOrAboveTarget, '
      'expectedShortfall: $expectedShortfall)';
}
