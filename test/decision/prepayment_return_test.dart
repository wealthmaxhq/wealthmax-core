import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 7, 12);

  LoanInput loan({String rate = '12', Currency currency = Currencies.inr}) {
    return LoanInput(
      principal: Money.parse('100000', currency: currency),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: 24,
    );
  }

  PrepaymentReturnInput input({
    LoanInput? loanInput,
    String extraCash = '10000',
    int installment = 1,
  }) {
    final selectedLoan = loanInput ?? loan();
    return PrepaymentReturnInput(
      loan: selectedLoan,
      extraCash: Money.parse(
        extraCash,
        currency: selectedLoan.principal.currency,
      ),
      decisionInstallment: installment,
    );
  }

  group('PrepaymentReturnInput', () {
    test('validates cash, currency, and installment', () {
      expect(input().decisionInstallment, 1);
      expect(() => input(extraCash: '0'), throwsArgumentError);
      expect(() => input(installment: 0), throwsArgumentError);
      expect(() => input(installment: 25), throwsArgumentError);
      expect(
        () => PrepaymentReturnInput(
          loan: loan(),
          extraCash: Money.parse('100', currency: Currencies.usd),
          decisionInstallment: 1,
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

  group('PrepaymentReturnCalculator', () {
    test('zero-interest loan produces a zero effective return', () {
      final result = const PrepaymentReturnCalculator().calculate(
        input(loanInput: loan(rate: '0')),
        calculatedAt: calculatedAt,
      );

      expect(result.value.monthlyReturn.isZero, isTrue);
      expect(result.value.effectiveAnnualReturn.isZero, isTrue);
      expect(result.value.netCashFlowTotal.isZero, isTrue);
    });

    test('fixed-rate prepayment return approximates loan effective rate', () {
      final result = const PrepaymentReturnCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );
      final expectedEffectivePercent =
          (_pow(Decimal.parse('1.01'), 12) - Decimal.one) *
          Decimal.fromInt(100);

      expect(
        (result.value.monthlyReturn.percent - Decimal.one).abs(),
        lessThan(Decimal.parse('0.01')),
      );
      expect(
        (result.value.effectiveAnnualReturn.percent - expectedEffectivePercent)
            .abs(),
        lessThan(Decimal.parse('0.05')),
      );
    });

    test('incremental cash flows reconcile to nominal interest saved', () {
      final result = const PrepaymentReturnCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      expect(result.netCashFlowTotal, result.loanPrepayment.interestSaved);
      expect(result.cashFlows.first.monthsFromDecision, 0);
      expect(result.cashFlows.first.amount.isNegative, isTrue);
      expect(result.cashFlows.last.amount.isPositive, isTrue);
    });

    test('solved monthly return produces a near-zero NPV', () {
      final result = const PrepaymentReturnCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;
      final growthFactor = Decimal.one + result.monthlyReturn.fraction;
      var npv = Decimal.zero;
      for (final cashFlow in result.cashFlows) {
        npv +=
            (cashFlow.amount.amount /
                    _pow(growthFactor, cashFlow.monthsFromDecision))
                .toDecimal(scaleOnInfinitePrecision: 24);
      }

      expect(npv.abs(), lessThan(Decimal.parse('0.0001')));
    });

    test('cash flows are immutable and ordered', () {
      final result = const PrepaymentReturnCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      expect(
        () => result.cashFlows.add(result.cashFlows.first),
        throwsUnsupportedError,
      );
      for (var index = 1; index < result.cashFlows.length; index++) {
        expect(
          result.cashFlows[index].monthsFromDecision,
          greaterThan(result.cashFlows[index - 1].monthsFromDecision),
        );
      }
    });

    test('rejects a final-installment decision with no future savings', () {
      expect(
        () => const PrepaymentReturnCalculator().calculate(
          input(installment: 24),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('supports partial accepted prepayment', () {
      final result = const PrepaymentReturnCalculator().calculate(
        input(extraCash: '1000000'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.loanPrepayment.unappliedPrepayment.isPositive,
        isTrue,
      );
      expect(result.value.monthlyReturn.isPositive, isTrue);
    });

    test('preserves another currency and configured rounding', () {
      final result =
          const PrepaymentReturnCalculator(
            roundingPolicy: RoundingPolicy.floor,
          ).calculate(
            input(loanInput: loan(currency: Currencies.usd)),
            calculatedAt: calculatedAt,
          );

      expect(result.value.cashFlows.first.amount.currency, Currencies.usd);
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('returns transparent OPT-004 metadata and limitations', () {
      final result = const PrepaymentReturnCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'OPT-004');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(
        result.metadata.assumptions['cashFlowSpacing'],
        'equalMonthlyPeriods',
      );
      expect(result.metadata.assumptions['taxBenefitsIncluded'], isFalse);
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-004-EQUAL-MONTHS-ASSUMED',
          'OPT-004-TAX-PENALTY-EXCLUDED',
        ]),
      );
    });

    test('supports value semantics and deterministic output', () {
      const calculator = PrepaymentReturnCalculator();
      final value = input();
      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.value.hashCode, second.value.hashCode);
      expect(first.value.toString(), contains('effectiveAnnualReturn'));
      expect(first.value.cashFlows.first.toString(), contains('amount'));
    });
  });
}

Decimal _pow(Decimal base, int exponent) {
  var result = Decimal.one;
  for (var index = 0; index < exponent; index++) {
    result *= base;
  }
  return result;
}
