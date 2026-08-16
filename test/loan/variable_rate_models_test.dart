import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);
  Money usd(String value) => Money.parse(value, currency: Currencies.usd);

  VariableRatePeriod period({
    int month = 1,
    String rate = '8',
    String emi = '100',
  }) {
    return VariableRatePeriod(
      effectiveInstallment: month,
      annualInterestRate: Percentage.fromPercent(rate),
      scheduledEmi: inr(emi),
    );
  }

  AmortizationSchedule schedule() {
    return AmortizationSchedule(
      scheduledEmi: inr('100'),
      financedPrincipal: inr('100'),
      entries: <AmortizationEntry>[
        AmortizationEntry(
          installmentNumber: 1,
          openingBalance: inr('100'),
          payment: inr('100'),
          interest: inr('0'),
          principal: inr('100'),
          closingBalance: inr('0'),
        ),
      ],
    );
  }

  group('VariableRatePeriod', () {
    test('stores rate and recalculated EMI', () {
      final value = period(month: 13, rate: '9', emi: '110');

      expect(value.effectiveInstallment, 13);
      expect(value.annualInterestRate, Percentage.fromPercent('9'));
      expect(value.scheduledEmi, inr('110'));
    });

    test('rejects a non-positive installment', () {
      expect(() => period(month: 0), throwsArgumentError);
    });

    test('rejects a negative rate', () {
      expect(() => period(rate: '-1'), throwsArgumentError);
    });

    test('rejects a negative EMI', () {
      expect(() => period(emi: '-1'), throwsArgumentError);
    });

    test('supports value equality and deterministic output', () {
      expect(period(), period());
      expect(period().hashCode, period().hashCode);
      expect(
        period().toString(),
        'VariableRatePeriod(effectiveInstallment: 1, '
        'annualInterestRate: 8%, scheduledEmi: INR 100)',
      );
    });
  });

  group('VariableRateLoanResult', () {
    test('stores and freezes applied periods', () {
      final source = <VariableRatePeriod>[period()];
      final result = VariableRateLoanResult(
        schedule: schedule(),
        periods: source,
      );

      source.clear();

      expect(result.periods, hasLength(1));
      expect(() => result.periods.add(period()), throwsUnsupportedError);
      expect(result.emiChangeCount, 0);
      expect(result.initialPeriod, result.finalPeriod);
    });

    test('rejects an empty period list', () {
      expect(
        () => VariableRateLoanResult(
          schedule: schedule(),
          periods: const <VariableRatePeriod>[],
        ),
        throwsArgumentError,
      );
    });

    test('requires first period to start at installment one', () {
      expect(
        () => VariableRateLoanResult(
          schedule: schedule(),
          periods: <VariableRatePeriod>[period(month: 2)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects mixed period currency', () {
      expect(
        () => VariableRateLoanResult(
          schedule: schedule(),
          periods: <VariableRatePeriod>[
            VariableRatePeriod(
              effectiveInstallment: 1,
              annualInterestRate: Percentage.fromPercent('8'),
              scheduledEmi: usd('100'),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-increasing period installments', () {
      expect(
        () => VariableRateLoanResult(
          schedule: schedule(),
          periods: <VariableRatePeriod>[period(), period()],
        ),
        throwsArgumentError,
      );
    });

    test('supports deep value equality and hash codes', () {
      VariableRateLoanResult build() => VariableRateLoanResult(
        schedule: schedule(),
        periods: <VariableRatePeriod>[period()],
      );

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });
  });
}
