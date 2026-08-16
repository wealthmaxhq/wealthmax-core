import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 5, 12);

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

  BreakEvenReturnInput input({
    LoanInput? loanInput,
    String extraCash = '10000',
    int installment = 1,
    String expenseRatio = '1',
  }) {
    final selectedLoan = loanInput ?? loan();
    return BreakEvenReturnInput(
      loan: selectedLoan,
      extraCash: Money.parse(
        extraCash,
        currency: selectedLoan.principal.currency,
      ),
      decisionInstallment: installment,
      annualExpenseRatio: Percentage.fromPercent(expenseRatio),
    );
  }

  group('BreakEvenReturnInput', () {
    test('stores valid assumptions', () {
      final value = input();

      expect(value.extraCash.amount, Decimal.fromInt(10000));
      expect(value.decisionInstallment, 1);
      expect(value.annualExpenseRatio, Percentage.fromPercent('1'));
    });

    test('rejects invalid cash, currency, installment, and expense ratio', () {
      expect(() => input(extraCash: '0'), throwsArgumentError);
      expect(() => input(installment: 0), throwsArgumentError);
      expect(() => input(installment: 25), throwsArgumentError);
      expect(() => input(expenseRatio: '-0.1'), throwsArgumentError);
      expect(() => input(expenseRatio: '100'), throwsArgumentError);
      expect(
        () => BreakEvenReturnInput(
          loan: loan(),
          extraCash: Money.parse('100', currency: Currencies.usd),
          decisionInstallment: 1,
          annualExpenseRatio: Percentage.fromPercent('1'),
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith, equality, hashing, and output', () {
      final original = input();
      final changed = original.copyWith(decisionInstallment: 2);
      final expected = original.copyWith(decisionInstallment: 2);

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('decisionInstallment: 2'));
    });
  });

  group('BreakEvenReturnCalculator', () {
    test('finds zero break-even return for a zero-rate loan without fees', () {
      final result = const BreakEvenReturnCalculator().calculate(
        input(
          loanInput: loan(rate: '0'),
          expenseRatio: '0',
        ),
        calculatedAt: calculatedAt,
      );

      expect(result.value.interestSaved.isZero, isTrue);
      expect(result.value.breakEvenNetAnnualReturn.isZero, isTrue);
      expect(result.value.breakEvenGrossAnnualReturn.isZero, isTrue);
    });

    test('fee alone raises gross break-even above zero', () {
      final result = const BreakEvenReturnCalculator().calculate(
        input(
          loanInput: loan(rate: '0'),
          expenseRatio: '1',
        ),
        calculatedAt: calculatedAt,
      );

      expect(result.value.breakEvenNetAnnualReturn.isZero, isTrue);
      expect(result.value.breakEvenGrossAnnualReturn.isPositive, isTrue);
      expect(
        (result.value.breakEvenGrossAnnualReturn.percent -
                Decimal.parse('1.010101010101'))
            .abs(),
        lessThan(Decimal.parse('0.000000001')),
      );
    });

    test('requires investment gain to equal actual interest saved', () {
      final result = const BreakEvenReturnCalculator()
          .calculate(input(expenseRatio: '0'), calculatedAt: calculatedAt)
          .value;

      expect(result.requiredInvestmentGain, result.interestSaved);
      expect(
        result.requiredFutureValue,
        result.investedAmount + result.interestSaved,
      );
    });

    test('higher fees raise the required gross return', () {
      const calculator = BreakEvenReturnCalculator();
      final noFee = calculator.calculate(
        input(expenseRatio: '0'),
        calculatedAt: calculatedAt,
      );
      final highFee = calculator.calculate(
        input(expenseRatio: '2'),
        calculatedAt: calculatedAt,
      );

      expect(
        highFee.value.breakEvenGrossAnnualReturn.compareTo(
          noFee.value.breakEvenGrossAnnualReturn,
        ),
        greaterThan(0),
      );
      expect(
        highFee.value.breakEvenNetAnnualReturn,
        noFee.value.breakEvenNetAnnualReturn,
      );
    });

    test(
      'break-even rate reconciles through OPT-001 within one minor unit',
      () {
        final assumptions = input();
        final threshold = const BreakEvenReturnCalculator().calculate(
          assumptions,
          calculatedAt: calculatedAt,
        );
        final comparison = const OpportunityCostCalculator().calculate(
          OpportunityCostInput(
            loan: assumptions.loan,
            extraCash: assumptions.extraCash,
            decisionInstallment: assumptions.decisionInstallment,
            grossAnnualInvestmentReturn:
                threshold.value.breakEvenGrossAnnualReturn,
            annualExpenseRatio: assumptions.annualExpenseRatio,
          ),
          calculatedAt: calculatedAt,
        );

        expect(
          comparison.value.nominalAdvantage.amount.abs(),
          lessThanOrEqualTo(Decimal.parse('0.01')),
        );
      },
    );

    test('rejects final-installment and fully unapplied decisions', () {
      expect(
        () => const BreakEvenReturnCalculator().calculate(
          input(installment: 24),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => const BreakEvenReturnCalculator().calculate(
          input(extraCash: '1000000', installment: 24),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('uses only the prepayment amount actually accepted', () {
      final result = const BreakEvenReturnCalculator().calculate(
        input(extraCash: '1000000'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.investedAmount,
        result.value.loanPrepayment.appliedPrepayment,
      );
      expect(
        result.value.loanPrepayment.unappliedPrepayment.isPositive,
        isTrue,
      );
      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-002-PARTIAL-PREPAYMENT'),
      );
    });

    test('preserves another currency', () {
      final result = const BreakEvenReturnCalculator().calculate(
        input(loanInput: loan(currency: Currencies.usd)),
        calculatedAt: calculatedAt,
      );

      expect(result.value.investedAmount.currency, Currencies.usd);
      expect(result.value.requiredFutureValue.currency, Currencies.usd);
    });

    test('adds high-expense warning', () {
      final result = const BreakEvenReturnCalculator().calculate(
        input(expenseRatio: '2'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-002-HIGH-EXPENSE-RATIO'),
      );
    });

    test('returns transparent OPT-002 metadata and limitations', () {
      final result = const BreakEvenReturnCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'OPT-002');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(
        result.metadata.assumptions['comparisonTarget'],
        'investmentGainEqualsInterestSaved',
      );
      expect(result.metadata.assumptions['taxesIncluded'], isFalse);
      expect(result.metadata.assumptions['cashFlowTimingNormalized'], isFalse);
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-002-THRESHOLD-NOT-FORECAST',
          'OPT-002-TIMING-NOT-NORMALIZED',
          'OPT-002-TAX-INFLATION-RISK-EXCLUDED',
        ]),
      );
    });

    test('supports result value semantics and deterministic calculation', () {
      const calculator = BreakEvenReturnCalculator();
      final value = input();
      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);
      final copy = first.value.copyWith();

      expect(first, second);
      expect(copy, first.value);
      expect(copy.hashCode, first.value.hashCode);
      expect(copy.toString(), contains('breakEvenGrossAnnualReturn'));
    });
  });
}
