import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 20, 12);

  AdjustedDecisionAnalysisInput input({
    String tax = '20',
    String inflation = '6',
    String investmentReturn = '20',
    Currency currency = Currencies.inr,
    CommonHorizonStrategyObjective objective =
        CommonHorizonStrategyObjective.maximumFutureValue,
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
      annualExpenseRatio: Percentage.fromPercent('0'),
      allocationStepPercent: 25,
    );
    return AdjustedDecisionAnalysisInput(
      analysis: CommonHorizonDecisionAnalysisInput(
        selection: CommonHorizonStrategySelectionInput(
          hybridStrategy: strategy,
          objective: objective,
        ),
        grossAnnualReturnScenarios: <Percentage>[
          Percentage.fromPercent('0'),
          Percentage.fromPercent(investmentReturn),
          Percentage.fromPercent('30'),
        ],
      ),
      investmentGainTaxRate: Percentage.fromPercent(tax),
      annualInflationRate: Percentage.fromPercent(inflation),
    );
  }

  group('AdjustedDecisionAnalysisInput', () {
    test('validates tax and inflation boundaries', () {
      expect(() => input(tax: '-0.01'), throwsArgumentError);
      expect(() => input(tax: '100.01'), throwsArgumentError);
      expect(() => input(inflation: '-100'), throwsArgumentError);
      expect(
        input(tax: '0', inflation: '-10'),
        isA<AdjustedDecisionAnalysisInput>(),
      );
      expect(input(tax: '100'), isA<AdjustedDecisionAnalysisInput>());
    });

    test('supports copyWith, equality, hashing, and output', () {
      final original = input();
      final changed = original.copyWith(
        annualInflationRate: Percentage.fromPercent('7'),
      );
      final expected = original.copyWith(
        annualInflationRate: Percentage.fromPercent('7'),
      );

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('annualInflationRate: 7%'));
    });
  });

  group('AdjustedDecisionAnalysisCalculator', () {
    test('zero tax and inflation preserve nominal future values', () {
      final result = const AdjustedDecisionAnalysisCalculator().calculate(
        input(tax: '0', inflation: '0'),
        calculatedAt: calculatedAt,
      );

      for (final scenario in result.value.scenarios) {
        expect(scenario.estimatedTax.isZero, isTrue);
        expect(
          scenario.afterTaxFutureValue,
          scenario.nominalScenario.totalFutureValue,
        );
        expect(scenario.realAfterTaxFutureValue, scenario.afterTaxFutureValue);
      }
      expect(result.value.selectionChangedByTax, isFalse);
    });

    test(
      'taxes positive gain after deducting all investment contributions',
      () {
        final result = const AdjustedDecisionAnalysisCalculator().calculate(
          input(tax: '20', inflation: '0'),
          calculatedAt: calculatedAt,
        );
        final allInvest = result.value.scenarios.first;
        final basis =
            allInvest.nominalScenario.allocation.investedAmount +
            allInvest.nominalScenario.nominalPaymentSavings;
        final expectedGain = allInvest.nominalScenario.totalFutureValue - basis;

        expect(allInvest.taxableInvestmentGain, expectedGain);
        expect(
          allInvest.estimatedTax,
          Money.parse('36.38', currency: Currencies.inr),
        );
        expect(
          allInvest.afterTaxFutureValue,
          allInvest.nominalScenario.totalFutureValue - allInvest.estimatedTax,
        );
      },
    );

    test('does not create a tax benefit for an investment loss', () {
      final result = const AdjustedDecisionAnalysisCalculator().calculate(
        input(tax: '30', inflation: '0', investmentReturn: '-20'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.scenarios.first.taxableInvestmentGain.isZero, isTrue);
      expect(result.value.scenarios.first.estimatedTax.isZero, isTrue);
    });

    test('discounts after-tax values with the existing inflation formula', () {
      final result = const AdjustedDecisionAnalysisCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );
      final selected = result.value.selectedScenario;
      final expected = const InflationAdjustmentCalculator().calculate(
        InflationAdjustmentInput(
          nominalFutureValue: selected.afterTaxFutureValue,
          annualInflationRate: Percentage.fromPercent('6'),
          horizonMonths: result
              .value
              .nominalAnalysis
              .optimization
              .commonHorizonInstallment,
        ),
        calculatedAt: calculatedAt,
      );

      expect(selected.realAfterTaxFutureValue, expected.value.realValue);
    });

    test('preserves currency and configured tax rounding', () {
      final result = const AdjustedDecisionAnalysisCalculator(
        roundingPolicy: RoundingPolicy.floor,
      ).calculate(input(currency: Currencies.usd), calculatedAt: calculatedAt);

      for (final scenario in result.value.scenarios) {
        expect(scenario.estimatedTax.currency, Currencies.usd);
        expect(scenario.realAfterTaxFutureValue.currency, Currencies.usd);
      }
    });

    test('preserves debt-first objective selection rules', () {
      final result = const AdjustedDecisionAnalysisCalculator().calculate(
        input(objective: CommonHorizonStrategyObjective.fastestDebtFree),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.selectedScenario.nominalScenario,
        result.value.nominalAnalysis.optimization.allPrepayScenario,
      );
    });

    test('publishes transparent OPT-012 metadata and limitations', () {
      final calculation = const AdjustedDecisionAnalysisCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(calculation.metadata.formulaId, 'OPT-012');
      expect(
        calculation.metadata.assumptions['taxBase'],
        'positiveInvestmentGainOnly',
      );
      expect(calculation.metadata.assumptions['taxTiming'], 'commonHorizon');
      expect(
        calculation.metadata.assumptions['inflationChangesRanking'],
        isFalse,
      );
      expect(
        calculation.metadata.details['nominalAnalysisFormulaId'],
        CommonHorizonDecisionAnalysisCalculator.formulaId,
      );
      expect(
        calculation.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-012-TAX-SIMPLIFICATION',
          'OPT-012-INFLATION-ASSUMPTION',
        ]),
      );
    });

    test('supports deterministic value equality and output', () {
      final first = const AdjustedDecisionAnalysisCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;
      final second = const AdjustedDecisionAnalysisCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('selectionChangedByTax'));
      expect(first.selectedScenario.toString(), contains('estimatedTax'));
    });

    test(
      'result rejects invalid adjustment assumptions and scenario grids',
      () {
        final valid = const AdjustedDecisionAnalysisCalculator()
            .calculate(input(), calculatedAt: calculatedAt)
            .value;

        expect(
          () => AdjustedDecisionAnalysisResult(
            nominalAnalysis: valid.nominalAnalysis,
            scenarios: valid.scenarios,
            selectedScenarioIndex: valid.selectedScenarioIndex,
            investmentGainTaxRate: Percentage.fromPercent('101'),
            annualInflationRate: valid.annualInflationRate,
          ),
          throwsArgumentError,
        );
        expect(
          () => AdjustedDecisionAnalysisResult(
            nominalAnalysis: valid.nominalAnalysis,
            scenarios: valid.scenarios.skip(1),
            selectedScenarioIndex: 0,
            investmentGainTaxRate: valid.investmentGainTaxRate,
            annualInflationRate: valid.annualInflationRate,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
