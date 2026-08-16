import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'weighted_decision_analysis_calculator.dart';
import 'weighted_downside_analysis_input.dart';
import 'weighted_downside_analysis_result.dart';

/// Measures target shortfall across a REP-003 probability distribution.
///
/// Formula `REP-005` classifies each case using its selected real after-tax
/// future value. Expected shortfall is the sum of each positive target gap
/// multiplied by its exact probability, rounded only after summation.
@immutable
final class WeightedDownsideAnalysisCalculator {
  const WeightedDownsideAnalysisCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
  });

  static const String formulaId = 'REP-005';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;

  CalculationResult<WeightedDownsideAnalysisResult> calculate(
    WeightedDownsideAnalysisInput input, {
    required DateTime calculatedAt,
  }) {
    final weighted = input.analysis;
    final target = input.targetRealAfterTaxFutureValue;
    var belowTargetPercent = Decimal.zero;
    var rawExpectedShortfall = Decimal.zero;

    for (final reportCase in weighted.value.report.value.cases) {
      final probability = weighted.value.weights
          .firstWhere((weight) => weight.caseId == reportCase.id)
          .probability;
      final realValue =
          reportCase.analysis.selectedScenario.realAfterTaxFutureValue;
      if (realValue.compareTo(target) < 0) {
        belowTargetPercent += probability.percent;
        rawExpectedShortfall +=
            (target.amount - realValue.amount) * probability.fraction;
      }
    }

    final belowTarget = Percentage.fromPercent(belowTargetPercent.toString());
    final atOrAboveTarget = Percentage.fromPercent(
      (Decimal.fromInt(100) - belowTargetPercent).toString(),
    );
    final expectedShortfall = Money(
      amount: roundingPolicy.round(
        rawExpectedShortfall,
        decimalPlaces: target.currency.decimalPlaces,
      ),
      currency: target.currency,
    );
    final result = WeightedDownsideAnalysisResult(
      input: input,
      probabilityBelowTarget: belowTarget,
      probabilityAtOrAboveTarget: atOrAboveTarget,
      expectedShortfall: expectedShortfall,
    );
    final warningsByCode = <String, CalculationWarning>{
      for (final warning in weighted.warnings) warning.code: warning,
      'REP-005-TARGET-USER-SUPPLIED': const CalculationWarning(
        code: 'REP-005-TARGET-USER-SUPPLIED',
        message:
            'The target value is user-supplied and should reflect the '
            'decision purpose and time horizon.',
        severity: WarningSeverity.caution,
      ),
      'REP-005-DOWNSIDE-NOT-FORECAST': const CalculationWarning(
        code: 'REP-005-DOWNSIDE-NOT-FORECAST',
        message:
            'Downside probabilities and expected shortfall reflect only the '
            'supplied scenarios and probabilities; they are not forecasts.',
        severity: WarningSeverity.caution,
      ),
    };

    return CalculationResult<WeightedDownsideAnalysisResult>(
      value: result,
      warnings: warningsByCode.values,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'sourceFormulaId': weighted.metadata.formulaId,
          'sourceFormulaVersion': weighted.metadata.formulaVersion,
          'targetRealAfterTaxFutureValue': target.amount.toString(),
          'currency': target.currency.code,
        },
        assumptions: <String, Object?>{
          'targetUserSupplied': true,
          'strictlyBelowTargetIsShortfall': true,
          'financialValuesRecalculated': false,
          'probabilitiesInheritedFrom':
              WeightedDecisionAnalysisCalculator.formulaId,
          'roundingTiming': 'afterWeightedSummation',
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'probabilityBelowTargetPercent': belowTarget.percent.toString(),
          'probabilityAtOrAboveTargetPercent': atOrAboveTarget.percent
              .toString(),
          'expectedShortfall': expectedShortfall.amount.toString(),
          'caseCount': weighted.value.weights.length,
        },
      ),
    );
  }
}
