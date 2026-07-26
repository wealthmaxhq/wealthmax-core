import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 26, 18);

  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  LoanInput loan({
    String principal = '1000000',
    String rate = '10',
    int months = 120,
    String? initialPrepayment,
  }) {
    return LoanInput(
      principal: inr(principal),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: months,
      prepayment: initialPrepayment == null ? null : inr(initialPrepayment),
    );
  }

  EmiChangePlan changes(Map<int, String> values) {
    return EmiChangePlan(
      values.entries.map(
        (entry) => ScheduledEmiChange(
          effectiveInstallment: entry.key,
          newEmi: inr(entry.value),
        ),
      ),
    );
  }

  PrepaymentPlan prepayments(Map<int, String> values) {
    return PrepaymentPlan(
      values.entries.map(
        (entry) => ScheduledPrepayment(
          installmentNumber: entry.key,
          amount: inr(entry.value),
        ),
      ),
    );
  }

  group('EmiChangeCalculator', () {
    test('empty plan matches baseline exactly', () {
      final result = const EmiChangeCalculator().calculate(
        loan(),
        emiChangePlan: EmiChangePlan.empty(),
        calculatedAt: calculatedAt,
      );

      expect(result.value.strategy, result.value.baseline);
      expect(result.value.installmentDifference, 0);
      expect(result.value.interestDifference, inr('0'));
      expect(result.value.emiChangeCount, 0);
    });

    test('higher EMI closes earlier and saves interest', () {
      final result = const EmiChangeCalculator().calculate(
        loan(),
        emiChangePlan: changes(<int, String>{13: '20000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.closesEarlier, isTrue);
      expect(result.value.extendsTenure, isFalse);
      expect(result.value.installmentDifference, lessThan(0));
      expect(result.value.interestSaved.isPositive, isTrue);
      expect(result.value.strategy.closingBalance, inr('0'));
    });

    test('lower valid EMI extends tenure and increases interest', () {
      final baseline = const EmiCalculator().calculate(
        loan(),
        calculatedAt: calculatedAt,
      );
      final lowerEmi = (baseline.value.emi.amount * Decimal.parse('0.8'))
          .toString();
      final result = const EmiChangeCalculator().calculate(
        loan(),
        emiChangePlan: changes(<int, String>{13: lowerEmi}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.extendsTenure, isTrue);
      expect(result.value.installmentDifference, greaterThan(0));
      expect(result.value.interestDifference.isPositive, isTrue);
      expect(result.value.strategy.closingBalance, inr('0'));
    });

    test('applies change before payment at effective installment', () {
      final result = const EmiChangeCalculator().calculate(
        loan(),
        emiChangePlan: changes(<int, String>{13: '20000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.strategy.entries[11].payment, isNot(inr('20000')));
      expect(result.value.strategy.entries[12].payment, inr('20000'));
      expect(result.value.periods.last.effectiveInstallment, 13);
    });

    test('supports multiple increases and decreases', () {
      final result = const EmiChangeCalculator().calculate(
        loan(),
        emiChangePlan: changes(<int, String>{
          13: '20000',
          25: '15000',
          37: '25000',
        }),
        calculatedAt: calculatedAt,
      );

      expect(result.value.periods, hasLength(4));
      expect(
        result.value.periods.map((period) => period.effectiveInstallment),
        <int>[1, 13, 25, 37],
      );
      expect(result.value.strategy.closingBalance, inr('0'));
    });

    test('rejects an EMI that does not cover interest', () {
      expect(
        () => const EmiChangeCalculator().calculate(
          loan(),
          emiChangePlan: changes(<int, String>{2: '100'}),
          calculatedAt: calculatedAt,
        ),
        throwsStateError,
      );
    });

    test('enforces maximum installment safety limit', () {
      expect(
        () => const EmiChangeCalculator(maxInstallments: 121).calculate(
          loan(),
          emiChangePlan: changes(<int, String>{2: '9000'}),
          calculatedAt: calculatedAt,
        ),
        throwsStateError,
      );
    });

    test('rejects a calculation limit below contractual tenure', () {
      expect(
        () => const EmiChangeCalculator(maxInstallments: 119).calculate(
          loan(),
          emiChangePlan: EmiChangePlan.empty(),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('integrates scheduled prepayments', () {
      final result = const EmiChangeCalculator().calculate(
        loan(),
        emiChangePlan: changes(<int, String>{13: '15000'}),
        prepaymentPlan: prepayments(<int, String>{24: '100000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.strategy.totalPrepayment, inr('100000'));
      expect(result.value.strategy.closingBalance, inr('0'));
      expect(result.value.strategy.totalPrincipal, inr('1000000'));
    });

    test('stops before applying future EMI changes after closure', () {
      final result = const EmiChangeCalculator().calculate(
        loan(),
        emiChangePlan: changes(<int, String>{13: '100000', 100: '20000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.strategy.paymentCount, lessThan(100));
      expect(result.value.periods, hasLength(2));
    });

    test('supports fully prepaid input', () {
      final result = const EmiChangeCalculator().calculate(
        loan(principal: '1000', months: 12, initialPrepayment: '1000'),
        emiChangePlan: changes(<int, String>{2: '100'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.strategy.entries, isEmpty);
      expect(result.value.periods.single.scheduledEmi, inr('0'));
    });

    test('preserves another currency', () {
      final input = LoanInput(
        principal: Money.parse('100000', currency: Currencies.usd),
        annualInterestRate: Percentage.fromPercent('8'),
        tenureMonths: 24,
      );
      final plan = EmiChangePlan(<ScheduledEmiChange>[
        ScheduledEmiChange(
          effectiveInstallment: 13,
          newEmi: Money.parse('6000', currency: Currencies.usd),
        ),
      ]);
      final result = const EmiChangeCalculator().calculate(
        input,
        emiChangePlan: plan,
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.strategy.entries.every(
          (entry) => entry.payment.currency == Currencies.usd,
        ),
        isTrue,
      );
    });

    test('returns transparent LN-005 metadata', () {
      final result = const EmiChangeCalculator().calculate(
        loan(),
        emiChangePlan: changes(<int, String>{13: '20000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'LN-005');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.details['appliedEmiPeriods'], hasLength(2));
      expect(result.metadata.assumptions['emiChangeEffect'], 'changeTenure');
    });

    test('is deterministic', () {
      final input = loan();
      final plan = changes(<int, String>{13: '20000'});
      const calculator = EmiChangeCalculator();

      final first = calculator.calculate(
        input,
        emiChangePlan: plan,
        calculatedAt: calculatedAt,
      );
      final second = calculator.calculate(
        input,
        emiChangePlan: plan,
        calculatedAt: calculatedAt,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
