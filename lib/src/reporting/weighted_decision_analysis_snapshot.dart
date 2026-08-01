import 'package:meta/meta.dart';

import 'decision_analysis_report_snapshot.dart';

/// Versioned, JSON-safe representation of a weighted decision analysis.
///
/// Exact decimal values are encoded as strings. The underlying immutable
/// snapshot contract also rejects values that cannot be encoded as JSON.
@immutable
final class WeightedDecisionAnalysisSnapshot {
  factory WeightedDecisionAnalysisSnapshot({
    required int schemaVersion,
    required Map<String, Object?> data,
  }) {
    final snapshot = DecisionAnalysisReportSnapshot(
      schemaVersion: schemaVersion,
      data: data,
    );
    return WeightedDecisionAnalysisSnapshot._(snapshot);
  }

  const WeightedDecisionAnalysisSnapshot._(this._snapshot);

  final DecisionAnalysisReportSnapshot _snapshot;

  int get schemaVersion => _snapshot.schemaVersion;
  Map<String, Object?> toJson() => _snapshot.toJson();
  String encode() => _snapshot.encode();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightedDecisionAnalysisSnapshot &&
          _snapshot == other._snapshot;

  @override
  int get hashCode => _snapshot.hashCode;

  @override
  String toString() =>
      'WeightedDecisionAnalysisSnapshot(schemaVersion: $schemaVersion, '
      'data: ${encode()})';
}
