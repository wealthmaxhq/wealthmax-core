import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final reportCalculatedAt = DateTime.utc(2026, 8, 25, 12);
  final weightedCalculatedAt = DateTime.utc(2026, 8, 25, 13);
  final downsideCalculatedAt = DateTime.utc(2026, 8, 25, 14);

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
  late Money target;
  late String lowerCaseId;
  late Percentage lowerCaseProbability;
  late WeightedDownsideAnalysisInput input;
  late CalculationResult<WeightedDownsideAnalysisResult> calculation;

  setUpAll(() {
    final report = const DecisionAnalysisReportCalculator().calculate(
      DecisionAnalysisReportInput(
        title: 'Downside cases',
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
    final first = report.value.cases.first;
    final second = report.value.cases.last;
    final firstValue = first.analysis.selectedScenario.realAfterTaxFutureValue;
    final secondValue =
        second.analysis.selectedScenario.realAfterTaxFutureValue;
    final lower = firstValue.compareTo(secondValue) < 0 ? first : second;
    final lowerValue = lower.analysis.selectedScenario.realAfterTaxFutureValue;
    lowerCaseId = lower.id;
    lowerCaseProbability = weighted.value.weights
        .firstWhere((weight) => weight.caseId == lowerCaseId)
        .probability;
    target = Money(
      amount: lowerValue.amount + Decimal.one,
      currency: lowerValue.currency,
    );
    input = WeightedDownsideAnalysisInput(
      analysis: weighted,
      targetRealAfterTaxFutureValue: target,
    );
    calculation = const WeightedDownsideAnalysisCalculator().calculate(
      input,
      calculatedAt: downsideCalculatedAt,
    );
  });

  group('WeightedDownsideAnalysisInput', () {
    test('supports validation, copyWith, equality, and output', () {
      final copy = input.copyWith();

      expect(copy, input);
      expect(copy.hashCode, input.hashCode);
      expect(copy.toString(), contains(target.toString()));
      expect(
        () => WeightedDownsideAnalysisInput(
          analysis: weighted,
          targetRealAfterTaxFutureValue: Money.parse(
            '-1',
            currency: Currencies.inr,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => WeightedDownsideAnalysisInput(
          analysis: weighted,
          targetRealAfterTaxFutureValue: Money.parse(
            '1',
            currency: Currencies.usd,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a calculation without REP-003 provenance', () {
      final invalid = weighted.copyWith(
        metadata: weighted.metadata.copyWith(formulaId: 'OTHER'),
      );

      expect(
        () => WeightedDownsideAnalysisInput(
          analysis: invalid,
          targetRealAfterTaxFutureValue: target,
        ),
        throwsArgumentError,
      );
    });
  });

  group('WeightedDownsideAnalysisCalculator', () {
    test('calculates exact downside probability and weighted shortfall', () {
      expect(calculation.value.probabilityBelowTarget, lowerCaseProbability);
      expect(
        calculation.value.probabilityAtOrAboveTarget.percent,
        Decimal.fromInt(100) - lowerCaseProbability.percent,
      );
      expect(
        calculation.value.expectedShortfall,
        Money(amount: lowerCaseProbability.fraction, currency: Currencies.inr),
      );
      expect(calculation.value.toString(), contains('expectedShortfall'));
    });

    test('treats equality as meeting the target', () {
      final lowerValue = weighted.value.report.value
          .caseById(lowerCaseId)
          .analysis
          .selectedScenario
          .realAfterTaxFutureValue;
      final result = const WeightedDownsideAnalysisCalculator().calculate(
        input.copyWith(targetRealAfterTaxFutureValue: lowerValue),
        calculatedAt: downsideCalculatedAt,
      );

      expect(result.value.probabilityBelowTarget.percent, Decimal.zero);
      expect(result.value.expectedShortfall, Money.zero(Currencies.inr));
    });

    test('returns zero downside for a zero target', () {
      final result = const WeightedDownsideAnalysisCalculator().calculate(
        input.copyWith(
          targetRealAfterTaxFutureValue: Money.zero(Currencies.inr),
        ),
        calculatedAt: downsideCalculatedAt,
      );

      expect(result.value.probabilityBelowTarget, Percentage.fromPercent('0'));
      expect(
        result.value.probabilityAtOrAboveTarget,
        Percentage.fromPercent('100'),
      );
      expect(result.value.expectedShortfall, Money.zero(Currencies.inr));
    });

    test('publishes REP-005 metadata, cautions, and source provenance', () {
      expect(calculation.metadata.formulaId, 'REP-005');
      expect(calculation.metadata.inputs['sourceFormulaId'], 'REP-003');
      expect(
        calculation.metadata.inputs['targetRealAfterTaxFutureValue'],
        target.amount.toString(),
      );
      expect(
        calculation.metadata.assumptions['financialValuesRecalculated'],
        isFalse,
      );
      expect(
        calculation.metadata.assumptions['binaryFloatingPointUsed'],
        isFalse,
      );
      expect(
        calculation.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'REP-003-SUBJECTIVE-PROBABILITIES',
          'REP-005-TARGET-USER-SUPPLIED',
          'REP-005-DOWNSIDE-NOT-FORECAST',
        ]),
      );
    });

    test('is deterministic and supports result value semantics', () {
      final second = const WeightedDownsideAnalysisCalculator().calculate(
        input,
        calculatedAt: downsideCalculatedAt,
      );

      expect(second, calculation);
      expect(second.hashCode, calculation.hashCode);
    });
  });
}
