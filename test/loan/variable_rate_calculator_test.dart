import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 26, 16);

  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  LoanInput loan({
    String principal = '1000000',
    String rate = '8',
    int months = 120,
  }) {
    return LoanInput(
      principal: inr(principal),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: months,
    );
  }

  InterestRatePlan rates(Map<int, String> values) {
    return InterestRatePlan(
      values.entries.map(
        (entry) => InterestRateChange(
          effectiveInstallment: entry.key,
          annualInterestRate: Percentage.fromPercent(entry.value),
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

  group('VariableRateCalculator', () {
    test('empty rate plan matches the fixed-rate schedule', () {
      final input = loan(months: 24);
      final fixed = const AmortizationCalculator()
          .calculate(input, calculatedAt: calculatedAt)
          .value;
      final variable = const VariableRateCalculator()
          .calculate(
            input,
            interestRatePlan: InterestRatePlan.empty(),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(variable.schedule, fixed);
      expect(variable.periods, hasLength(1));
      expect(variable.emiChangeCount, 0);
    });

    test('rate increase raises EMI while retaining tenure', () {
      final result = const VariableRateCalculator().calculate(
        loan(months: 24),
        interestRatePlan: rates(<int, String>{13: '12'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.periods, hasLength(2));
      expect(
        result.value.finalPeriod.scheduledEmi.compareTo(
          result.value.initialPeriod.scheduledEmi,
        ),
        greaterThan(0),
      );
      expect(result.value.schedule.paymentCount, 24);
      expect(result.value.schedule.closingBalance, inr('0'));
    });

    test('rate decrease lowers EMI while retaining tenure', () {
      final result = const VariableRateCalculator().calculate(
        loan(rate: '12', months: 24),
        interestRatePlan: rates(<int, String>{13: '6'}),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.finalPeriod.scheduledEmi.compareTo(
          result.value.initialPeriod.scheduledEmi,
        ),
        lessThan(0),
      );
      expect(result.value.schedule.paymentCount, 24);
    });

    test('applies new rate before interest for effective installment', () {
      final result = const VariableRateCalculator().calculate(
        loan(months: 24),
        interestRatePlan: rates(<int, String>{13: '12'}),
        calculatedAt: calculatedAt,
      );
      final thirteenth = result.value.schedule.entries[12];
      final expectedInterest = RoundingPolicy.halfUp.round(
        (thirteenth.openingBalance.amount *
                Percentage.fromPercent('12').fraction /
                Decimal.fromInt(12))
            .toDecimal(scaleOnInfinitePrecision: 32),
        decimalPlaces: 2,
      );

      expect(thirteenth.interest.amount, expectedInterest);
      expect(thirteenth.payment, result.value.finalPeriod.scheduledEmi);
    });

    test('supports multiple rate changes', () {
      final result = const VariableRateCalculator().calculate(
        loan(months: 36),
        interestRatePlan: rates(<int, String>{13: '10', 25: '7'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.periods, hasLength(3));
      expect(
        result.value.periods.map((period) => period.effectiveInstallment),
        <int>[1, 13, 25],
      );
      expect(result.value.emiChangeCount, 2);
      expect(result.value.schedule.paymentCount, 36);
    });

    test('supports transition to zero interest', () {
      final result = const VariableRateCalculator().calculate(
        loan(months: 24),
        interestRatePlan: rates(<int, String>{13: '0'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.finalPeriod.annualInterestRate.isZero, isTrue);
      expect(
        result.value.schedule.entries
            .skip(12)
            .every((entry) => entry.interest.isZero),
        isTrue,
      );
      expect(result.value.schedule.closingBalance, inr('0'));
    });

    test('integrates scheduled prepayments and early closure', () {
      final result = const VariableRateCalculator().calculate(
        loan(),
        interestRatePlan: rates(<int, String>{13: '10', 25: '7'}),
        prepaymentPlan: prepayments(<int, String>{30: '500000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.schedule.paymentCount, lessThan(120));
      expect(result.value.schedule.totalPrepayment.isPositive, isTrue);
      expect(result.value.schedule.closingBalance, inr('0'));
    });

    test('a later rate reset absorbs earlier prepayment into lower EMI', () {
      final input = loan();
      final ratePlan = rates(<int, String>{13: '10'});
      final withoutPrepayment = const VariableRateCalculator().calculate(
        input,
        interestRatePlan: ratePlan,
        calculatedAt: calculatedAt,
      );
      final withPrepayment = const VariableRateCalculator().calculate(
        input,
        interestRatePlan: ratePlan,
        prepaymentPlan: prepayments(<int, String>{12: '250000'}),
        calculatedAt: calculatedAt,
      );

      expect(
        withPrepayment.value.finalPeriod.scheduledEmi.compareTo(
          withoutPrepayment.value.finalPeriod.scheduledEmi,
        ),
        lessThan(0),
      );
      expect(withPrepayment.value.schedule.paymentCount, 120);
    });

    test('does not apply a future rate change after early closure', () {
      final result = const VariableRateCalculator().calculate(
        loan(),
        interestRatePlan: rates(<int, String>{13: '10', 100: '7'}),
        prepaymentPlan: prepayments(<int, String>{12: '1000000'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.schedule.paymentCount, 12);
      expect(result.value.periods, hasLength(1));
    });

    test('supports full initial prepayment with an empty schedule', () {
      final input = LoanInput(
        principal: inr('1000'),
        annualInterestRate: Percentage.fromPercent('8'),
        tenureMonths: 12,
        prepayment: inr('1000'),
      );
      final result = const VariableRateCalculator().calculate(
        input,
        interestRatePlan: rates(<int, String>{6: '10'}),
        calculatedAt: calculatedAt,
      );

      expect(result.value.schedule.entries, isEmpty);
      expect(result.value.initialPeriod.scheduledEmi, inr('0'));
      expect(result.value.periods, hasLength(1));
    });

    test('rejects a rate change beyond contractual tenure', () {
      expect(
        () => const VariableRateCalculator().calculate(
          loan(months: 12),
          interestRatePlan: rates(<int, String>{13: '10'}),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('preserves another currency across recalculations', () {
      final input = LoanInput(
        principal: Money.parse('100000', currency: Currencies.usd),
        annualInterestRate: Percentage.fromPercent('8'),
        tenureMonths: 24,
      );
      final result = const VariableRateCalculator().calculate(
        input,
        interestRatePlan: rates(<int, String>{13: '10'}),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.periods.every(
          (period) => period.scheduledEmi.currency == Currencies.usd,
        ),
        isTrue,
      );
      expect(
        result.value.schedule.entries.every(
          (entry) => entry.payment.currency == Currencies.usd,
        ),
        isTrue,
      );
    });

    test('returns transparent LN-004 metadata', () {
      final result = const VariableRateCalculator().calculate(
        loan(months: 24),
        interestRatePlan: rates(<int, String>{13: '10'}),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'LN-004');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.details['emiFormulaId'], 'LN-001');
      expect(result.metadata.details['appliedRatePeriods'], hasLength(2));
      expect(
        result.metadata.assumptions['rateChangeEffect'],
        'recalculateEmiKeepRemainingTenure',
      );
    });

    test('is deterministic', () {
      final input = loan(months: 36);
      final plan = rates(<int, String>{13: '10', 25: '7'});
      const calculator = VariableRateCalculator();

      final first = calculator.calculate(
        input,
        interestRatePlan: plan,
        calculatedAt: calculatedAt,
      );
      final second = calculator.calculate(
        input,
        interestRatePlan: plan,
        calculatedAt: calculatedAt,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
