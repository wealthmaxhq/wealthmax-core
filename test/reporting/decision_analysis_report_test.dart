import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 22, 12);

  DecisionAnalysisCaseInput reportCase({
    required String id,
    required String label,
    required String investmentReturn,
    Currency currency = Currencies.inr,
  }) {
    final strategy = HybridStrategyInput(
      loan: LoanInput(
        principal: Money.parse('10000', currency: currency),
        annualInterestRate: Percentage.fromPercent('10'),
        tenureMonths: 12,
      ),
      extraCash: Money.parse('1000', currency: currency),
      decisionInstallment: 1,
      grossAnnualInvestmentReturn: Percentage.fromPercent(investmentReturn),
      annualExpenseRatio: Percentage.fromPercent('1'),
      allocationStepPercent: 50,
    );
    return DecisionAnalysisCaseInput(
      id: id,
      label: label,
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

  DecisionAnalysisReportInput input() => DecisionAnalysisReportInput(
    title: 'Return assumption comparison',
    cases: <DecisionAnalysisCaseInput>[
      reportCase(id: 'base', label: 'Base case', investmentReturn: '10'),
      reportCase(id: 'upside', label: 'Upside case', investmentReturn: '20'),
    ],
  );

  late CalculationResult<DecisionAnalysisReportResult> calculation;

  setUpAll(() {
    calculation = const DecisionAnalysisReportCalculator().calculate(
      input(),
      calculatedAt: calculatedAt,
    );
  });

  group('DecisionAnalysisReportInput', () {
    test('normalizes names and supports value semantics', () {
      final value = DecisionAnalysisReportInput(
        title: '  Report  ',
        cases: <DecisionAnalysisCaseInput>[
          reportCase(id: ' base ', label: ' Base ', investmentReturn: '10'),
        ],
      );
      final same = value.copyWith();

      expect(value.title, 'Report');
      expect(value.cases.single.id, 'base');
      expect(value.cases.single.label, 'Base');
      expect(same, value);
      expect(same.hashCode, value.hashCode);
      expect(value.toString(), contains('Report'));
    });

    test('rejects empty names, cases, duplicate ids, and mixed currencies', () {
      expect(
        () => DecisionAnalysisCaseInput(
          id: ' ',
          label: 'Case',
          analysis: reportCase(
            id: 'valid',
            label: 'Valid',
            investmentReturn: '10',
          ).analysis,
        ),
        throwsArgumentError,
      );
      expect(
        () => DecisionAnalysisReportInput(
          title: ' ',
          cases: <DecisionAnalysisCaseInput>[],
        ),
        throwsArgumentError,
      );
      final base = reportCase(
        id: 'base',
        label: 'Base',
        investmentReturn: '10',
      );
      expect(
        () => DecisionAnalysisReportInput(
          title: 'Duplicate',
          cases: <DecisionAnalysisCaseInput>[base, base],
        ),
        throwsArgumentError,
      );
      expect(
        () => DecisionAnalysisReportInput(
          title: 'Mixed',
          cases: <DecisionAnalysisCaseInput>[
            base,
            reportCase(
              id: 'usd',
              label: 'USD',
              investmentReturn: '20',
              currency: Currencies.usd,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('DecisionAnalysisReportCalculator', () {
    test('retains every case result and calculation provenance', () {
      final result = calculation.value;

      expect(result.cases, hasLength(2));
      expect(result.caseById('base').label, 'Base case');
      expect(
        result.cases.map(
          (reportCase) => reportCase.calculation.metadata.formulaId,
        ),
        everyElement(AdjustedDecisionAnalysisCalculator.formulaId),
      );
      expect(
        result.cases.map((reportCase) => reportCase.calculation.warningCount),
        everyElement(greaterThan(0)),
      );
    });

    test('aggregates selected real-value bounds and range', () {
      final result = calculation.value;
      final minimum = result.minimumSelectedValueCase;
      final maximum = result.maximumSelectedValueCase;

      expect(
        minimum.selectedRealAfterTaxFutureValue.compareTo(
          maximum.selectedRealAfterTaxFutureValue,
        ),
        lessThanOrEqualTo(0),
      );
      expect(
        result.selectedRealValueRange,
        maximum.selectedRealAfterTaxFutureValue -
            minimum.selectedRealAfterTaxFutureValue,
      );
      expect(result.selectedRealValueRange.isNegative, isFalse);
    });

    test('publishes REP-001 assumptions, case details, and cautions', () {
      expect(calculation.metadata.formulaId, 'REP-001');
      expect(calculation.metadata.inputs['caseCount'], 2);
      expect(calculation.metadata.assumptions['probabilityWeighted'], isFalse);
      expect(
        calculation.metadata.assumptions['caseCalculationProvenanceRetained'],
        isTrue,
      );
      expect(calculation.metadata.details['cases'], isA<List<Object?>>());
      expect(
        calculation.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'REP-001-CASES-NOT-PROBABILITIES',
          'REP-001-CROSS-CASE-RANGE',
        ]),
      );
    });

    test('supports deterministic equality, hashing, and output', () {
      final second = const DecisionAnalysisReportCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(second, calculation);
      expect(second.hashCode, calculation.hashCode);
      expect(calculation.value.toString(), contains('caseCount: 2'));
      expect(calculation.value.cases.first.toString(), contains('base'));
    });

    test('result rejects duplicate evaluated ids', () {
      final first = calculation.value.cases.first;

      expect(
        () => DecisionAnalysisReportResult(
          title: 'Invalid',
          cases: <DecisionAnalysisReportCase>[first, first],
        ),
        throwsArgumentError,
      );
    });
  });
}
