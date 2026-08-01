import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 26, 10);

  LoanInput loan({
    required String principal,
    required String rate,
    required int months,
    String? fee,
    String? prepayment,
  }) {
    return LoanInput(
      principal: Money.parse(principal, currency: Currencies.inr),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: months,
      processingFee: fee == null
          ? null
          : Money.parse(fee, currency: Currencies.inr),
      prepayment: prepayment == null
          ? null
          : Money.parse(prepayment, currency: Currencies.inr),
    );
  }

  group('EmiCalculator', () {
    test('calculates a standard 20-year loan', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '1000000', rate: '10', months: 240),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.emi,
        Money.parse('9650.22', currency: Currencies.inr),
      );
      expect(
        result.value.totalPayment,
        Money.parse('2316050', currency: Currencies.inr),
      );
      expect(
        result.value.totalInterest,
        Money.parse('1316050', currency: Currencies.inr),
      );
    });

    test('calculates a standard home loan regression case', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '5000000', rate: '8.5', months: 240),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.emi,
        Money.parse('43391.16', currency: Currencies.inr),
      );
    });

    test('handles a zero-interest loan', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '1200', rate: '0', months: 12),
        calculatedAt: calculatedAt,
      );

      expect(result.value.emi, Money.parse('100', currency: Currencies.inr));
      expect(
        result.value.totalPayment,
        Money.parse('1200', currency: Currencies.inr),
      );
      expect(result.value.totalInterest, Money.zero(Currencies.inr));
    });

    test('rounds a repeating zero-interest payment explicitly', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '1000', rate: '0', months: 3),
        calculatedAt: calculatedAt,
      );

      expect(result.value.emi, Money.parse('333.33', currency: Currencies.inr));
      expect(
        result.value.totalPayment,
        Money.parse('1000', currency: Currencies.inr),
      );
      expect(result.value.totalInterest, Money.zero(Currencies.inr));
    });

    test('handles a one-month loan', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '1000', rate: '12', months: 1),
        calculatedAt: calculatedAt,
      );

      expect(result.value.emi, Money.parse('1010', currency: Currencies.inr));
      expect(
        result.value.totalInterest,
        Money.parse('10', currency: Currencies.inr),
      );
    });

    test('applies prepayment before calculating EMI', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '100000', rate: '12', months: 12, prepayment: '10000'),
        calculatedAt: calculatedAt,
      );

      final withoutPrepayment = const EmiCalculator().calculate(
        loan(principal: '100000', rate: '12', months: 12),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.emi.compareTo(withoutPrepayment.value.emi),
        lessThan(0),
      );
      expect(result.metadata.details['financedPrincipal'], '90000');
    });

    test('returns zero values when prepayment equals principal', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '1000', rate: '12', months: 12, prepayment: '1000'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.emi, Money.zero(Currencies.inr));
      expect(result.value.totalInterest, Money.zero(Currencies.inr));
      expect(result.value.totalPayment, Money.zero(Currencies.inr));
    });

    test('processing fee does not change scheduled EMI', () {
      final base = const EmiCalculator().calculate(
        loan(principal: '100000', rate: '10', months: 24),
        calculatedAt: calculatedAt,
      );
      final withFee = const EmiCalculator().calculate(
        loan(principal: '100000', rate: '10', months: 24, fee: '2500'),
        calculatedAt: calculatedAt,
      );

      expect(withFee.value, base.value);
      expect(withFee.metadata.inputs['processingFee'], '2500');
    });

    test('preserves the input currency', () {
      final input = LoanInput(
        principal: Money.parse('10000', currency: Currencies.usd),
        annualInterestRate: Percentage.fromPercent('6'),
        tenureMonths: 12,
      );

      final result = const EmiCalculator().calculate(
        input,
        calculatedAt: calculatedAt,
      );

      expect(result.value.emi.currency, Currencies.usd);
      expect(result.value.totalInterest.currency, Currencies.usd);
      expect(result.value.totalPayment.currency, Currencies.usd);
    });

    test('uses the currency decimal places', () {
      final input = LoanInput(
        principal: Money.parse('100000', currency: Currencies.eur),
        annualInterestRate: Percentage.fromPercent('5'),
        tenureMonths: 12,
      );

      final result = const EmiCalculator().calculate(
        input,
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.emi.amount,
        RoundingPolicy.halfUp.round(
          result.value.emi.amount,
          decimalPlaces: Currencies.eur.decimalPlaces,
        ),
      );
    });

    test('honors an alternative rounding policy', () {
      final input = loan(principal: '1000', rate: '0', months: 3);

      final halfUp = const EmiCalculator().calculate(
        input,
        calculatedAt: calculatedAt,
      );
      final ceiling = const EmiCalculator(
        roundingPolicy: RoundingPolicy.ceiling,
      ).calculate(input, calculatedAt: calculatedAt);

      expect(halfUp.value.emi, Money.parse('333.33', currency: Currencies.inr));
      expect(
        ceiling.value.emi,
        Money.parse('333.34', currency: Currencies.inr),
      );
    });

    test('returns LN-001 formula metadata', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '100000', rate: '10', months: 12),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'LN-001');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.inputs['principal'], '100000');
      expect(result.metadata.inputs['annualInterestRatePercent'], '10');
      expect(result.metadata.inputs['tenureMonths'], 12);
    });

    test('records transparent assumptions and calculation details', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '100000', rate: '10', months: 12),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.assumptions['repaymentFrequency'], 'monthly');
      expect(result.metadata.assumptions['interestMethod'], 'reducingBalance');
      expect(result.metadata.assumptions['roundingPolicy'], 'halfUp');
      expect(result.metadata.details['calculationScale'], 32);
      expect(result.metadata.details['financedPrincipal'], '100000');
    });

    test('normalizes the audit timestamp to UTC', () {
      final localTimestamp = DateTime(2026, 7, 26, 15, 30);
      final result = const EmiCalculator().calculate(
        loan(principal: '1000', rate: '0', months: 1),
        calculatedAt: localTimestamp,
      );

      expect(result.metadata.calculatedAt.isUtc, isTrue);
      expect(result.metadata.calculatedAt, localTimestamp.toUtc());
    });

    test('produces no warnings for a valid deterministic calculation', () {
      final result = const EmiCalculator().calculate(
        loan(principal: '100000', rate: '10', months: 12),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings, isEmpty);
      expect(result.hasWarnings, isFalse);
    });

    test('is deterministic for identical inputs and timestamp', () {
      final input = loan(principal: '750000', rate: '9.25', months: 84);
      const calculator = EmiCalculator();

      final first = calculator.calculate(input, calculatedAt: calculatedAt);
      final second = calculator.calculate(input, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('reconciles totals with the rounded amortization schedule', () {
      final input = loan(principal: '1000000', rate: '10', months: 240);

      final summary = const EmiCalculator().calculate(
        input,
        calculatedAt: calculatedAt,
      );
      final schedule = const AmortizationCalculator().calculate(
        input,
        calculatedAt: calculatedAt,
      );

      expect(summary.value.emi, schedule.value.scheduledEmi);
      expect(summary.value.totalInterest, schedule.value.totalInterest);
      expect(summary.value.totalPayment, schedule.value.totalPayment);
      expect(
        summary.metadata.details['paymentCount'],
        schedule.value.paymentCount,
      );
      expect(summary.metadata.details['finalPaymentAdjustment'], isTrue);
    });

    test('validates calculation scale at runtime', () {
      const calculator = EmiCalculator(calculationScale: 0);

      expect(
        () => calculator.calculate(
          loan(principal: '1000', rate: '10', months: 12),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });
  });
}
