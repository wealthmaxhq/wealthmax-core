import 'dart:collection';

import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../decision/adjusted_decision_analysis_result.dart';
import '../money/money.dart';

/// One evaluated case with its full calculation provenance intact.
@immutable
final class DecisionAnalysisReportCase {
  factory DecisionAnalysisReportCase({
    required String id,
    required String label,
    required CalculationResult<AdjustedDecisionAnalysisResult> calculation,
  }) {
    final normalizedId = id.trim();
    final normalizedLabel = label.trim();
    if (normalizedId.isEmpty || normalizedLabel.isEmpty) {
      throw ArgumentError('Evaluated case id and label must not be empty.');
    }
    return DecisionAnalysisReportCase._(
      id: normalizedId,
      label: normalizedLabel,
      calculation: calculation,
    );
  }

  const DecisionAnalysisReportCase._({
    required this.id,
    required this.label,
    required this.calculation,
  });

  final String id;
  final String label;
  final CalculationResult<AdjustedDecisionAnalysisResult> calculation;

  AdjustedDecisionAnalysisResult get analysis => calculation.value;
  Money get selectedRealAfterTaxFutureValue =>
      analysis.selectedScenario.realAfterTaxFutureValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecisionAnalysisReportCase &&
          id == other.id &&
          label == other.label &&
          calculation == other.calculation;

  @override
  int get hashCode => Object.hash(id, label, calculation);

  @override
  String toString() =>
      'DecisionAnalysisReportCase(id: $id, label: $label, '
      'selectedRealAfterTaxFutureValue: $selectedRealAfterTaxFutureValue)';
}

/// Aggregated report summary across named, same-currency cases.
@immutable
final class DecisionAnalysisReportResult {
  factory DecisionAnalysisReportResult({
    required String title,
    required Iterable<DecisionAnalysisReportCase> cases,
  }) {
    final snapshot = List<DecisionAnalysisReportCase>.of(cases);
    if (snapshot.isEmpty) {
      throw ArgumentError('At least one evaluated case is required.');
    }
    final currency = snapshot.first.selectedRealAfterTaxFutureValue.currency;
    final ids = <String>{};
    for (final reportCase in snapshot) {
      if (!ids.add(reportCase.id)) {
        throw ArgumentError('Evaluated case ids must be unique.');
      }
      if (reportCase.selectedRealAfterTaxFutureValue.currency != currency) {
        throw ArgumentError('All evaluated cases must use ${currency.code}.');
      }
    }
    var minimumIndex = 0;
    var maximumIndex = 0;
    for (var index = 1; index < snapshot.length; index++) {
      final value = snapshot[index].selectedRealAfterTaxFutureValue;
      if (value.compareTo(
            snapshot[minimumIndex].selectedRealAfterTaxFutureValue,
          ) <
          0) {
        minimumIndex = index;
      }
      if (value.compareTo(
            snapshot[maximumIndex].selectedRealAfterTaxFutureValue,
          ) >
          0) {
        maximumIndex = index;
      }
    }
    return DecisionAnalysisReportResult._(
      title: title,
      cases: UnmodifiableListView(snapshot),
      minimumSelectedValueCaseIndex: minimumIndex,
      maximumSelectedValueCaseIndex: maximumIndex,
    );
  }

  const DecisionAnalysisReportResult._({
    required this.title,
    required this.cases,
    required this.minimumSelectedValueCaseIndex,
    required this.maximumSelectedValueCaseIndex,
  });

  final String title;
  final List<DecisionAnalysisReportCase> cases;
  final int minimumSelectedValueCaseIndex;
  final int maximumSelectedValueCaseIndex;

  DecisionAnalysisReportCase get minimumSelectedValueCase =>
      cases[minimumSelectedValueCaseIndex];
  DecisionAnalysisReportCase get maximumSelectedValueCase =>
      cases[maximumSelectedValueCaseIndex];
  Money get selectedRealValueRange =>
      maximumSelectedValueCase.selectedRealAfterTaxFutureValue -
      minimumSelectedValueCase.selectedRealAfterTaxFutureValue;
  int get taxChangedSelectionCount => cases
      .where((reportCase) => reportCase.analysis.selectionChangedByTax)
      .length;
  int get criticalWarningCaseCount => cases
      .where((reportCase) => reportCase.calculation.hasCriticalWarnings)
      .length;

  DecisionAnalysisReportCase caseById(String id) =>
      cases.firstWhere((reportCase) => reportCase.id == id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecisionAnalysisReportResult &&
          title == other.title &&
          _listsEqual(cases, other.cases) &&
          minimumSelectedValueCaseIndex ==
              other.minimumSelectedValueCaseIndex &&
          maximumSelectedValueCaseIndex == other.maximumSelectedValueCaseIndex;

  @override
  int get hashCode => Object.hash(
    title,
    Object.hashAll(cases),
    minimumSelectedValueCaseIndex,
    maximumSelectedValueCaseIndex,
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
      'DecisionAnalysisReportResult(title: $title, caseCount: ${cases.length}, '
      'minimumCase: ${minimumSelectedValueCase.id}, '
      'maximumCase: ${maximumSelectedValueCase.id}, '
      'selectedRealValueRange: $selectedRealValueRange, '
      'taxChangedSelectionCount: $taxChangedSelectionCount)';
}
