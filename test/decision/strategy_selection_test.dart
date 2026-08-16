import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 9, 12);

  HybridStrategyInput hybrid({
    String principal = '100000',
    String rate = '10',
    int months = 24,
    String extraCash = '20000',
    String investmentReturn = '12',
    String expenseRatio = '0',
    int installment = 1,
    int step = 25,
    Currency currency = Currencies.inr,
  }) {
    return HybridStrategyInput(
      loan: LoanInput(
        principal: Money.parse(principal, currency: currency),
        annualInterestRate: Percentage.fromPercent(rate),
        tenureMonths: months,
      ),
      extraCash: Money.parse(extraCash, currency: currency),
      decisionInstallment: installment,
      grossAnnualInvestmentReturn: Percentage.fromPercent(investmentReturn),
      annualExpenseRatio: Percentage.fromPercent(expenseRatio),
      allocationStepPercent: step,
    );
  }

  StrategySelectionInput input(
    StrategyObjective objective, {
    HybridStrategyInput? hybridInput,
  }) {
    return StrategySelectionInput(
      hybridStrategy: hybridInput ?? hybrid(),
      objective: objective,
    );
  }

  group('StrategySelectionInput', () {
    test('stores the hybrid assumptions and explicit objective', () {
      final value = input(StrategyObjective.minimumInterestCost);

      expect(value.hybridStrategy, hybrid());
      expect(value.objective, StrategyObjective.minimumInterestCost);
    });

    test('supports copyWith, equality, hashing, and deterministic output', () {
      final original = input(StrategyObjective.maximumNominalBenefit);
      final changed = original.copyWith(
        objective: StrategyObjective.fastestDebtFree,
      );
      final expected = original.copyWith(
        objective: StrategyObjective.fastestDebtFree,
      );

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('fastestDebtFree'));
    });
  });

  group('StrategySelectionCalculator', () {
    test('maximum benefit selects the optimizer best scenario', () {
      final result = const StrategySelectionCalculator()
          .calculate(
            input(StrategyObjective.maximumNominalBenefit),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(result.selectedScenario, result.optimization.bestScenario);
      expect(result.nominalBenefitDifferenceFromMaximum.isZero, isTrue);
    });

    test('minimum interest selects the greatest interest saving', () {
      final result = const StrategySelectionCalculator()
          .calculate(
            input(StrategyObjective.minimumInterestCost),
            calculatedAt: calculatedAt,
          )
          .value;

      for (final scenario in result.optimization.scenarios) {
        expect(
          result.selectedScenario.interestSaved.compareTo(
            scenario.interestSaved,
          ),
          greaterThanOrEqualTo(0),
        );
      }
    });

    test('fastest debt-free selects the greatest tenure reduction', () {
      final result = const StrategySelectionCalculator()
          .calculate(
            input(StrategyObjective.fastestDebtFree),
            calculatedAt: calculatedAt,
          )
          .value;

      for (final scenario in result.optimization.scenarios) {
        expect(
          result.selectedScenario.installmentsReduced,
          greaterThanOrEqualTo(scenario.installmentsReduced),
        );
      }
    });

    test('maximum invested capital selects the all-invest endpoint', () {
      final value = hybrid();
      final result = const StrategySelectionCalculator()
          .calculate(
            input(StrategyObjective.maximumInvestedCapital, hybridInput: value),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(result.selectedScenario, result.optimization.allInvestScenario);
      expect(result.selectedScenario.investedAmount, value.extraCash);
    });

    test('high return can separate maximum benefit from debt objectives', () {
      final assumptions = hybrid(investmentReturn: '40');
      const calculator = StrategySelectionCalculator();
      final wealth = calculator
          .calculate(
            input(
              StrategyObjective.maximumNominalBenefit,
              hybridInput: assumptions,
            ),
            calculatedAt: calculatedAt,
          )
          .value;
      final debt = calculator
          .calculate(
            input(
              StrategyObjective.minimumInterestCost,
              hybridInput: assumptions,
            ),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(wealth.selectedScenario, wealth.optimization.allInvestScenario);
      expect(
        debt.selectedScenario.requestedPrepaymentAllocation.compareTo(
          wealth.selectedScenario.requestedPrepaymentAllocation,
        ),
        greaterThan(0),
      );
      expect(debt.nominalBenefitDifferenceFromMaximum.isNegative, isTrue);
    });

    test('debt objectives use lower allocation after lender cap ties', () {
      final assumptions = hybrid(
        principal: '1000',
        extraCash: '100000',
        step: 25,
      );
      const calculator = StrategySelectionCalculator();
      final minimumInterest = calculator
          .calculate(
            input(
              StrategyObjective.minimumInterestCost,
              hybridInput: assumptions,
            ),
            calculatedAt: calculatedAt,
          )
          .value;
      final fastest = calculator
          .calculate(
            input(StrategyObjective.fastestDebtFree, hybridInput: assumptions),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(
        minimumInterest.selectedScenario.requestedPrepaymentAllocation.percent,
        Percentage.fromPercent('25').percent,
      );
      expect(fastest.selectedScenario, minimumInterest.selectedScenario);
      expect(
        minimumInterest.selectedScenario.redirectedToInvestment.isPositive,
        isTrue,
      );
    });

    test('selection is always one of the evaluated immutable scenarios', () {
      final result = const StrategySelectionCalculator().calculate(
        input(StrategyObjective.fastestDebtFree),
        calculatedAt: calculatedAt,
      );

      expect(
        identical(
          result.value.selectedScenario,
          result.value.optimization.scenarios[result
              .value
              .selectedScenarioIndex],
        ),
        isTrue,
      );
      expect(
        () => result.value.optimization.scenarios.add(
          result.value.selectedScenario,
        ),
        throwsUnsupportedError,
      );
    });

    test('preserves currency and configured rounding policy', () {
      final result =
          const StrategySelectionCalculator(
            roundingPolicy: RoundingPolicy.floor,
          ).calculate(
            input(
              StrategyObjective.maximumNominalBenefit,
              hybridInput: hybrid(currency: Currencies.usd),
            ),
            calculatedAt: calculatedAt,
          );

      expect(
        result.value.selectedScenario.availableCash.currency,
        Currencies.usd,
      );
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('returns transparent OPT-006 rules without weighted scoring', () {
      final result = const StrategySelectionCalculator().calculate(
        input(StrategyObjective.minimumInterestCost),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'OPT-006');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(
        result.metadata.assumptions['selectionMethod'],
        'lexicographicObjectiveMetrics',
      );
      expect(result.metadata.assumptions['weightedScoreUsed'], isFalse);
      expect(result.metadata.assumptions['financialAdvice'], isFalse);
      expect(result.metadata.assumptions['objectiveRules'], <String>[
        'maximizeInterestSaved',
        'maximizeInstallmentsReduced',
        'maximizeInvestedAmount',
        'minimizeRequestedPrepaymentAllocation',
      ]);
      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-006-OBJECTIVE-DEPENDENT'),
      );
    });

    test('adds liquidity warning only for invested-capital objective', () {
      const calculator = StrategySelectionCalculator();
      final capital = calculator.calculate(
        input(StrategyObjective.maximumInvestedCapital),
        calculatedAt: calculatedAt,
      );
      final benefit = calculator.calculate(
        input(StrategyObjective.maximumNominalBenefit),
        calculatedAt: calculatedAt,
      );

      expect(
        capital.warnings.map((warning) => warning.code),
        contains('OPT-006-LIQUIDITY-NOT-INFERRED'),
      );
      expect(
        benefit.warnings.map((warning) => warning.code),
        isNot(contains('OPT-006-LIQUIDITY-NOT-INFERRED')),
      );
    });

    test('rejects an invalid selected scenario index', () {
      final optimization = const HybridStrategyCalculator()
          .calculate(hybrid(), calculatedAt: calculatedAt)
          .value;

      expect(
        () => StrategySelectionResult(
          optimization: optimization,
          objective: StrategyObjective.maximumNominalBenefit,
          selectedScenarioIndex: -1,
        ),
        throwsRangeError,
      );
      expect(
        () => StrategySelectionResult(
          optimization: optimization,
          objective: StrategyObjective.maximumNominalBenefit,
          selectedScenarioIndex: optimization.scenarios.length,
        ),
        throwsRangeError,
      );
    });

    test('supports value semantics and deterministic output', () {
      const calculator = StrategySelectionCalculator();
      final selectedInput = input(StrategyObjective.fastestDebtFree);
      final first = calculator.calculate(
        selectedInput,
        calculatedAt: calculatedAt,
      );
      final second = calculator.calculate(
        selectedInput,
        calculatedAt: calculatedAt,
      );

      expect(first, second);
      expect(first.value.hashCode, second.value.hashCode);
      expect(first.value.toString(), contains('fastestDebtFree'));
      expect(
        first.value.toString(),
        contains('nominalBenefitDifferenceFromMaximum'),
      );
    });
  });
}
