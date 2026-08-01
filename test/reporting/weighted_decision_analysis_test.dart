import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final reportCalculatedAt = DateTime.utc(2026, 8, 23, 12);
  final weightedCalculatedAt = DateTime.utc(2026, 8, 23, 13);

  DecisionAnalysisCaseInput reportCase({
    required String id,
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

  late CalculationResult<DecisionAnalysisReportResult> report;
  late WeightedDecisionAnalysisInput input;
  late CalculationResult<WeightedDecisionAnalysisResult> calculation;

  setUpAll(() {
    report = const DecisionAnalysisReportCalculator().calculate(
      DecisionAnalysisReportInput(
        title: 'Weighted cases',
        cases: <DecisionAnalysisCaseInput>[
          reportCase(id: 'base', investmentReturn: '10'),
          reportCase(id: 'upside', investmentReturn: '20'),
        ],
      ),
      calculatedAt: reportCalculatedAt,
    );
    input = WeightedDecisionAnalysisInput(
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
    );
    calculation = const WeightedDecisionAnalysisCalculator().calculate(
      input,
      calculatedAt: weightedCalculatedAt,
    );
  });

  group('WeightedDecisionAnalysisInput', () {
    test('normalizes weights and supports value semantics', () {
      final weight = DecisionScenarioWeight(
        caseId: ' base ',
        probability: Percentage.fromPercent('60'),
      );
      final same = weight.copyWith();

      expect(weight.caseId, 'base');
      expect(same, weight);
      expect(same.hashCode, weight.hashCode);
      expect(weight.toString(), contains('60%'));
      expect(
        input.weightFor('upside').probability,
        Percentage.fromPercent('40'),
      );
      expect(input.toString(), contains('Weighted cases'));
    });

    test('rejects invalid probabilities and incomplete distributions', () {
      expect(
        () => DecisionScenarioWeight(
          caseId: 'base',
          probability: Percentage.fromPercent('-1'),
        ),
        throwsArgumentError,
      );
      expect(
        () => DecisionScenarioWeight(
          caseId: 'base',
          probability: Percentage.fromPercent('101'),
        ),
        throwsArgumentError,
      );
      expect(
        () => WeightedDecisionAnalysisInput(
          report: report,
          weights: <DecisionScenarioWeight>[
            DecisionScenarioWeight(
              caseId: 'base',
              probability: Percentage.fromPercent('100'),
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => WeightedDecisionAnalysisInput(
          report: report,
          weights: <DecisionScenarioWeight>[
            DecisionScenarioWeight(
              caseId: 'base',
              probability: Percentage.fromPercent('50'),
            ),
            DecisionScenarioWeight(
              caseId: 'upside',
              probability: Percentage.fromPercent('49.99'),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'accepts zero-probability cases when all cases remain represented',
      () {
        final value = WeightedDecisionAnalysisInput(
          report: report,
          weights: <DecisionScenarioWeight>[
            DecisionScenarioWeight(
              caseId: 'base',
              probability: Percentage.fromPercent('100'),
            ),
            DecisionScenarioWeight(
              caseId: 'upside',
              probability: Percentage.fromPercent('0'),
            ),
          ],
        );

        expect(value.weights, hasLength(2));
      },
    );
  });

  group('WeightedDecisionAnalysisCalculator', () {
    test('reconciles independently weighted selected monetary values', () {
      Decimal expected(Decimal Function(AdjustedDecisionScenario value) pick) {
        final base = pick(
          report.value.caseById('base').analysis.selectedScenario,
        );
        final upside = pick(
          report.value.caseById('upside').analysis.selectedScenario,
        );
        return base * Decimal.parse('0.6') + upside * Decimal.parse('0.4');
      }

      expect(
        calculation.value.expectedAfterTaxFutureValue.amount,
        RoundingPolicy.halfUp.round(
          expected((value) => value.afterTaxFutureValue.amount),
          decimalPlaces: 2,
        ),
      );
      expect(
        calculation.value.expectedRealAfterTaxFutureValue.amount,
        RoundingPolicy.halfUp.round(
          expected((value) => value.realAfterTaxFutureValue.amount),
          decimalPlaces: 2,
        ),
      );
      expect(
        calculation.value.expectedEstimatedTax.amount,
        RoundingPolicy.halfUp.round(
          expected((value) => value.estimatedTax.amount),
          decimalPlaces: 2,
        ),
      );
    });

    test('weights selected allocations and tax-driven changes', () {
      Decimal weightedAllocation = Decimal.zero;
      Decimal changedProbability = Decimal.zero;
      for (final reportCase in report.value.cases) {
        final probability = input.weightFor(reportCase.id).probability;
        weightedAllocation +=
            reportCase
                .analysis
                .selectedScenario
                .nominalScenario
                .requestedPrepaymentAllocation
                .percent *
            probability.fraction;
        if (reportCase.analysis.selectionChangedByTax) {
          changedProbability += probability.percent;
        }
      }

      expect(
        calculation.value.expectedPrepaymentAllocation.percent,
        weightedAllocation,
      );
      expect(
        calculation.value.probabilitySelectionChangedByTax.percent,
        changedProbability,
      );
    });

    test('honors final monetary rounding and preserves currency', () {
      final result = const WeightedDecisionAnalysisCalculator(
        roundingPolicy: RoundingPolicy.floor,
      ).calculate(input, calculatedAt: weightedCalculatedAt);

      expect(result.value.expectedAfterTaxFutureValue.currency, Currencies.inr);
      expect(result.metadata.assumptions['roundingPolicy'], 'floor');
    });

    test('publishes REP-003 metadata and explicit probability cautions', () {
      expect(calculation.metadata.formulaId, 'REP-003');
      expect(calculation.metadata.inputs['sourceFormulaId'], 'REP-001');
      expect(
        calculation.metadata.assumptions['probabilitiesUserSupplied'],
        isTrue,
      );
      expect(
        calculation.metadata.assumptions['aggregationMethod'],
        'probabilityWeightedArithmeticMean',
      );
      expect(
        calculation.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'REP-003-SUBJECTIVE-PROBABILITIES',
          'REP-003-EXPECTED-VALUE-NOT-FORECAST',
        ]),
      );
    });

    test('supports deterministic equality, hashing, and output', () {
      final second = const WeightedDecisionAnalysisCalculator().calculate(
        input,
        calculatedAt: weightedCalculatedAt,
      );

      expect(second, calculation);
      expect(second.hashCode, calculation.hashCode);
      expect(second.value.toString(), contains('expectedAfterTaxFutureValue'));
    });
  });
}
