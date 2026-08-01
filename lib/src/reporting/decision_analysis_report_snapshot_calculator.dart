import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import 'decision_analysis_report_calculator.dart';
import 'decision_analysis_report_result.dart';
import 'decision_analysis_report_snapshot.dart';

/// Converts REP-001 into a deterministic portable report contract.
///
/// Formula `REP-002` performs no new financial projection. It snapshots the
/// existing report with exact decimals encoded as strings and complete warning
/// and formula provenance for storage, APIs, and document generation.
@immutable
final class DecisionAnalysisReportSnapshotCalculator {
  const DecisionAnalysisReportSnapshotCalculator();

  static const String formulaId = 'REP-002';
  static const String formulaVersion = '1.0.0';
  static const int schemaVersion = 1;

  CalculationResult<DecisionAnalysisReportSnapshot> calculate(
    CalculationResult<DecisionAnalysisReportResult> report, {
    required DateTime calculatedAt,
  }) {
    if (report.metadata.formulaId !=
        DecisionAnalysisReportCalculator.formulaId) {
      throw ArgumentError.value(
        report.metadata.formulaId,
        'report',
        'Portable snapshots require a REP-001 calculation result.',
      );
    }
    final value = report.value;
    final currency = value.selectedRealValueRange.currency;
    final cases = value.cases.map(_caseSnapshot).toList(growable: false);
    final data = <String, Object?>{
      'schemaVersion': schemaVersion,
      'snapshotFormula': <String, Object?>{
        'id': formulaId,
        'version': formulaVersion,
        'calculatedAt': calculatedAt.toUtc().toIso8601String(),
      },
      'sourceReport': <String, Object?>{
        'formulaId': report.metadata.formulaId,
        'formulaVersion': report.metadata.formulaVersion,
        'calculatedAt': report.metadata.calculatedAt.toUtc().toIso8601String(),
        'title': value.title,
        'currency': currency.code,
        'caseCount': value.cases.length,
      },
      'summary': <String, Object?>{
        'minimumSelectedValueCaseId': value.minimumSelectedValueCase.id,
        'maximumSelectedValueCaseId': value.maximumSelectedValueCase.id,
        'selectedRealValueRange': value.selectedRealValueRange.amount
            .toString(),
        'taxChangedSelectionCount': value.taxChangedSelectionCount,
        'criticalWarningCaseCount': value.criticalWarningCaseCount,
      },
      'cases': cases,
      'warnings': report.warnings.map(_warningSnapshot).toList(growable: false),
    };
    final snapshot = DecisionAnalysisReportSnapshot(
      schemaVersion: schemaVersion,
      data: data,
    );

    return CalculationResult<DecisionAnalysisReportSnapshot>(
      value: snapshot,
      warnings: report.warnings,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'sourceFormulaId': report.metadata.formulaId,
          'sourceFormulaVersion': report.metadata.formulaVersion,
          'sourceCalculatedAt': report.metadata.calculatedAt
              .toUtc()
              .toIso8601String(),
          'caseCount': value.cases.length,
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

  Map<String, Object?> _caseSnapshot(DecisionAnalysisReportCase reportCase) {
    final analysis = reportCase.analysis;
    final selected = analysis.selectedScenario;
    final nominal = selected.nominalScenario;
    final allocation = nominal.allocation;
    final calculation = reportCase.calculation;
    return <String, Object?>{
      'id': reportCase.id,
      'label': reportCase.label,
      'objective': analysis.nominalAnalysis.selection.objective.name,
      'currency': selected.afterTaxFutureValue.currency.code,
      'selectedScenarioIndex': analysis.selectedScenarioIndex,
      'selectionChangedByTax': analysis.selectionChangedByTax,
      'selectedPrepaymentAllocationPercent': nominal
          .requestedPrepaymentAllocation
          .percent
          .toString(),
      'appliedPrepayment': allocation.appliedPrepayment.amount.toString(),
      'investedAmount': allocation.investedAmount.amount.toString(),
      'taxableInvestmentGain': selected.taxableInvestmentGain.amount.toString(),
      'estimatedTax': selected.estimatedTax.amount.toString(),
      'nominalFutureValue': nominal.totalFutureValue.amount.toString(),
      'afterTaxFutureValue': selected.afterTaxFutureValue.amount.toString(),
      'realAfterTaxFutureValue': selected.realAfterTaxFutureValue.amount
          .toString(),
      'investmentGainTaxRatePercent': analysis.investmentGainTaxRate.percent
          .toString(),
      'annualInflationRatePercent': analysis.annualInflationRate.percent
          .toString(),
      'calculation': <String, Object?>{
        'formulaId': calculation.metadata.formulaId,
        'formulaVersion': calculation.metadata.formulaVersion,
        'calculatedAt': calculation.metadata.calculatedAt
            .toUtc()
            .toIso8601String(),
      },
      'warnings': calculation.warnings
          .map(_warningSnapshot)
          .toList(growable: false),
    };
  }

  Map<String, Object?> _warningSnapshot(CalculationWarning warning) =>
      <String, Object?>{
        'code': warning.code,
        'message': warning.message,
        'severity': warning.severity.name,
      };
}
