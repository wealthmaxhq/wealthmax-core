import 'dart:convert';

import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final reportCalculatedAt = DateTime.utc(2026, 8, 24, 12);
  final weightedCalculatedAt = DateTime.utc(2026, 8, 24, 13);
  final snapshotCalculatedAt = DateTime.utc(2026, 8, 24, 14);

  DecisionAnalysisCaseInput reportCase(String id, String investmentReturn) {
    final strategy = HybridStrategyInput(
      loan: LoanInput(
        principal: Money.parse('10000', currency: Currencies.inr),
        annualInterestRate: Percentage.fromPercent('10'),
        tenureMonths: 12,
      ),
      extraCash: Money.parse('1000', currency: Currencies.inr),
      decisionInstallment: 1,
      grossAnnualInvestmentReturn: Percentage.fromPercent(investmentReturn),
      annualExpenseRatio: Percentage.fromPercent('1'),
      allocationStepPercent: 50,
    );
    return DecisionAnalysisCaseInput(
      id: id,
      label: '$id case',
      analysis: AdjustedDecisionAnalysisInput(
        analysis: CommonHorizonDecisionAnalysisInput(
          selection: CommonHorizonStrategySelectionInput(
            hybridStrategy: strategy,
            objective: CommonHorizonStrategyObjective.maximumFutureValue,
          ),
          grossAnnualReturnScenarios: <Percentage>[
            Percentage.fromPercent('0'),
            Percentage.fromPercent(investmentReturn),
            Percentage.fromPercent('30'),
          ],
        ),
        investmentGainTaxRate: Percentage.fromPercent('20'),
        annualInflationRate: Percentage.fromPercent('6'),
      ),
    );
  }

  late CalculationResult<WeightedDecisionAnalysisResult> weighted;
  late CalculationResult<WeightedDecisionAnalysisSnapshot> snapshot;

  setUpAll(() {
    final report = const DecisionAnalysisReportCalculator().calculate(
      DecisionAnalysisReportInput(
        title: 'Portable weighted cases',
        cases: <DecisionAnalysisCaseInput>[
          reportCase('base', '10'),
          reportCase('upside', '20'),
        ],
      ),
      calculatedAt: reportCalculatedAt,
    );
    weighted = const WeightedDecisionAnalysisCalculator().calculate(
      WeightedDecisionAnalysisInput(
        report: report,
        weights: <DecisionScenarioWeight>[
          DecisionScenarioWeight(
            caseId: 'base',
            probability: Percentage.fromPercent('60'),
          ),
          DecisionScenarioWeight(
            caseId: 'upside',
            probability: Percentage.fromPercent('40'),
          ),
        ],
      ),
      calculatedAt: weightedCalculatedAt,
    );
    snapshot = const WeightedDecisionAnalysisSnapshotCalculator().calculate(
      weighted,
      calculatedAt: snapshotCalculatedAt,
    );
  });

  group('WeightedDecisionAnalysisSnapshot', () {
    test('is immutable, JSON-safe, and versioned', () {
      final decoded = jsonDecode(snapshot.value.encode()) as Map<String, Object?>;

      expect(decoded['schemaVersion'], 1);
      expect(decoded.keys, <String>[
        'schemaVersion',
        'snapshotFormula',
        'sourceAnalysis',
        'summary',
        'weights',
        'warnings',
      ]);
      expect(jsonEncode(snapshot.value.toJson()), snapshot.value.encode());
      expect(() => snapshot.value.toJson()['extra'] = true, throwsUnsupportedError);
    });

    test('rejects invalid schema versions and JSON-unsafe values', () {
      expect(
        () => WeightedDecisionAnalysisSnapshot(
          schemaVersion: 0,
          data: const <String, Object?>{'schemaVersion': 0},
        ),
        throwsArgumentError,
      );
      expect(
        () => WeightedDecisionAnalysisSnapshot(
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

  group('WeightedDecisionAnalysisSnapshotCalculator', () {
    test('preserves exact summary values, weights, and provenance', () {
      final data = snapshot.value.toJson();
      final source = data['sourceAnalysis']! as Map<Object?, Object?>;
      final summary = data['summary']! as Map<Object?, Object?>;
      final weights = data['weights']! as List<Object?>;

      expect(source['formulaId'], 'REP-003');
      expect(source['sourceReportFormulaId'], 'REP-001');
      expect(source['title'], 'Portable weighted cases');
      expect(source['currency'], 'INR');
      expect(
        summary['expectedRealAfterTaxFutureValue'],
        weighted.value.expectedRealAfterTaxFutureValue.amount.toString(),
      );
      expect(summary['expectedPrepaymentAllocationPercent'], weighted.value.expectedPrepaymentAllocation.percent.toString());
      expect(weights, hasLength(2));
      expect((weights.first! as Map<Object?, Object?>)['probabilityPercent'], '60');
      expect(snapshot.warnings, weighted.warnings);
    });

    test('publishes transparent REP-004 metadata', () {
      expect(snapshot.metadata.formulaId, 'REP-004');
      expect(snapshot.metadata.inputs['sourceFormulaId'], 'REP-003');
      expect(snapshot.metadata.assumptions['financialValuesRecalculated'], isFalse);
      expect(snapshot.metadata.assumptions['exactDecimalsEncodedAsStrings'], isTrue);
      expect(snapshot.metadata.details['schemaVersion'], 1);
      expect(snapshot.metadata.details['encodedLength'], greaterThan(0));
    });

    test('is deterministic and has value equality', () {
      final second = const WeightedDecisionAnalysisSnapshotCalculator().calculate(
        weighted,
        calculatedAt: snapshotCalculatedAt,
      );

      expect(second, snapshot);
      expect(second.hashCode, snapshot.hashCode);
      expect(second.value.toString(), contains('schemaVersion: 1'));
    });

    test('rejects a calculation without REP-003 provenance', () {
      final invalid = weighted.copyWith(
        metadata: weighted.metadata.copyWith(formulaId: 'OTHER'),
      );

      expect(
        () => const WeightedDecisionAnalysisSnapshotCalculator().calculate(
          invalid,
          calculatedAt: snapshotCalculatedAt,
        ),
        throwsArgumentError,
      );
    });
  });
}
