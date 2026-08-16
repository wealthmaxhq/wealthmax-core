import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 14, 12);

  HybridStrategyInput input({
    String principal = '100000',
    String rate = '10',
    int months = 24,
    String extraCash = '20000',
    String investmentReturn = '0',
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

  group('CommonHorizonStrategyPreparation', () {
    test('revalues to the same result as a full calculation', () {
      const calculator = CommonHorizonStrategyCalculator();
      final source = input();
      final preparation = calculator.prepare(
        source,
        calculatedAt: calculatedAt,
      );
      final grossReturn = Percentage.fromPercent('20');
      final expenseRatio = Percentage.fromPercent('1.25');

      final prepared = calculator.revaluePrepared(
        preparation,
        grossAnnualInvestmentReturn: grossReturn,
        annualExpenseRatio: expenseRatio,
      );
      final direct = calculator
          .calculate(
            source.copyWith(
              grossAnnualInvestmentReturn: grossReturn,
              annualExpenseRatio: expenseRatio,
            ),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(prepared, direct);
    });

    test('supports the minimum valid return exactly', () {
      const calculator = CommonHorizonStrategyCalculator();
      final source = input();
      final preparation = calculator.prepare(
        source,
        calculatedAt: calculatedAt,
      );
      final minimumReturn = Percentage.fromPercent('-100');

      final prepared = calculator.revaluePrepared(
        preparation,
        grossAnnualInvestmentReturn: minimumReturn,
        annualExpenseRatio: source.annualExpenseRatio,
      );
      final direct = calculator
          .calculate(
            source.copyWith(grossAnnualInvestmentReturn: minimumReturn),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(prepared, direct);
    });

    test('preserves currency and configured rounding policy', () {
      const calculator = CommonHorizonStrategyCalculator(
        roundingPolicy: RoundingPolicy.floor,
      );
      final source = input(currency: Currencies.usd);
      final preparation = calculator.prepare(
        source,
        calculatedAt: calculatedAt,
      );
      final grossReturn = Percentage.fromPercent('13.75');
      final expenseRatio = Percentage.fromPercent('2');

      final prepared = calculator.revaluePrepared(
        preparation,
        grossAnnualInvestmentReturn: grossReturn,
        annualExpenseRatio: expenseRatio,
      );
      final direct = calculator
          .calculate(
            source.copyWith(
              grossAnnualInvestmentReturn: grossReturn,
              annualExpenseRatio: expenseRatio,
            ),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(prepared, direct);
      for (final scenario in prepared.scenarios) {
        expect(scenario.totalFutureValue.currency, Currencies.usd);
      }
    });

    test('reuses prepared loan prepayment results for every scenario', () {
      const calculator = CommonHorizonStrategyCalculator();
      final source = input(step: 10);
      final preparation = calculator.prepare(
        source,
        calculatedAt: calculatedAt,
      );
      final revalued = calculator.revaluePrepared(
        preparation,
        grossAnnualInvestmentReturn: Percentage.fromPercent('18'),
        annualExpenseRatio: Percentage.fromPercent('1'),
      );

      expect(revalued.scenarios.length, preparation.template.scenarios.length);
      for (var index = 0; index < revalued.scenarios.length; index++) {
        expect(
          revalued.scenarios[index].allocation.loanPrepayment,
          same(preparation.template.scenarios[index].allocation.loanPrepayment),
        );
      }
    });

    test('has value semantics and deterministic output', () {
      const calculator = CommonHorizonStrategyCalculator();
      final source = input();
      final template = calculator
          .calculate(source, calculatedAt: calculatedAt)
          .value;
      final first = CommonHorizonStrategyPreparation(
        sourceInput: source,
        template: template,
      );
      final second = CommonHorizonStrategyPreparation(
        sourceInput: source,
        template: template,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('scenarioCount: 5'));
      expect(first.toString(), contains('commonHorizonInstallment:'));
    });

    test('rejects a template whose investment return does not match', () {
      const calculator = CommonHorizonStrategyCalculator();
      final source = input();
      final mismatchedTemplate = calculator
          .calculate(
            source.copyWith(
              grossAnnualInvestmentReturn: Percentage.fromPercent('12'),
            ),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(
        () => CommonHorizonStrategyPreparation(
          sourceInput: source,
          template: mismatchedTemplate,
        ),
        throwsArgumentError,
      );
    });

    test('break-even solver discloses prepared-scenario reuse', () {
      final result = const CommonHorizonBreakEvenCalculator().calculate(
        BreakEvenReturnInput(
          loan: input().loan,
          extraCash: input().extraCash,
          decisionInstallment: input().decisionInstallment,
          annualExpenseRatio: Percentage.fromPercent('0'),
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        result.metadata.assumptions['loanScenarioPreparationReused'],
        isTrue,
      );
      expect(result.metadata.details['loanScenarioPreparationCount'], 1);
      expect(
        result.metadata.details['strategyRevaluationCount'],
        greaterThan(0),
      );
      expect(
        result.metadata.details['avoidedLoanScenarioRebuildCount'],
        result.metadata.details['strategyRevaluationCount'],
      );
    });
  });
}
