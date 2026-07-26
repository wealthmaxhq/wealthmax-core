import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 8, 12);

  LoanInput loan({
    String principal = '100000',
    String rate = '10',
    int months = 24,
    Currency currency = Currencies.inr,
  }) {
    return LoanInput(
      principal: Money.parse(principal, currency: currency),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: months,
    );
  }

  HybridStrategyInput input({
    LoanInput? loanInput,
    String extraCash = '20000',
    int installment = 1,
    String investmentReturn = '12',
    String expenseRatio = '0',
    int step = 25,
  }) {
    final selectedLoan = loanInput ?? loan();
    return HybridStrategyInput(
      loan: selectedLoan,
      extraCash: Money.parse(
        extraCash,
        currency: selectedLoan.principal.currency,
      ),
      decisionInstallment: installment,
      grossAnnualInvestmentReturn: Percentage.fromPercent(investmentReturn),
      annualExpenseRatio: Percentage.fromPercent(expenseRatio),
      allocationStepPercent: step,
    );
  }

  group('HybridStrategyInput', () {
    test('validates cash, currency, rates, installment, and step', () {
      expect(input().allocationStepPercent, 25);
      expect(() => input(extraCash: '0'), throwsArgumentError);
      expect(() => input(installment: 0), throwsArgumentError);
      expect(() => input(installment: 25), throwsArgumentError);
      expect(() => input(investmentReturn: '-100.01'), throwsArgumentError);
      expect(() => input(expenseRatio: '-0.01'), throwsArgumentError);
      expect(() => input(expenseRatio: '100'), throwsArgumentError);
      expect(() => input(step: 0), throwsArgumentError);
      expect(() => input(step: 101), throwsArgumentError);
      expect(
        () => HybridStrategyInput(
          loan: loan(),
          extraCash: Money.parse('100', currency: Currencies.usd),
          decisionInstallment: 1,
          grossAnnualInvestmentReturn: Percentage.fromPercent('10'),
          annualExpenseRatio: Percentage.fromPercent('0'),
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith, equality, hashing, and output', () {
      final original = input();
      final changed = original.copyWith(allocationStepPercent: 20);
      final expected = original.copyWith(allocationStepPercent: 20);

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('allocationStepPercent: 20'));
    });
  });

  group('HybridStrategyCalculator', () {
    test('includes both endpoints and every configured allocation', () {
      final result = const HybridStrategyCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      expect(
        result.scenarios.map(
          (scenario) => scenario.requestedPrepaymentAllocation.percent,
        ),
        <Decimal>[
          Decimal.zero,
          Decimal.fromInt(25),
          Decimal.fromInt(50),
          Decimal.fromInt(75),
          Decimal.fromInt(100),
        ],
      );
      expect(result.allInvestScenario.requestedPrepayment.isZero, isTrue);
      expect(result.allInvestScenario.investedAmount, input().extraCash);
      expect(result.allPrepayScenario.requestedPrepayment, input().extraCash);
      expect(result.allPrepayScenario.investedAmount.isZero, isTrue);
    });

    test('preserves exact cash at allocation endpoints', () {
      final selectedInput = input(extraCash: '1234.5678', step: 50);
      final result = const HybridStrategyCalculator()
          .calculate(selectedInput, calculatedAt: calculatedAt)
          .value;

      expect(result.allInvestScenario.investedAmount, selectedInput.extraCash);
      expect(
        result.allPrepayScenario.requestedPrepayment,
        selectedInput.extraCash,
      );
      for (final scenario in result.scenarios) {
        expect(
          scenario.appliedPrepayment + scenario.investedAmount,
          selectedInput.extraCash,
        );
      }
    });

    test('includes 100% when step does not divide 100', () {
      final result = const HybridStrategyCalculator()
          .calculate(input(step: 30), calculatedAt: calculatedAt)
          .value;

      expect(
        result.scenarios.map(
          (scenario) => scenario.requestedPrepaymentAllocation.percent,
        ),
        <Decimal>[
          Decimal.zero,
          Decimal.fromInt(30),
          Decimal.fromInt(60),
          Decimal.fromInt(90),
          Decimal.fromInt(100),
        ],
      );
    });

    test('conserves available cash in every scenario', () {
      final result = const HybridStrategyCalculator()
          .calculate(input(step: 10), calculatedAt: calculatedAt)
          .value;

      for (final scenario in result.scenarios) {
        expect(
          scenario.appliedPrepayment + scenario.investedAmount,
          scenario.availableCash,
        );
      }
    });

    test('redirects lender-capped prepayment into investment', () {
      final result = const HybridStrategyCalculator()
          .calculate(
            input(extraCash: '1000000', step: 50),
            calculatedAt: calculatedAt,
          )
          .value;
      final allPrepay = result.allPrepayScenario;

      expect(allPrepay.redirectedToInvestment.isPositive, isTrue);
      expect(allPrepay.investedAmount, allPrepay.redirectedToInvestment);
      expect(
        allPrepay.appliedPrepayment + allPrepay.investedAmount,
        allPrepay.availableCash,
      );
    });

    test(
      'zero loan rate and zero investment return tie-breaks to liquidity',
      () {
        final result = const HybridStrategyCalculator()
            .calculate(
              input(
                loanInput: loan(rate: '0'),
                investmentReturn: '0',
                step: 25,
              ),
              calculatedAt: calculatedAt,
            )
            .value;

        expect(result.bestScenarioIndex, 0);
        expect(result.bestScenario, result.allInvestScenario);
        expect(result.bestScenario.totalNominalBenefit.isZero, isTrue);
      },
    );

    test('high investment return favors all investment', () {
      final result = const HybridStrategyCalculator()
          .calculate(input(investmentReturn: '30'), calculatedAt: calculatedAt)
          .value;

      expect(result.bestScenario, result.allInvestScenario);
      expect(result.bestScenario.investedAmount, input().extraCash);
    });

    test('negative investment return favors loan prepayment', () {
      final result = const HybridStrategyCalculator()
          .calculate(input(investmentReturn: '-20'), calculatedAt: calculatedAt)
          .value;

      expect(result.bestScenario, result.allPrepayScenario);
      expect(result.bestScenario.interestSaved.isPositive, isTrue);
    });

    test('expense ratio lowers investment scenario benefit', () {
      const calculator = HybridStrategyCalculator();
      final noFee = calculator
          .calculate(input(expenseRatio: '0'), calculatedAt: calculatedAt)
          .value
          .allInvestScenario;
      final withFee = calculator
          .calculate(input(expenseRatio: '2'), calculatedAt: calculatedAt)
          .value
          .allInvestScenario;

      expect(
        withFee.totalNominalBenefit.compareTo(noFee.totalNominalBenefit),
        lessThan(0),
      );
    });

    test('preserves currency and configured minor-unit rounding', () {
      final selectedInput = input(
        loanInput: loan(currency: Currencies.usd),
        extraCash: '1234.56',
        step: 33,
      );
      final result = const HybridStrategyCalculator(
        roundingPolicy: RoundingPolicy.floor,
      ).calculate(selectedInput, calculatedAt: calculatedAt);

      for (final scenario in result.value.scenarios) {
        expect(scenario.availableCash.currency, Currencies.usd);
        expect(scenario.appliedPrepayment.currency, Currencies.usd);
        expect(scenario.investedAmount.currency, Currencies.usd);
        expect(
          scenario.appliedPrepayment + scenario.investedAmount,
          selectedInput.extraCash,
        );
      }
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('ranks every scenario by benefit with documented tie-break', () {
      final result = const HybridStrategyCalculator()
          .calculate(input(step: 10), calculatedAt: calculatedAt)
          .value;

      for (final scenario in result.scenarios) {
        final comparison = result.bestScenario.totalNominalBenefit.compareTo(
          scenario.totalNominalBenefit,
        );
        expect(comparison, greaterThanOrEqualTo(0));
        if (comparison == 0) {
          expect(
            result.bestScenario.investedAmount.compareTo(
              scenario.investedAmount,
            ),
            greaterThanOrEqualTo(0),
          );
        }
      }
    });

    test('returns transparent OPT-005 metadata and limitations', () {
      final result = const HybridStrategyCalculator().calculate(
        input(step: 20),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'OPT-005');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(
        result.metadata.assumptions['rankingObjective'],
        'interestSavedPlusInvestmentGain',
      );
      expect(
        result.metadata.assumptions['unappliedPrepaymentTreatment'],
        'redirectToInvestment',
      );
      expect(result.metadata.assumptions['cashConservationRequired'], isTrue);
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-005-PROJECTION-NOT-GUARANTEED',
          'OPT-005-NOMINAL-TIMING-NOT-NORMALIZED',
          'OPT-005-TAX-INFLATION-RISK-EXCLUDED',
        ]),
      );
    });

    test('reports capped-prepayment warning only when applicable', () {
      const calculator = HybridStrategyCalculator();
      final uncapped = calculator.calculate(
        input(extraCash: '1000'),
        calculatedAt: calculatedAt,
      );
      final capped = calculator.calculate(
        input(extraCash: '1000000'),
        calculatedAt: calculatedAt,
      );

      expect(
        uncapped.warnings.map((warning) => warning.code),
        isNot(contains('OPT-005-PREPAYMENT-CAPPED')),
      );
      expect(
        capped.warnings.map((warning) => warning.code),
        contains('OPT-005-PREPAYMENT-CAPPED'),
      );
    });

    test('scenario collections are immutable and output is deterministic', () {
      const calculator = HybridStrategyCalculator();
      final selectedInput = input();
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
      expect(
        () => first.value.scenarios.add(first.value.bestScenario),
        throwsUnsupportedError,
      );
      expect(first.value.toString(), contains('bestScenario'));
      expect(first.value.bestScenario.toString(), contains('investedAmount'));
    });

    test('result rejects unordered scenarios and missing endpoints', () {
      final value = const HybridStrategyCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      expect(
        () => HybridStrategyResult(
          scenarios: value.scenarios.reversed,
          netAnnualInvestmentReturn: value.netAnnualInvestmentReturn,
        ),
        throwsArgumentError,
      );
      expect(
        () => HybridStrategyResult(
          scenarios: value.scenarios.skip(1),
          netAnnualInvestmentReturn: value.netAnnualInvestmentReturn,
        ),
        throwsArgumentError,
      );
    });

    test('scenario rejects a cash conservation violation', () {
      final scenario = const HybridStrategyCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value
          .scenarios[1];

      expect(
        () => HybridStrategyScenario(
          requestedPrepaymentAllocation: scenario.requestedPrepaymentAllocation,
          availableCash: scenario.availableCash,
          requestedPrepayment: scenario.requestedPrepayment,
          loanPrepayment: scenario.loanPrepayment,
          investedAmount:
              scenario.investedAmount +
              Money.parse('1', currency: scenario.investedAmount.currency),
          investmentFutureValue: scenario.investmentFutureValue,
          investmentHorizonMonths: scenario.investmentHorizonMonths,
        ),
        throwsArgumentError,
      );
    });
  });
}
