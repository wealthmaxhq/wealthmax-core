import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 4, 12);

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

  OpportunityCostInput input({
    LoanInput? loanInput,
    String extraCash = '10000',
    int installment = 1,
    String investmentReturn = '12',
    String expenseRatio = '1',
  }) {
    final selectedLoan = loanInput ?? loan();
    return OpportunityCostInput(
      loan: selectedLoan,
      extraCash: Money.parse(
        extraCash,
        currency: selectedLoan.principal.currency,
      ),
      decisionInstallment: installment,
      grossAnnualInvestmentReturn: Percentage.fromPercent(investmentReturn),
      annualExpenseRatio: Percentage.fromPercent(expenseRatio),
    );
  }

  group('OpportunityCostInput', () {
    test('stores valid decision assumptions', () {
      final value = input();

      expect(value.extraCash.amount, Decimal.fromInt(10000));
      expect(value.decisionInstallment, 1);
      expect(value.grossAnnualInvestmentReturn, Percentage.fromPercent('12'));
    });

    test('rejects non-positive or mixed-currency cash', () {
      expect(() => input(extraCash: '0'), throwsArgumentError);
      expect(
        () => OpportunityCostInput(
          loan: loan(),
          extraCash: Money.parse('100', currency: Currencies.usd),
          decisionInstallment: 1,
          grossAnnualInvestmentReturn: Percentage.fromPercent('10'),
          annualExpenseRatio: Percentage.fromPercent('1'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects installment outside contractual tenure', () {
      expect(() => input(installment: 0), throwsArgumentError);
      expect(() => input(installment: 25), throwsArgumentError);
    });

    test('rejects invalid return and expense assumptions', () {
      expect(() => input(investmentReturn: '-100.01'), throwsArgumentError);
      expect(() => input(expenseRatio: '-0.01'), throwsArgumentError);
      expect(() => input(expenseRatio: '100'), throwsArgumentError);
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

  group('OpportunityCostResult', () {
    test('reports investment preference from positive advantage', () {
      final result = const OpportunityCostCalculator()
          .calculate(
            input(investmentReturn: '50', expenseRatio: '0'),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(result.investmentGain.isPositive, isTrue);
      expect(result.nominalAdvantage.isPositive, isTrue);
      expect(result.preferredOption, OpportunityCostPreference.invest);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final original = const OpportunityCostCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;
      final changed = original.copyWith(
        netAnnualInvestmentReturn: Percentage.fromPercent('9'),
      );
      final expected = original.copyWith(
        netAnnualInvestmentReturn: Percentage.fromPercent('9'),
      );

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('preferredOption'));
    });
  });

  group('OpportunityCostCalculator', () {
    test('prepayment wins when investment has no gain', () {
      final result = const OpportunityCostCalculator().calculate(
        input(investmentReturn: '0', expenseRatio: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.interestSaved.isPositive, isTrue);
      expect(result.value.investmentGain.isZero, isTrue);
      expect(result.value.preferredOption, OpportunityCostPreference.prepay);
    });

    test('zero-rate loan and zero-return investment are equivalent', () {
      final result = const OpportunityCostCalculator().calculate(
        input(
          loanInput: loan(rate: '0'),
          investmentReturn: '0',
          expenseRatio: '0',
        ),
        calculatedAt: calculatedAt,
      );

      expect(result.value.interestSaved.isZero, isTrue);
      expect(result.value.investmentGain.isZero, isTrue);
      expect(
        result.value.preferredOption,
        OpportunityCostPreference.equivalent,
      );
    });

    test('uses the amount actually applied as the investment alternative', () {
      final result = const OpportunityCostCalculator().calculate(
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
        contains('OPT-001-PARTIAL-PREPAYMENT'),
      );
    });

    test('invests from the decision installment to baseline payoff', () {
      final result = const OpportunityCostCalculator().calculate(
        input(installment: 6),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.investmentHorizonMonths,
        result.value.loanPrepayment.baseline.paymentCount - 6,
      );
    });

    test('final-installment decision has no remaining investment horizon', () {
      final result = const OpportunityCostCalculator().calculate(
        input(installment: 24),
        calculatedAt: calculatedAt,
      );

      expect(result.value.investmentHorizonMonths, 0);
      expect(result.value.investedAmount.isZero, isTrue);
      expect(result.value.investmentFutureValue.isZero, isTrue);
      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-001-PARTIAL-PREPAYMENT'),
      );
    });

    test('supports a total investment loss after the decision', () {
      final result = const OpportunityCostCalculator().calculate(
        input(investmentReturn: '-100', expenseRatio: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.investmentFutureValue.isZero, isTrue);
      expect(result.value.investmentGain.isNegative, isTrue);
      expect(result.value.preferredOption, OpportunityCostPreference.prepay);
    });

    test('preserves another currency and configured rounding', () {
      final result =
          const OpportunityCostCalculator(
            roundingPolicy: RoundingPolicy.floor,
          ).calculate(
            input(loanInput: loan(currency: Currencies.usd)),
            calculatedAt: calculatedAt,
          );

      expect(result.value.investmentFutureValue.currency, Currencies.usd);
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('returns transparent OPT-001 metadata and limitations', () {
      final result = const OpportunityCostCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'OPT-001');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(
        result.metadata.assumptions['comparisonHorizon'],
        'baselineLoanPayoff',
      );
      expect(result.metadata.assumptions['taxesIncluded'], isFalse);
      expect(result.metadata.assumptions['cashFlowTimingNormalized'], isFalse);
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-001-PROJECTION-NOT-GUARANTEED',
          'OPT-001-TIMING-NOT-NORMALIZED',
          'OPT-001-TAX-INFLATION-EXCLUDED',
        ]),
      );
    });

    test('is deterministic for identical inputs and timestamp', () {
      const calculator = OpportunityCostCalculator();
      final value = input();

      expect(
        calculator.calculate(value, calculatedAt: calculatedAt),
        calculator.calculate(value, calculatedAt: calculatedAt),
      );
    });
  });
}
