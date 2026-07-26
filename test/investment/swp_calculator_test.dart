import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 30, 12);
  const annualReturnForOnePercentMonthly = '12.6825030131969720661201';

  SwpInput input({
    String investment = '20000',
    String withdrawal = '1000',
    String annualReturn = '0',
    int months = 12,
    WithdrawalTiming timing = WithdrawalTiming.endOfPeriod,
    Currency currency = Currencies.inr,
  }) {
    return SwpInput(
      initialInvestment: Money.parse(investment, currency: currency),
      monthlyWithdrawal: Money.parse(withdrawal, currency: currency),
      expectedAnnualReturn: Percentage.fromPercent(annualReturn),
      tenureMonths: months,
      withdrawalTiming: timing,
    );
  }

  bool closeTo(Decimal actual, Decimal expected, String tolerance) {
    return (actual - expected).abs() <= Decimal.parse(tolerance);
  }

  group('SwpCalculator', () {
    test('projects a fully funded zero-return withdrawal plan', () {
      final result = const SwpCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.totalWithdrawn,
        Money.parse('12000', currency: Currencies.inr),
      );
      expect(
        result.value.endingBalance,
        Money.parse('8000', currency: Currencies.inr),
      );
      expect(result.value.isFullyFunded, isTrue);
      expect(result.value.isDepleted, isFalse);
      expect(result.value.withdrawalsMade, 12);
      expect(result.value.fullWithdrawalsMade, 12);
    });

    test('depletes exactly in the final month without a shortfall', () {
      final result = const SwpCalculator().calculate(
        input(investment: '12000'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.endingBalance, Money.zero(Currencies.inr));
      expect(result.value.depletionMonth, 12);
      expect(result.value.isDepletedEarly, isFalse);
      expect(result.value.isFullyFunded, isTrue);
    });

    test('reports early corpus depletion and funding shortfall', () {
      final result = const SwpCalculator().calculate(
        input(investment: '5000'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.depletionMonth, 5);
      expect(result.value.monthsProcessed, 5);
      expect(result.value.withdrawalsMade, 5);
      expect(result.value.fullWithdrawalsMade, 5);
      expect(
        result.value.totalWithdrawn,
        input(investment: '5000').initialInvestment,
      );
      expect(
        result.value.withdrawalShortfall,
        Money.parse('7000', currency: Currencies.inr),
      );
      expect(result.value.isDepletedEarly, isTrue);
    });

    test('uses a partial final withdrawal to exhaust the corpus', () {
      final result = const SwpCalculator().calculate(
        input(investment: '4500'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.depletionMonth, 5);
      expect(result.value.withdrawalsMade, 5);
      expect(result.value.fullWithdrawalsMade, 4);
      expect(
        result.value.totalWithdrawn,
        Money.parse('4500', currency: Currencies.inr),
      );
      expect(result.value.endingBalance, Money.zero(Currencies.inr));
    });

    test('end timing preserves more balance than beginning timing', () {
      const calculator = SwpCalculator();
      final end = calculator.calculate(
        input(
          annualReturn: annualReturnForOnePercentMonthly,
          timing: WithdrawalTiming.endOfPeriod,
        ),
        calculatedAt: calculatedAt,
      );
      final beginning = calculator.calculate(
        input(
          annualReturn: annualReturnForOnePercentMonthly,
          timing: WithdrawalTiming.beginningOfPeriod,
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        end.value.endingBalance.compareTo(beginning.value.endingBalance),
        greaterThan(0),
      );
      expect(end.value.totalWithdrawn, beginning.value.totalWithdrawn);
    });

    test('applies one percent monthly growth before end withdrawal', () {
      final result = const SwpCalculator().calculate(
        input(
          investment: '10000',
          annualReturn: annualReturnForOnePercentMonthly,
          months: 1,
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.endingBalance,
        Money.parse('9100', currency: Currencies.inr),
      );
      expect(
        closeTo(
          result.value.monthlyEquivalentReturn.percent,
          Decimal.one,
          '0.0000000001',
        ),
        isTrue,
      );
    });

    test('applies beginning withdrawal before monthly growth', () {
      final result = const SwpCalculator().calculate(
        input(
          investment: '10000',
          annualReturn: annualReturnForOnePercentMonthly,
          months: 1,
          timing: WithdrawalTiming.beginningOfPeriod,
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.endingBalance,
        Money.parse('9090', currency: Currencies.inr),
      );
    });

    test('supports negative expected returns', () {
      const calculator = SwpCalculator();
      final negative = calculator.calculate(
        input(annualReturn: '-10'),
        calculatedAt: calculatedAt,
      );
      final zero = calculator.calculate(input(), calculatedAt: calculatedAt);

      expect(negative.value.monthlyEquivalentReturn.isNegative, isTrue);
      expect(
        negative.value.endingBalance.compareTo(zero.value.endingBalance),
        lessThan(0),
      );
    });

    test('total-loss end timing depletes before any withdrawal', () {
      final result = const SwpCalculator().calculate(
        input(annualReturn: '-100'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.depletionMonth, 1);
      expect(result.value.withdrawalsMade, 0);
      expect(result.value.totalWithdrawn, Money.zero(Currencies.inr));
      expect(result.value.endingBalance, Money.zero(Currencies.inr));
    });

    test('total-loss beginning timing pays one withdrawal first', () {
      final result = const SwpCalculator().calculate(
        input(annualReturn: '-100', timing: WithdrawalTiming.beginningOfPeriod),
        calculatedAt: calculatedAt,
      );

      expect(result.value.depletionMonth, 1);
      expect(result.value.withdrawalsMade, 1);
      expect(
        result.value.totalWithdrawn,
        Money.parse('1000', currency: Currencies.inr),
      );
    });

    test('honors monthly growth rounding policy', () {
      final value = input(
        investment: '1',
        withdrawal: '0.5',
        annualReturn: '1',
        months: 1,
      );
      final halfUp = const SwpCalculator().calculate(
        value,
        calculatedAt: calculatedAt,
      );
      final ceiling = const SwpCalculator(
        roundingPolicy: RoundingPolicy.ceiling,
      ).calculate(value, calculatedAt: calculatedAt);

      expect(
        halfUp.value.endingBalance,
        Money.parse('0.5', currency: Currencies.inr),
      );
      expect(
        ceiling.value.endingBalance,
        Money.parse('0.51', currency: Currencies.inr),
      );
    });

    test('preserves another currency', () {
      final result = const SwpCalculator().calculate(
        input(currency: Currencies.usd),
        calculatedAt: calculatedAt,
      );

      expect(result.value.initialInvestment.currency, Currencies.usd);
      expect(result.value.monthlyWithdrawal.currency, Currencies.usd);
      expect(result.value.totalWithdrawn.currency, Currencies.usd);
      expect(result.value.endingBalance.currency, Currencies.usd);
    });

    test('returns only projection warning when fully funded', () {
      final result = const SwpCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.code, 'INV-004-PROJECTION-NOT-GUARANTEED');
      expect(result.warnings.single.severity, WarningSeverity.info);
    });

    test('adds caution warning when withdrawals are underfunded', () {
      final result = const SwpCalculator().calculate(
        input(investment: '5000'),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings, hasLength(2));
      expect(result.warnings.last.code, 'INV-004-WITHDRAWAL-SHORTFALL');
      expect(result.warnings.last.severity, WarningSeverity.caution);
      expect(result.warnings.last.message, contains('INR 7000'));
    });

    test('returns transparent INV-004 metadata', () {
      final result = const SwpCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'INV-004');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.inputs['initialInvestment'], '20000');
      expect(result.metadata.inputs['monthlyWithdrawal'], '1000');
      expect(result.metadata.assumptions['partialFinalWithdrawal'], isTrue);
      expect(
        result.metadata.assumptions['monthlyGrowthRounding'],
        'currencyDecimalPlaces',
      );
      expect(result.metadata.assumptions['taxesIncluded'], isFalse);
      expect(result.metadata.details['depletionMonth'], isNull);
    });

    test('is deterministic', () {
      final value = input(annualReturn: annualReturnForOnePercentMonthly);
      const calculator = SwpCalculator();

      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
