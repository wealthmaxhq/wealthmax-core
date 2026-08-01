import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 26, 12);

  LoanInput loan({
    required String principal,
    required String rate,
    required int months,
    String? prepayment,
  }) {
    return LoanInput(
      principal: Money.parse(principal, currency: Currencies.inr),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: months,
      prepayment: prepayment == null
          ? null
          : Money.parse(prepayment, currency: Currencies.inr),
    );
  }

  group('AmortizationCalculator', () {
    test('validates calculation scale at runtime', () {
      const calculator = AmortizationCalculator(calculationScale: 0);

      expect(
        () => calculator.calculate(
          loan(principal: '1000', rate: '10', months: 12),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('builds a fully reconciled standard schedule', () {
      final result = const AmortizationCalculator().calculate(
        loan(principal: '100000', rate: '12', months: 12),
        calculatedAt: calculatedAt,
      );
      final schedule = result.value;

      expect(schedule.paymentCount, 12);
      expect(schedule.totalPrincipal, schedule.financedPrincipal);
      expect(schedule.closingBalance, Money.zero(Currencies.inr));
      expect(schedule.entries.first.openingBalance.amount.toString(), '100000');
      expect(schedule.entries.last.closingBalance.amount.toString(), '0');
    });

    test('calculates the first installment components exactly', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(principal: '100000', rate: '12', months: 12),
            calculatedAt: calculatedAt,
          )
          .value;
      final first = schedule.entries.first;

      expect(first.interest.amount.toString(), '1000');
      expect(first.payment, schedule.scheduledEmi);
      expect(first.principal, first.payment - first.interest);
      expect(first.closingBalance, first.openingBalance - first.principal);
    });

    test('adjusts the final payment to close the balance exactly', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(principal: '100000', rate: '12', months: 12),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(schedule.finalPayment, isNot(schedule.scheduledEmi));
      expect(schedule.entries.last.closingBalance.isZero, isTrue);
    });

    test('handles exact zero-interest installments', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(principal: '1200', rate: '0', months: 12),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(schedule.paymentCount, 12);
      expect(schedule.totalInterest, Money.zero(Currencies.inr));
      expect(
        schedule.totalPayment,
        Money.parse('1200', currency: Currencies.inr),
      );
      expect(schedule.entries.every((entry) => entry.interest.isZero), isTrue);
    });

    test('corrects repeating zero-interest rounding in final payment', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(principal: '1000', rate: '0', months: 3),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(
        schedule.entries.map((entry) => entry.payment.amount.toString()),
        <String>['333.33', '333.33', '333.34'],
      );
      expect(schedule.totalPayment.amount.toString(), '1000');
      expect(schedule.totalPrincipal.amount.toString(), '1000');
    });

    test('handles a one-month loan', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(principal: '1000', rate: '12', months: 1),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(schedule.paymentCount, 1);
      expect(schedule.entries.single.interest.amount.toString(), '10');
      expect(schedule.entries.single.principal.amount.toString(), '1000');
      expect(schedule.entries.single.payment.amount.toString(), '1010');
    });

    test('uses financed principal after initial prepayment', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(
              principal: '100000',
              rate: '10',
              months: 12,
              prepayment: '10000',
            ),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(schedule.financedPrincipal.amount.toString(), '90000');
      expect(schedule.entries.first.openingBalance.amount.toString(), '90000');
      expect(schedule.totalPrincipal.amount.toString(), '90000');
    });

    test('returns an empty schedule after full initial prepayment', () {
      final schedule = const AmortizationCalculator()
          .calculate(
            loan(principal: '1000', rate: '12', months: 12, prepayment: '1000'),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(schedule.entries, isEmpty);
      expect(schedule.scheduledEmi, Money.zero(Currencies.inr));
      expect(schedule.totalPayment, Money.zero(Currencies.inr));
    });

    test('supports another currency', () {
      final input = LoanInput(
        principal: Money.parse('10000', currency: Currencies.usd),
        annualInterestRate: Percentage.fromPercent('6'),
        tenureMonths: 12,
      );
      final schedule = const AmortizationCalculator()
          .calculate(input, calculatedAt: calculatedAt)
          .value;

      expect(
        schedule.entries.every(
          (entry) => entry.payment.currency == Currencies.usd,
        ),
        isTrue,
      );
      expect(schedule.totalPayment.currency, Currencies.usd);
    });

    test('honors the selected rounding policy', () {
      final input = loan(principal: '1000', rate: '0', months: 3);
      final schedule = const AmortizationCalculator(
        roundingPolicy: RoundingPolicy.ceiling,
      ).calculate(input, calculatedAt: calculatedAt).value;

      expect(
        schedule.entries.map((entry) => entry.payment.amount.toString()),
        <String>['333.34', '333.34', '333.32'],
      );
      expect(schedule.totalPayment.amount.toString(), '1000');
    });

    test('returns transparent LN-002 metadata', () {
      final result = const AmortizationCalculator().calculate(
        loan(principal: '100000', rate: '10', months: 12),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'LN-002');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.details['emiFormulaId'], 'LN-001');
      expect(result.metadata.details['paymentCount'], 12);
      expect(result.metadata.details['totalPrincipal'], '100000');
      expect(result.metadata.assumptions['finalPaymentAdjustment'], isTrue);
    });

    test('is deterministic for identical inputs and timestamps', () {
      final input = loan(principal: '750000', rate: '9.25', months: 84);
      const calculator = AmortizationCalculator();

      final first = calculator.calculate(input, calculatedAt: calculatedAt);
      final second = calculator.calculate(input, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
