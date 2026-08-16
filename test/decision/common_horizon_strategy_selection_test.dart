import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 13, 12);

  HybridStrategyInput strategy({
    String principal = '10000',
    String rate = '10',
    int months = 12,
    String extraCash = '1000',
    int installment = 1,
    String investmentReturn = '20',
    String expenseRatio = '0',
    int allocationStep = 25,
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
      allocationStepPercent: allocationStep,
    );
  }

  CommonHorizonStrategySelectionInput input(
    CommonHorizonStrategyObjective objective, {
    HybridStrategyInput? hybridStrategy,
  }) {
    return CommonHorizonStrategySelectionInput(
      hybridStrategy: hybridStrategy ?? strategy(),
      objective: objective,
    );
  }

  late Map<
    CommonHorizonStrategyObjective,
    CalculationResult<CommonHorizonStrategySelectionResult>
  >
  calculations;

  setUpAll(() {
    calculations =
        <
          CommonHorizonStrategyObjective,
          CalculationResult<CommonHorizonStrategySelectionResult>
        >{
          for (final objective in CommonHorizonStrategyObjective.values)
            objective: const CommonHorizonStrategySelectionCalculator()
                .calculate(input(objective), calculatedAt: calculatedAt),
        };
  });

  group('CommonHorizonStrategySelectionInput', () {
    test('supports copyWith, equality, hashing, and output', () {
      final original = input(CommonHorizonStrategyObjective.maximumFutureValue);
      final same = original.copyWith();
      final changed = original.copyWith(
        objective: CommonHorizonStrategyObjective.fastestDebtFree,
      );

      expect(same, original);
      expect(same.hashCode, original.hashCode);
      expect(changed, isNot(original));
      expect(original.toString(), contains('maximumFutureValue'));
    });
  });

  group('CommonHorizonStrategySelectionCalculator', () {
    test('maximum future value selects the normalized optimum', () {
      final result =
          calculations[CommonHorizonStrategyObjective.maximumFutureValue]!
              .value;

      expect(
        result.selectedScenarioIndex,
        result.optimization.bestScenarioIndex,
      );
      expect(result.selectedScenario, result.optimization.bestScenario);
      expect(result.futureValueDifferenceFromMaximum.isZero, isTrue);
    });

    test('minimum interest cost selects the highest prepayment', () {
      final result =
          calculations[CommonHorizonStrategyObjective.minimumInterestCost]!
              .value;

      expect(result.selectedScenario, result.optimization.allPrepayScenario);
      expect(
        result.selectedScenario.allocation.interestSaved,
        result.optimization.scenarios
            .map((scenario) => scenario.allocation.interestSaved)
            .reduce(
              (first, second) => first.compareTo(second) >= 0 ? first : second,
            ),
      );
    });

    test('fastest debt free selects the greatest tenure reduction', () {
      final result =
          calculations[CommonHorizonStrategyObjective.fastestDebtFree]!.value;
      final maximumReduction = result.optimization.scenarios
          .map((scenario) => scenario.allocation.installmentsReduced)
          .reduce((first, second) => first > second ? first : second);

      expect(
        result.selectedScenario.allocation.installmentsReduced,
        maximumReduction,
      );
      expect(result.selectedScenario, result.optimization.allPrepayScenario);
    });

    test('maximum invested capital selects all-invest', () {
      final calculation =
          calculations[CommonHorizonStrategyObjective.maximumInvestedCapital]!;

      expect(
        calculation.value.selectedScenario,
        calculation.value.optimization.allInvestScenario,
      );
      expect(
        calculation.warnings.map((warning) => warning.code),
        contains('OPT-010-LIQUIDITY-NOT-INFERRED'),
      );
    });

    test('zero-return tie deterministically favors lower prepayment', () {
      final result = const CommonHorizonStrategySelectionCalculator().calculate(
        input(
          CommonHorizonStrategyObjective.maximumFutureValue,
          hybridStrategy: strategy(rate: '0', investmentReturn: '0'),
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.selectedScenario.requestedPrepaymentAllocation.isZero,
        isTrue,
      );
    });

    test('preserves another currency and configured rounding', () {
      final result =
          const CommonHorizonStrategySelectionCalculator(
            roundingPolicy: RoundingPolicy.floor,
          ).calculate(
            input(
              CommonHorizonStrategyObjective.maximumFutureValue,
              hybridStrategy: strategy(currency: Currencies.usd),
            ),
            calculatedAt: calculatedAt,
          );

      expect(
        result.value.selectedScenario.totalFutureValue.currency,
        Currencies.usd,
      );
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('propagates prepayment cap disclosure', () {
      final result = const CommonHorizonStrategySelectionCalculator().calculate(
        input(
          CommonHorizonStrategyObjective.minimumInterestCost,
          hybridStrategy: strategy(extraCash: '100000'),
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-007-PREPAYMENT-CAPPED'),
      );
    });

    test('returns transparent OPT-010 objective rules without scoring', () {
      final result =
          calculations[CommonHorizonStrategyObjective.fastestDebtFree]!;

      expect(result.metadata.formulaId, 'OPT-010');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.assumptions['weightedScoreUsed'], isFalse);
      expect(result.metadata.assumptions['cashFlowTimingNormalized'], isTrue);
      expect(
        result.metadata.assumptions['objectiveRules'],
        contains('maximizeInstallmentsReduced'),
      );
      expect(
        result.metadata.details['commonHorizonStrategyFormulaId'],
        CommonHorizonStrategyCalculator.formulaId,
      );
      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-010-OBJECTIVE-DEPENDENT'),
      );
    });

    test('non-wealth objectives disclose their future-value tradeoff', () {
      final maximum =
          calculations[CommonHorizonStrategyObjective.maximumFutureValue]!
              .value;
      final debtFree =
          calculations[CommonHorizonStrategyObjective.fastestDebtFree]!.value;

      expect(maximum.futureValueDifferenceFromMaximum.isZero, isTrue);
      expect(debtFree.futureValueDifferenceFromMaximum.isPositive, isFalse);
    });

    test('result rejects an out-of-range selected index', () {
      final optimization =
          calculations[CommonHorizonStrategyObjective.maximumFutureValue]!
              .value
              .optimization;

      expect(
        () => CommonHorizonStrategySelectionResult(
          optimization: optimization,
          objective: CommonHorizonStrategyObjective.maximumFutureValue,
          selectedScenarioIndex: optimization.scenarios.length,
        ),
        throwsRangeError,
      );
    });

    test('supports value equality, hashing, and deterministic output', () {
      final first =
          calculations[CommonHorizonStrategyObjective.maximumFutureValue]!;
      final second = const CommonHorizonStrategySelectionCalculator().calculate(
        input(CommonHorizonStrategyObjective.maximumFutureValue),
        calculatedAt: calculatedAt,
      );

      expect(first, second);
      expect(first.value.hashCode, second.value.hashCode);
      expect(first.value.toString(), contains('maximumFutureValue'));
      expect(
        first.value.toString(),
        contains('futureValueDifferenceFromMaximum'),
      );
    });
  });
}
