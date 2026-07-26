import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 26, 14);

  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  LoanInput loan({
    String principal = '1000000',
    String rate = '10',
    int months = 120,
  }) {
    return LoanInput(
      principal: inr(principal),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: months,
    );
  }

  PrepaymentPlan plan(Map<int, String> values) {
    return PrepaymentPlan(
      values.entries.map(
        (entry) => ScheduledPrepayment(
          installmentNumber: entry.key,
          amount: inr(entry.value),
        ),
      ),
    );
  }

  group('scheduled amortization', () {
    test('applies a prepayment after the scheduled installment', () {
      final result = const AmortizationCalculator().calculate(
        loan(months: 24),
        calculatedAt: calculatedAt,
        prepaymentPlan: plan(<int, String>{6: '100000'}),
      );
      final sixth = result.value.entries[5];

      expect(sixth.prepayment, inr('100000'));
      expect(
        sixth.openingBalance,
        sixth.principal + sixth.prepayment + sixth.closingBalance,
      );
      expect(sixth.payment, sixth.interest + sixth.principal);
    });

    test('combines multiple prepayments in the same installment', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(months: 24),
            calculatedAt: calculatedAt,
            prepaymentPlan: PrepaymentPlan(<ScheduledPrepayment>[
              ScheduledPrepayment(installmentNumber: 3, amount: inr('10000')),
              ScheduledPrepayment(installmentNumber: 3, amount: inr('15000')),
            ]),
          )
          .value;

      expect(schedule.entries[2].prepayment, inr('25000'));
      expect(schedule.totalPrepayment, inr('25000'));
    });

    test('caps an excessive prepayment at remaining balance', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(principal: '10000', months: 12),
            calculatedAt: calculatedAt,
            prepaymentPlan: plan(<int, String>{1: '100000'}),
          )
          .value;

      expect(schedule.paymentCount, 1);
      expect(schedule.closingBalance, inr('0'));
      expect(schedule.totalPrepayment.compareTo(inr('100000')), lessThan(0));
    });

    test('stops immediately after early payoff', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(months: 120),
            calculatedAt: calculatedAt,
            prepaymentPlan: plan(<int, String>{12: '1000000'}),
          )
          .value;

      expect(schedule.paymentCount, 12);
      expect(schedule.entries.last.installmentNumber, 12);
      expect(schedule.entries.last.closingBalance, inr('0'));
    });

    test('ignores future plan events after the loan closes', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(months: 120),
            calculatedAt: calculatedAt,
            prepaymentPlan: plan(<int, String>{12: '1000000', 24: '50000'}),
          )
          .value;

      expect(schedule.paymentCount, 12);
      expect(schedule.totalPrepayment.compareTo(inr('1050000')), lessThan(0));
    });

    test('preserves the scheduled EMI before early closure', () {
      final input = loan(months: 120);
      final baseline = const AmortizationCalculator()
          .calculate(input, calculatedAt: calculatedAt)
          .value;
      final strategy = const AmortizationCalculator()
          .calculate(
            input,
            calculatedAt: calculatedAt,
            prepaymentPlan: plan(<int, String>{12: '100000'}),
          )
          .value;

      expect(strategy.scheduledEmi, baseline.scheduledEmi);
      expect(strategy.entries.first.payment, baseline.entries.first.payment);
    });

    test('rejects a prepayment beyond contractual tenure', () {
      expect(
        () => const AmortizationCalculator().calculate(
          loan(months: 12),
          calculatedAt: calculatedAt,
          prepaymentPlan: plan(<int, String>{13: '100'}),
        ),
        throwsArgumentError,
      );
    });

    test('records applied prepayment metadata', () {
      final result = const AmortizationCalculator().calculate(
        loan(months: 24),
        calculatedAt: calculatedAt,
        prepaymentPlan: plan(<int, String>{6: '10000'}),
      );

      expect(result.metadata.details['totalPrepayment'], '10000');
      expect(result.metadata.assumptions['prepaymentEffect'], 'reduceTenure');
      expect(
        result.metadata.assumptions['prepaymentTiming'],
        'afterScheduledInstallment',
      );
    });
  });

  group('PrepaymentCalculator', () {
    test('calculates positive interest savings', () {
      final result = const PrepaymentCalculator().calculate(
        loan(),
        prepaymentPlan: plan(<int, String>{12: '100000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.interestSaved.isPositive, isTrue);
      expect(
        result.value.strategy.totalInterest.compareTo(
          result.value.baseline.totalInterest,
        ),
        lessThan(0),
      );
    });

    test('calculates reduced tenure and early closure', () {
      final result = const PrepaymentCalculator().calculate(
        loan(),
        prepaymentPlan: plan(<int, String>{12: '250000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.installmentsReduced, greaterThan(0));
      expect(result.value.closesEarly, isTrue);
      expect(
        result.value.strategy.paymentCount,
        lessThan(result.value.baseline.paymentCount),
      );
    });

    test('reports requested, applied, and unapplied amounts', () {
      final result = const PrepaymentCalculator().calculate(
        loan(principal: '10000', months: 12),
        prepaymentPlan: plan(<int, String>{1: '100000', 2: '50000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.requestedPrepayment, inr('150000'));
      expect(
        result.value.appliedPrepayment.compareTo(inr('10000')),
        lessThan(0),
      );
      expect(result.value.unappliedPrepayment.isPositive, isTrue);
      expect(
        result.value.requestedPrepayment,
        result.value.appliedPrepayment + result.value.unappliedPrepayment,
      );
    });

    test('empty plan matches baseline without savings', () {
      final result = const PrepaymentCalculator().calculate(
        loan(),
        prepaymentPlan: PrepaymentPlan.empty(),
        calculatedAt: calculatedAt,
      );

      expect(result.value.strategy, result.value.baseline);
      expect(result.value.interestSaved, Money.zero(Currencies.inr));
      expect(result.value.installmentsReduced, 0);
      expect(result.value.closesEarly, isFalse);
    });

    test('preserves principal reconciliation after multiple events', () {
      final result = const PrepaymentCalculator().calculate(
        loan(),
        prepaymentPlan: plan(<int, String>{
          12: '50000',
          24: '50000',
          36: '50000',
        }),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.strategy.totalPrincipal,
        result.value.strategy.financedPrincipal,
      );
      expect(result.value.strategy.closingBalance, inr('0'));
    });

    test('supports a zero-interest loan without artificial savings', () {
      final result = const PrepaymentCalculator().calculate(
        loan(principal: '1200', rate: '0', months: 12),
        prepaymentPlan: plan(<int, String>{3: '300'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.interestSaved, inr('0'));
      expect(result.value.installmentsReduced, greaterThan(0));
      expect(result.value.strategy.totalPayment, inr('1200'));
    });

    test('returns transparent LN-003 metadata', () {
      final result = const PrepaymentCalculator().calculate(
        loan(),
        prepaymentPlan: plan(<int, String>{12: '100000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'LN-003');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.details['amortizationFormulaId'], 'LN-002');
      expect(result.metadata.details['installmentsReduced'], greaterThan(0));
      expect(result.metadata.assumptions['prepaymentEffect'], 'reduceTenure');
    });

    test('is deterministic', () {
      final input = loan();
      final prepayments = plan(<int, String>{12: '100000'});
      const calculator = PrepaymentCalculator();

      final first = calculator.calculate(
        input,
        prepaymentPlan: prepayments,
        calculatedAt: calculatedAt,
      );
      final second = calculator.calculate(
        input,
        prepaymentPlan: prepayments,
        calculatedAt: calculatedAt,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
