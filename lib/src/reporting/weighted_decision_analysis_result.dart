import 'dart:collection';

import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import 'decision_analysis_report_result.dart';
import 'weighted_decision_analysis_input.dart';

/// Probability-weighted summary of selected values across REP-001 cases.
@immutable
final class WeightedDecisionAnalysisResult {
  factory WeightedDecisionAnalysisResult({
    required CalculationResult<DecisionAnalysisReportResult> report,
    required Iterable<DecisionScenarioWeight> weights,
    required Money expectedAfterTaxFutureValue,
    required Money expectedRealAfterTaxFutureValue,
    required Money expectedEstimatedTax,
    required Percentage expectedPrepaymentAllocation,
    required Percentage probabilitySelectionChangedByTax,
  }) {
    final snapshot = List<DecisionScenarioWeight>.of(weights);
    WeightedDecisionAnalysisInput(report: report, weights: snapshot);
    final currency = report.value.selectedRealValueRange.currency;
    for (final value in <Money>[
      expectedAfterTaxFutureValue,
      expectedRealAfterTaxFutureValue,
      expectedEstimatedTax,
    ]) {
      if (value.currency != currency || value.isNegative) {
        throw ArgumentError(
          'Expected monetary values must be non-negative and use ${currency.code}.',
        );
      }
    }
    for (final value in <Percentage>[
      expectedPrepaymentAllocation,
      probabilitySelectionChangedByTax,
    ]) {
      if (value.isNegative || value.percent.compareTo(_oneHundred) > 0) {
        throw ArgumentError(
          'Expected percentages must be between 0% and 100%.',
        );
      }
    }
    return WeightedDecisionAnalysisResult._(
      report: report,
      weights: UnmodifiableListView(snapshot),
      expectedAfterTaxFutureValue: expectedAfterTaxFutureValue,
      expectedRealAfterTaxFutureValue: expectedRealAfterTaxFutureValue,
      expectedEstimatedTax: expectedEstimatedTax,
      expectedPrepaymentAllocation: expectedPrepaymentAllocation,
      probabilitySelectionChangedByTax: probabilitySelectionChangedByTax,
    );
  }

  const WeightedDecisionAnalysisResult._({
    required this.report,
    required this.weights,
    required this.expectedAfterTaxFutureValue,
    required this.expectedRealAfterTaxFutureValue,
    required this.expectedEstimatedTax,
    required this.expectedPrepaymentAllocation,
    required this.probabilitySelectionChangedByTax,
  });

  final CalculationResult<DecisionAnalysisReportResult> report;
  final List<DecisionScenarioWeight> weights;
  final Money expectedAfterTaxFutureValue;
  final Money expectedRealAfterTaxFutureValue;
  final Money expectedEstimatedTax;
  final Percentage expectedPrepaymentAllocation;
  final Percentage probabilitySelectionChangedByTax;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightedDecisionAnalysisResult &&
          report == other.report &&
          _listsEqual(weights, other.weights) &&
          expectedAfterTaxFutureValue == other.expectedAfterTaxFutureValue &&
          expectedRealAfterTaxFutureValue ==
              other.expectedRealAfterTaxFutureValue &&
          expectedEstimatedTax == other.expectedEstimatedTax &&
          expectedPrepaymentAllocation == other.expectedPrepaymentAllocation &&
          probabilitySelectionChangedByTax ==
              other.probabilitySelectionChangedByTax;

  @override
  int get hashCode => Object.hash(
    report,
    Object.hashAll(weights),
    expectedAfterTaxFutureValue,
    expectedRealAfterTaxFutureValue,
    expectedEstimatedTax,
    expectedPrepaymentAllocation,
    probabilitySelectionChangedByTax,
  );

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'WeightedDecisionAnalysisResult('
      'expectedAfterTaxFutureValue: $expectedAfterTaxFutureValue, '
      'expectedRealAfterTaxFutureValue: $expectedRealAfterTaxFutureValue, '
      'expectedEstimatedTax: $expectedEstimatedTax, '
      'expectedPrepaymentAllocation: $expectedPrepaymentAllocation, '
      'probabilitySelectionChangedByTax: '
      '$probabilitySelectionChangedByTax)';
}

final _oneHundred = Percentage.fromPercent('100').percent;
