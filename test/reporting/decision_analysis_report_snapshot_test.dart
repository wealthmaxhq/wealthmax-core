import 'dart:convert';

import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final reportCalculatedAt = DateTime.utc(2026, 8, 22, 12);
  final snapshotCalculatedAt = DateTime.utc(2026, 8, 22, 13);

  DecisionAnalysisReportInput input() {
    final strategy = HybridStrategyInput(
      loan: LoanInput(
        principal: Money.parse('10000', currency: Currencies.inr),
        annualInterestRate: Percentage.fromPercent('10'),
        tenureMonths: 12,
      ),
      extraCash: Money.parse('1000', currency: Currencies.inr),
      decisionInstallment: 1,
      grossAnnualInvestmentReturn: Percentage.fromPercent('20'),
      annualExpenseRatio: Percentage.fromPercent('1'),
      allocationStepPercent: 50,
    );
    return DecisionAnalysisReportInput(
      title: 'Portable report',
      cases: <DecisionAnalysisCaseInput>[
        DecisionAnalysisCaseInput(
          id: 'base',
          label: 'Base case',
          analysis: AdjustedDecisionAnalysisInput(
            analysis: CommonHorizonDecisionAnalysisInput(
              selection: CommonHorizonStrategySelectionInput(
                hybridStrategy: strategy,
                objective: CommonHorizonStrategyObjective.maximumFutureValue,
              ),
              grossAnnualReturnScenarios: <Percentage>[
                Percentage.fromPercent('0'),
                Percentage.fromPercent('20'),
                Percentage.fromPercent('30'),
              ],
            ),
            investmentGainTaxRate: Percentage.fromPercent('20'),
            annualInflationRate: Percentage.fromPercent('6'),
          ),
        ),
      ],
    );
  }

  late CalculationResult<DecisionAnalysisReportResult> report;
  late CalculationResult<DecisionAnalysisReportSnapshot> snapshot;

  setUpAll(() {
    report = const DecisionAnalysisReportCalculator().calculate(
      input(),
      calculatedAt: reportCalculatedAt,
    );
    snapshot = const DecisionAnalysisReportSnapshotCalculator().calculate(
      report,
      calculatedAt: snapshotCalculatedAt,
    );
  });

  group('DecisionAnalysisReportSnapshot', () {
    test('is directly JSON encodable with a versioned top-level contract', () {
      final decoded =
          jsonDecode(snapshot.value.encode()) as Map<String, Object?>;

      expect(decoded['schemaVersion'], 1);
      expect(decoded.keys, <String>[
        'schemaVersion',
        'snapshotFormula',
        'sourceReport',
        'summary',
        'cases',
        'warnings',
      ]);
      expect(jsonEncode(snapshot.value.toJson()), snapshot.value.encode());
    });

    test('defensively freezes source maps and nested collections', () {
      final cases = <Object?>[
        <String, Object?>{'id': 'base'},
      ];
      final source = <String, Object?>{'schemaVersion': 1, 'cases': cases};
      final value = DecisionAnalysisReportSnapshot(
        schemaVersion: 1,
        data: source,
      );
      cases.add(<String, Object?>{'id': 'changed'});
      source['extra'] = true;

      expect(value.toJson().containsKey('extra'), isFalse);
      expect(value.toJson()['cases'], hasLength(1));
      expect(() => value.toJson()['extra'] = true, throwsUnsupportedError);
      expect(
        () => (value.toJson()['cases']! as List<Object?>).add(null),
        throwsUnsupportedError,
      );
    });

    test('rejects invalid schema versions, mismatches, and unsafe values', () {
      expect(
        () => DecisionAnalysisReportSnapshot(
          schemaVersion: 0,
          data: const <String, Object?>{'schemaVersion': 0},
        ),
        throwsArgumentError,
      );
      expect(
        () => DecisionAnalysisReportSnapshot(
          schemaVersion: 1,
          data: const <String, Object?>{'schemaVersion': 2},
        ),
        throwsArgumentError,
      );
      expect(
        () => DecisionAnalysisReportSnapshot(
          schemaVersion: 1,
          data: <String, Object?>{
            'schemaVersion': 1,
            'unsafe': DateTime.utc(2026),
          },
        ),
        throwsArgumentError,
      );
    });
  });

  group('DecisionAnalysisReportSnapshotCalculator', () {
    test('preserves exact values, assumptions, warnings, and provenance', () {
      final data = snapshot.value.toJson();
      final source = data['sourceReport']! as Map<Object?, Object?>;
      final summary = data['summary']! as Map<Object?, Object?>;
      final cases = data['cases']! as List<Object?>;
      final reportCase = cases.single! as Map<Object?, Object?>;
      final selected = report.value.cases.single.analysis.selectedScenario;

      expect(source['formulaId'], DecisionAnalysisReportCalculator.formulaId);
      expect(source['title'], 'Portable report');
      expect(source['currency'], 'INR');
      expect(summary['minimumSelectedValueCaseId'], 'base');
      expect(
        reportCase['realAfterTaxFutureValue'],
        selected.realAfterTaxFutureValue.amount.toString(),
      );
      expect(reportCase['investmentGainTaxRatePercent'], '20');
      expect(reportCase['annualInflationRatePercent'], '6');
      expect(reportCase['warnings'], isNotEmpty);
      expect(snapshot.warnings, report.warnings);
    });

    test('publishes transparent REP-002 metadata', () {
      expect(snapshot.metadata.formulaId, 'REP-002');
      expect(snapshot.metadata.inputs['sourceFormulaId'], 'REP-001');
      expect(
        snapshot.metadata.assumptions['financialValuesRecalculated'],
        isFalse,
      );
      expect(
        snapshot.metadata.assumptions['exactDecimalsEncodedAsStrings'],
        isTrue,
      );
      expect(snapshot.metadata.details['schemaVersion'], 1);
      expect(snapshot.metadata.details['encodedLength'], greaterThan(0));
    });

    test('is deterministic and has value equality', () {
      final second = const DecisionAnalysisReportSnapshotCalculator().calculate(
        report,
        calculatedAt: snapshotCalculatedAt,
      );

      expect(second, snapshot);
      expect(second.hashCode, snapshot.hashCode);
      expect(second.value.toString(), contains('schemaVersion: 1'));
    });

    test('rejects a calculation without REP-001 provenance', () {
      final invalid = report.copyWith(
        metadata: report.metadata.copyWith(formulaId: 'OTHER'),
      );

      expect(
        () => const DecisionAnalysisReportSnapshotCalculator().calculate(
          invalid,
          calculatedAt: snapshotCalculatedAt,
        ),
        throwsArgumentError,
      );
    });
  });
}
