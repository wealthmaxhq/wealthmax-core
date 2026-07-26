import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 28, 10);

  LoanInput loan({
    String principal = '100000',
    String rate = '12',
    int months = 12,
    String? fee,
    String? prepayment,
    Currency currency = Currencies.inr,
  }) {
    return LoanInput(
      principal: Money.parse(principal, currency: currency),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: months,
      processingFee: fee == null ? null : Money.parse(fee, currency: currency),
      prepayment: prepayment == null
          ? null
          : Money.parse(prepayment, currency: currency),
    );
  }

  bool closeTo(Decimal actual, Decimal expected, String tolerance) {
    return (actual - expected).abs() <= Decimal.parse(tolerance);
  }

  group('EffectiveRateCalculator', () {
    test('recovers the nominal rate when no processing fee is charged', () {
      final result = const EffectiveRateCalculator().calculate(
        loan(),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(
          result.value.nominalAnnualPercentageRate.percent,
          Decimal.parse('12'),
          '0.001',
        ),
        isTrue,
      );
    });

    test('derives a compounded annual rate above nominal APR', () {
      final result = const EffectiveRateCalculator().calculate(
        loan(),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.effectiveAnnualRate.compareTo(
          result.value.nominalAnnualPercentageRate,
        ),
        greaterThan(0),
      );
      expect(
        closeTo(
          result.value.effectiveAnnualRate.percent,
          Decimal.parse('12.6825'),
          '0.01',
        ),
        isTrue,
      );
    });

    test('processing fee increases the disclosed annual borrowing cost', () {
      const calculator = EffectiveRateCalculator();
      final withoutFee = calculator.calculate(
        loan(),
        calculatedAt: calculatedAt,
      );
      final withFee = calculator.calculate(
        loan(fee: '2000'),
        calculatedAt: calculatedAt,
      );

      expect(
        withFee.value.nominalAnnualPercentageRate.compareTo(
          withoutFee.value.nominalAnnualPercentageRate,
        ),
        greaterThan(0),
      );
      expect(
        withFee.value.netProceeds,
        Money.parse('98000', currency: Currencies.inr),
      );
    });

    test('includes the fee in finance charge through reduced proceeds', () {
      final withoutFee = const EffectiveRateCalculator().calculate(
        loan(),
        calculatedAt: calculatedAt,
      );
      final withFee = const EffectiveRateCalculator().calculate(
        loan(fee: '2000'),
        calculatedAt: calculatedAt,
      );

      expect(
        withFee.value.financeCharge - withoutFee.value.financeCharge,
        Money.parse('2000', currency: Currencies.inr),
      );
    });

    test('returns zero rates for a zero-interest fee-free loan', () {
      final result = const EffectiveRateCalculator().calculate(
        loan(rate: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.monthlyEffectiveRate.isZero, isTrue);
      expect(result.value.nominalAnnualPercentageRate.isZero, isTrue);
      expect(result.value.effectiveAnnualRate.isZero, isTrue);
      expect(result.value.financeCharge.isZero, isTrue);
    });

    test('a fee creates a positive rate on a zero-interest loan', () {
      final result = const EffectiveRateCalculator().calculate(
        loan(rate: '0', fee: '1000'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.monthlyEffectiveRate.isPositive, isTrue);
      expect(result.value.nominalAnnualPercentageRate.isPositive, isTrue);
      expect(result.value.effectiveAnnualRate.isPositive, isTrue);
    });

    test('uses actual final adjusted payment for repeating division', () {
      final result = const EffectiveRateCalculator().calculate(
        loan(principal: '1000', rate: '0', months: 3),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.totalRepayment,
        Money.parse('1000', currency: Currencies.inr),
      );
      expect(result.value.paymentCount, 3);
      expect(result.value.monthlyEffectiveRate.isZero, isTrue);
    });

    test('supports a one-month loan', () {
      final result = const EffectiveRateCalculator().calculate(
        loan(principal: '1000', rate: '12', months: 1),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(
          result.value.monthlyEffectiveRate.percent,
          Decimal.parse('1'),
          '0.000001',
        ),
        isTrue,
      );
      expect(result.value.paymentCount, 1);
    });

    test('uses financed principal after initial prepayment', () {
      final result = const EffectiveRateCalculator().calculate(
        loan(principal: '100000', prepayment: '10000'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.netProceeds,
        Money.parse('90000', currency: Currencies.inr),
      );
      expect(
        closeTo(
          result.value.nominalAnnualPercentageRate.percent,
          Decimal.parse('12'),
          '0.001',
        ),
        isTrue,
      );
    });

    test('rejects a fully prepaid loan', () {
      expect(
        () => const EffectiveRateCalculator().calculate(
          loan(principal: '1000', prepayment: '1000'),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a fee equal to financed principal', () {
      expect(
        () => const EffectiveRateCalculator().calculate(
          loan(principal: '1000', fee: '1000'),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a fee greater than financed principal', () {
      expect(
        () => const EffectiveRateCalculator().calculate(
          loan(principal: '1000', fee: '1001'),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('preserves another currency', () {
      final result = const EffectiveRateCalculator().calculate(
        loan(currency: Currencies.usd, fee: '500'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.netProceeds.currency, Currencies.usd);
      expect(result.value.totalRepayment.currency, Currencies.usd);
      expect(result.value.financeCharge.currency, Currencies.usd);
    });

    test('honors the selected repayment rounding policy', () {
      final input = loan(principal: '1000', rate: '0', months: 3);
      final halfUp = const EffectiveRateCalculator().calculate(
        input,
        calculatedAt: calculatedAt,
      );
      final ceiling = const EffectiveRateCalculator(
        roundingPolicy: RoundingPolicy.ceiling,
      ).calculate(input, calculatedAt: calculatedAt);

      expect(halfUp.value.totalRepayment, ceiling.value.totalRepayment);
      expect(
        halfUp.value.monthlyEffectiveRate,
        ceiling.value.monthlyEffectiveRate,
      );
    });

    test('returns transparent LN-007 metadata', () {
      final result = const EffectiveRateCalculator().calculate(
        loan(fee: '2000'),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'LN-007');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.inputs['processingFee'], '2000');
      expect(result.metadata.details['amortizationFormulaId'], 'LN-002');
      expect(result.metadata.assumptions['rateSolver'], 'boundedBisection');
      expect(
        result.metadata.assumptions['processingFeeTiming'],
        'deductedFromInitialProceeds',
      );
      expect(result.metadata.assumptions['taxEffectsIncluded'], isFalse);
    });

    test('is deterministic for identical input and timestamp', () {
      final input = loan(fee: '1500');
      const calculator = EffectiveRateCalculator();

      final first = calculator.calculate(input, calculatedAt: calculatedAt);
      final second = calculator.calculate(input, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
