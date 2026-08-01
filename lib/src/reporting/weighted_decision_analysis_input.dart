import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../percentage/percentage.dart';
import 'decision_analysis_report_calculator.dart';
import 'decision_analysis_report_result.dart';

/// Probability assigned to one named REP-001 case.
@immutable
final class DecisionScenarioWeight {
  factory DecisionScenarioWeight({
    required String caseId,
    required Percentage probability,
  }) {
    final normalizedId = caseId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(caseId, 'caseId', 'Case id must not be empty.');
    }
    if (probability.isNegative || probability.percent > Decimal.fromInt(100)) {
      throw ArgumentError.value(
        probability,
        'probability',
        'Probability must be between 0% and 100%.',
      );
    }
    return DecisionScenarioWeight._(
      caseId: normalizedId,
      probability: probability,
    );
  }

  const DecisionScenarioWeight._({
    required this.caseId,
    required this.probability,
  });

  final String caseId;
  final Percentage probability;

  DecisionScenarioWeight copyWith({String? caseId, Percentage? probability}) =>
      DecisionScenarioWeight(
        caseId: caseId ?? this.caseId,
        probability: probability ?? this.probability,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecisionScenarioWeight &&
          caseId == other.caseId &&
          probability == other.probability;

  @override
  int get hashCode => Object.hash(caseId, probability);

  @override
  String toString() =>
      'DecisionScenarioWeight(caseId: $caseId, probability: $probability)';
}

/// A complete probability distribution over one REP-001 report.
@immutable
final class WeightedDecisionAnalysisInput {
  factory WeightedDecisionAnalysisInput({
    required CalculationResult<DecisionAnalysisReportResult> report,
    required Iterable<DecisionScenarioWeight> weights,
  }) {
    if (report.metadata.formulaId !=
        DecisionAnalysisReportCalculator.formulaId) {
      throw ArgumentError.value(
        report.metadata.formulaId,
        'report',
        'Weighted aggregation requires a REP-001 calculation result.',
      );
    }
    final snapshot = List<DecisionScenarioWeight>.of(weights);
    if (snapshot.length != report.value.cases.length) {
      throw ArgumentError('Weights must cover every report case exactly once.');
    }
    final expectedIds = report.value.cases.map((value) => value.id).toSet();
    final actualIds = <String>{};
    var total = Decimal.zero;
    for (final weight in snapshot) {
      if (!actualIds.add(weight.caseId)) {
        throw ArgumentError('Scenario weight case ids must be unique.');
      }
      total += weight.probability.percent;
    }
    if (actualIds.length != expectedIds.length ||
        !actualIds.containsAll(expectedIds)) {
      throw ArgumentError(
        'Weight case ids must exactly match report case ids.',
      );
    }
    if (total != Decimal.fromInt(100)) {
      throw ArgumentError.value(
        total,
        'weights',
        'Scenario probabilities must sum exactly to 100%.',
      );
    }
    return WeightedDecisionAnalysisInput._(
      report: report,
      weights: UnmodifiableListView(snapshot),
    );
  }

  const WeightedDecisionAnalysisInput._({
    required this.report,
    required this.weights,
  });

  final CalculationResult<DecisionAnalysisReportResult> report;
  final List<DecisionScenarioWeight> weights;

  DecisionScenarioWeight weightFor(String caseId) =>
      weights.firstWhere((weight) => weight.caseId == caseId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightedDecisionAnalysisInput &&
          report == other.report &&
          _listsEqual(weights, other.weights);

  @override
  int get hashCode => Object.hash(report, Object.hashAll(weights));

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'WeightedDecisionAnalysisInput(report: ${report.value.title}, '
      'weights: $weights)';
}
