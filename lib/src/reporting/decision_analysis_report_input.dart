import 'dart:collection';

import 'package:meta/meta.dart';

import '../decision/adjusted_decision_analysis_input.dart';

/// One named case in a reusable decision-analysis report.
@immutable
final class DecisionAnalysisCaseInput {
  factory DecisionAnalysisCaseInput({
    required String id,
    required String label,
    required AdjustedDecisionAnalysisInput analysis,
  }) {
    final normalizedId = id.trim();
    final normalizedLabel = label.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Case id must not be empty.');
    }
    if (normalizedLabel.isEmpty) {
      throw ArgumentError.value(
        label,
        'label',
        'Case label must not be empty.',
      );
    }
    return DecisionAnalysisCaseInput._(
      id: normalizedId,
      label: normalizedLabel,
      analysis: analysis,
    );
  }

  const DecisionAnalysisCaseInput._({
    required this.id,
    required this.label,
    required this.analysis,
  });

  final String id;
  final String label;
  final AdjustedDecisionAnalysisInput analysis;

  DecisionAnalysisCaseInput copyWith({
    String? id,
    String? label,
    AdjustedDecisionAnalysisInput? analysis,
  }) => DecisionAnalysisCaseInput(
    id: id ?? this.id,
    label: label ?? this.label,
    analysis: analysis ?? this.analysis,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecisionAnalysisCaseInput &&
          id == other.id &&
          label == other.label &&
          analysis == other.analysis;

  @override
  int get hashCode => Object.hash(id, label, analysis);

  @override
  String toString() =>
      'DecisionAnalysisCaseInput(id: $id, label: $label, analysis: $analysis)';
}

/// Immutable named collection of comparable decision-analysis cases.
@immutable
final class DecisionAnalysisReportInput {
  factory DecisionAnalysisReportInput({
    required String title,
    required Iterable<DecisionAnalysisCaseInput> cases,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Report title must not be empty.',
      );
    }
    final snapshot = List<DecisionAnalysisCaseInput>.of(cases);
    if (snapshot.isEmpty) {
      throw ArgumentError.value(
        cases,
        'cases',
        'At least one case is required.',
      );
    }
    final ids = <String>{};
    final currency = snapshot
        .first
        .analysis
        .analysis
        .selection
        .hybridStrategy
        .loan
        .principal
        .currency;
    for (final reportCase in snapshot) {
      if (!ids.add(reportCase.id)) {
        throw ArgumentError.value(
          reportCase.id,
          'cases',
          'Case ids must be unique.',
        );
      }
      final caseCurrency = reportCase
          .analysis
          .analysis
          .selection
          .hybridStrategy
          .loan
          .principal
          .currency;
      if (caseCurrency != currency) {
        throw ArgumentError('All report cases must use ${currency.code}.');
      }
    }
    return DecisionAnalysisReportInput._(
      title: normalizedTitle,
      cases: UnmodifiableListView(snapshot),
    );
  }

  const DecisionAnalysisReportInput._({
    required this.title,
    required this.cases,
  });

  final String title;
  final List<DecisionAnalysisCaseInput> cases;

  DecisionAnalysisReportInput copyWith({
    String? title,
    Iterable<DecisionAnalysisCaseInput>? cases,
  }) => DecisionAnalysisReportInput(
    title: title ?? this.title,
    cases: cases ?? this.cases,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecisionAnalysisReportInput &&
          title == other.title &&
          _listsEqual(cases, other.cases);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(cases));

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'DecisionAnalysisReportInput(title: $title, cases: $cases)';
}
