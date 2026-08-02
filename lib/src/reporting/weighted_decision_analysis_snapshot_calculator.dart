import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import 'weighted_decision_analysis_calculator.dart';
import 'weighted_decision_analysis_result.dart';
import 'weighted_decision_analysis_snapshot.dart';

/// Converts REP-003 into a deterministic portable report contract.
///
/// Formula `REP-004` performs no financial calculation. It preserves the
/// weighted result, probability distribution, warnings, and source provenance
/// using exact decimal strings suitable for storage and APIs.
@immutable
final class WeightedDecisionAnalysisSnapshotCalculator {
  const WeightedDecisionAnalysisSnapshotCalculator();

  static const String formulaId = 'REP-004';
  static const String formulaVersion = '1.0.0';
  static const int schemaVersion = 1;

  CalculationResult<WeightedDecisionAnalysisSnapshot> calculate(
    CalculationResult<WeightedDecisionAnalysisResult> analysis, {
    required DateTime calculatedAt,
  }) {
    if (analysis.metadata.formulaId !=
        WeightedDecisionAnalysisCalculator.formulaId) {
      throw ArgumentError.value(
        analysis.metadata.formulaId,
        'analysis',
        'Portable weighted snapshots require a REP-003 calculation result.',
      );
    }

    final value = analysis.value;
    final currency = value.expectedAfterTaxFutureValue.currency;
    final data = <String, Object?>{
      'schemaVersion': schemaVersion,
      'snapshotFormula': <String, Object?>{
        'id': formulaId,
        'version': formulaVersion,
        'calculatedAt': calculatedAt.toUtc().toIso8601String(),
      },
      'sourceAnalysis': <String, Object?>{
        'formulaId': analysis.metadata.formulaId,
        'formulaVersion': analysis.metadata.formulaVersion,
        'calculatedAt': analysis.metadata.calculatedAt
            .toUtc()
            .toIso8601String(),
        'sourceReportFormulaId': value.report.metadata.formulaId,
        'sourceReportFormulaVersion': value.report.metadata.formulaVersion,
        'title': value.report.value.title,
        'currency': currency.code,
        'caseCount': value.weights.length,
      },
      'summary': <String, Object?>{
        'expectedAfterTaxFutureValue': value.expectedAfterTaxFutureValue.amount
            .toString(),
        'expectedRealAfterTaxFutureValue': value
            .expectedRealAfterTaxFutureValue
            .amount
            .toString(),
        'expectedEstimatedTax': value.expectedEstimatedTax.amount.toString(),
        'expectedPrepaymentAllocationPercent': value
            .expectedPrepaymentAllocation
            .percent
            .toString(),
        'probabilitySelectionChangedByTaxPercent': value
            .probabilitySelectionChangedByTax
            .percent
            .toString(),
      },
      'weights': value.weights
          .map(
            (weight) => <String, Object?>{
              'caseId': weight.caseId,
              'probabilityPercent': weight.probability.percent.toString(),
            },
          )
          .toList(growable: false),
      'warnings': analysis.warnings
          .map(
            (warning) => <String, Object?>{
              'code': warning.code,
              'message': warning.message,
              'severity': warning.severity.name,
            },
          )
          .toList(growable: false),
    };
    final snapshot = WeightedDecisionAnalysisSnapshot(
      schemaVersion: schemaVersion,
      data: data,
    );

    return CalculationResult<WeightedDecisionAnalysisSnapshot>(
      value: snapshot,
      warnings: analysis.warnings,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'sourceFormulaId': analysis.metadata.formulaId,
          'sourceFormulaVersion': analysis.metadata.formulaVersion,
          'sourceCalculatedAt': analysis.metadata.calculatedAt
              .toUtc()
              .toIso8601String(),
          'caseCount': value.weights.length,
          'currency': currency.code,
        },
        assumptions: const <String, Object?>{
          'financialValuesRecalculated': false,
          'exactDecimalsEncodedAsStrings': true,
          'jsonSafeValuesOnly': true,
          'schemaVersioned': true,
          'sourceWarningsPreserved': true,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'schemaVersion': schemaVersion,
          'topLevelKeys': data.keys.toList(growable: false),
          'encodedLength': snapshot.encode().length,
        },
      ),
    );
  }
}
