import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 10, 12);

  HybridStrategyInput input({
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

  group('CommonHorizonStrategyCalculator', () {
    test('preserves the allocation grid and endpoints', () {
      final result = const CommonHorizonStrategyCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      expect(result.scenarios.length, 5);
      expect(
        result.allInvestScenario.requestedPrepaymentAllocation.isZero,
        isTrue,
      );
      expect(
        result.allPrepayScenario.requestedPrepaymentAllocation.percent,
        Percentage.fromPercent('100').percent,
      );
      expect(
        result.commonHorizonInstallment,
        result
            .allInvestScenario
            .allocation
            .loanPrepayment
            .baseline
            .paymentCount,
      );
    });

    test('all-invest has no future loan-payment savings', () {
      final result = const CommonHorizonStrategyCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value
          .allInvestScenario;

      expect(result.reinvestedPaymentSavings, isEmpty);
      expect(result.futureValueOfPaymentSavings.isZero, isTrue);
      expect(result.totalFutureValue, result.initialInvestmentFutureValue);
    });

    test('zero return reconciles wealth gain to nominal interest saved', () {
      final result = const CommonHorizonStrategyCalculator()
          .calculate(
            input(investmentReturn: '0', step: 10),
            calculatedAt: calculatedAt,
          )
          .value;

      for (final scenario in result.scenarios) {
        expect(scenario.futureWealthGain, scenario.allocation.interestSaved);
        expect(
          scenario.nominalPaymentSavings,
          scenario.allocation.appliedPrepayment +
              scenario.allocation.interestSaved,
        );
      }
    });

    test(
      'zero loan and investment returns make all allocations equivalent',
      () {
        final result = const CommonHorizonStrategyCalculator()
            .calculate(
              input(rate: '0', investmentReturn: '0'),
              calculatedAt: calculatedAt,
            )
            .value;

        for (final scenario in result.scenarios) {
          expect(
            scenario.totalFutureValue,
            input(rate: '0', investmentReturn: '0').extraCash,
          );
        }
        expect(result.bestScenario, result.allInvestScenario);
      },
    );

    test('positive return compounds earlier payment savings for longer', () {
      final scenario = const CommonHorizonStrategyCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value
          .allPrepayScenario;

      expect(scenario.reinvestedPaymentSavings, isNotEmpty);
      expect(
        scenario.futureValueOfPaymentSavings.compareTo(
          scenario.nominalPaymentSavings,
        ),
        greaterThan(0),
      );
      for (
        var index = 1;
        index < scenario.reinvestedPaymentSavings.length;
        index++
      ) {
        final previous = scenario.reinvestedPaymentSavings[index - 1];
        final current = scenario.reinvestedPaymentSavings[index];
        expect(
          current.installmentNumber,
          greaterThan(previous.installmentNumber),
        );
        expect(current.growthMonths, lessThan(previous.growthMonths));
      }
    });

    test('excludes the decision prepayment from saved payment cash flows', () {
      final decisionInstallment = 6;
      final scenario = const CommonHorizonStrategyCalculator()
          .calculate(
            input(installment: decisionInstallment),
            calculatedAt: calculatedAt,
          )
          .value
          .allPrepayScenario;

      expect(scenario.reinvestedPaymentSavings, isNotEmpty);
      expect(
        scenario.reinvestedPaymentSavings.first.installmentNumber,
        greaterThan(decisionInstallment),
      );
      expect(scenario.reinvestedPaymentSavings.last.growthMonths, 0);
    });

    test('scenario total equals both future-value components', () {
      final result = const CommonHorizonStrategyCalculator()
          .calculate(input(step: 10), calculatedAt: calculatedAt)
          .value;

      for (final scenario in result.scenarios) {
        expect(
          scenario.totalFutureValue,
          scenario.initialInvestmentFutureValue +
              scenario.futureValueOfPaymentSavings,
        );
        var sum = Money.zero(scenario.allocation.availableCash.currency);
        for (final cashFlow in scenario.reinvestedPaymentSavings) {
          sum += cashFlow.futureValue;
        }
        expect(sum, scenario.futureValueOfPaymentSavings);
      }
    });

    test('high return favors the all-invest strategy', () {
      final result = const CommonHorizonStrategyCalculator()
          .calculate(input(investmentReturn: '40'), calculatedAt: calculatedAt)
          .value;

      expect(result.bestScenario, result.allInvestScenario);
    });

    test('negative return favors loan prepayment', () {
      final result = const CommonHorizonStrategyCalculator()
          .calculate(input(investmentReturn: '-20'), calculatedAt: calculatedAt)
          .value;

      expect(result.bestScenario, result.allPrepayScenario);
    });

    test('expense ratio lowers all-invest common-horizon value', () {
      const calculator = CommonHorizonStrategyCalculator();
      final noFee = calculator
          .calculate(input(expenseRatio: '0'), calculatedAt: calculatedAt)
          .value
          .allInvestScenario;
      final fee = calculator
          .calculate(input(expenseRatio: '2'), calculatedAt: calculatedAt)
          .value
          .allInvestScenario;

      expect(
        fee.totalFutureValue.compareTo(noFee.totalFutureValue),
        lessThan(0),
      );
    });

    test('capped prepayment redirects excess into initial investment', () {
      final result = const CommonHorizonStrategyCalculator().calculate(
        input(extraCash: '1000000', step: 50),
        calculatedAt: calculatedAt,
      );
      final allPrepay = result.value.allPrepayScenario;

      expect(allPrepay.allocation.redirectedToInvestment.isPositive, isTrue);
      expect(
        allPrepay.allocation.investedAmount,
        allPrepay.allocation.redirectedToInvestment,
      );
      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-007-PREPAYMENT-CAPPED'),
      );
    });

    test('preserves currency and configured rounding policy', () {
      final result = const CommonHorizonStrategyCalculator(
        roundingPolicy: RoundingPolicy.floor,
      ).calculate(input(currency: Currencies.usd), calculatedAt: calculatedAt);

      for (final scenario in result.value.scenarios) {
        expect(scenario.totalFutureValue.currency, Currencies.usd);
        expect(scenario.futureValueOfPaymentSavings.currency, Currencies.usd);
      }
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('returns transparent OPT-007 cash-flow assumptions', () {
      final result = const CommonHorizonStrategyCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'OPT-007');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.assumptions['cashFlowTimingNormalized'], isTrue);
      expect(
        result.metadata.assumptions['savedPaymentTreatment'],
        'fullyReinvestedToCommonHorizon',
      );
      expect(
        result.metadata.assumptions['prepaymentExcludedFromSavedPayments'],
        isTrue,
      );
      expect(
        result.metadata.assumptions['paymentSavingFutureValueRounding'],
        'eachCashFlowAtCurrencyPrecision',
      );
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-007-PROJECTION-NOT-GUARANTEED',
          'OPT-007-REINVESTMENT-DISCIPLINE-ASSUMED',
          'OPT-007-TAX-INFLATION-RISK-EXCLUDED',
        ]),
      );
    });

    test('cash-flow and scenario collections are immutable', () {
      final result = const CommonHorizonStrategyCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;
      final scenario = result.allPrepayScenario;

      expect(
        () => result.scenarios.add(result.bestScenario),
        throwsUnsupportedError,
      );
      expect(
        () => scenario.reinvestedPaymentSavings.add(
          scenario.reinvestedPaymentSavings.first,
        ),
        throwsUnsupportedError,
      );
    });

    test('supports value semantics and deterministic output', () {
      const calculator = CommonHorizonStrategyCalculator();
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
      expect(first.value.toString(), contains('commonHorizonInstallment'));
      expect(first.value.bestScenario.toString(), contains('totalFutureValue'));
      expect(
        first.value.allPrepayScenario.reinvestedPaymentSavings.first.toString(),
        contains('growthMonths'),
      );
    });

    test('result rejects unordered scenarios and invalid horizon', () {
      final value = const CommonHorizonStrategyCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      expect(
        () => CommonHorizonStrategyResult(
          scenarios: value.scenarios.reversed,
          netAnnualInvestmentReturn: value.netAnnualInvestmentReturn,
          commonHorizonInstallment: value.commonHorizonInstallment,
        ),
        throwsArgumentError,
      );
      expect(
        () => CommonHorizonStrategyResult(
          scenarios: value.scenarios,
          netAnnualInvestmentReturn: value.netAnnualInvestmentReturn,
          commonHorizonInstallment: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
