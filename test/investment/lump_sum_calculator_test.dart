import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 28, 14);

  LumpSumInput input({
    String initial = '100000',
    String annualReturn = '12',
    int years = 10,
    Currency currency = Currencies.inr,
  }) {
    return LumpSumInput(
      initialInvestment: Money.parse(initial, currency: currency),
      expectedAnnualReturn: Percentage.fromPercent(annualReturn),
      tenureYears: years,
    );
  }

  group('LumpSumCalculator', () {
    test('projects a standard ten-year investment', () {
      final result = const LumpSumCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('310584.82', currency: Currencies.inr),
      );
      expect(
        result.value.totalGain,
        Money.parse('210584.82', currency: Currencies.inr),
      );
      expect(
        result.value.cumulativeReturn,
        Percentage.fromPercent('210.58482'),
      );
    });

    test('zero return preserves invested capital', () {
      final result = const LumpSumCalculator().calculate(
        input(annualReturn: '0'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('100000', currency: Currencies.inr),
      );
      expect(result.value.totalGain.isZero, isTrue);
      expect(result.value.cumulativeReturn.isZero, isTrue);
    });

    test('zero tenure preserves invested capital', () {
      final result = const LumpSumCalculator().calculate(
        input(years: 0),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('100000', currency: Currencies.inr),
      );
      expect(result.value.totalGain.isZero, isTrue);
    });

    test('supports a negative annual return', () {
      final result = const LumpSumCalculator().calculate(
        input(annualReturn: '-10', years: 2),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('81000', currency: Currencies.inr),
      );
      expect(result.value.cumulativeReturn, Percentage.fromPercent('-19'));
      expect(result.value.isLoss, isTrue);
    });

    test('supports a total loss assumption', () {
      final result = const LumpSumCalculator().calculate(
        input(annualReturn: '-100', years: 1),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('0', currency: Currencies.inr),
      );
      expect(result.value.cumulativeReturn, Percentage.fromPercent('-100'));
    });

    test('supports returns above one hundred percent', () {
      final result = const LumpSumCalculator().calculate(
        input(annualReturn: '150', years: 2),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('625000', currency: Currencies.inr),
      );
    });

    test('preserves another currency', () {
      final result = const LumpSumCalculator().calculate(
        input(currency: Currencies.usd),
        calculatedAt: calculatedAt,
      );

      expect(result.value.initialInvestment.currency, Currencies.usd);
      expect(result.value.futureValue.currency, Currencies.usd);
      expect(result.value.totalGain.currency, Currencies.usd);
    });

    test('honors final-value rounding policy', () {
      final value = input(initial: '1', annualReturn: '0.1', years: 1);
      final halfUp = const LumpSumCalculator().calculate(
        value,
        calculatedAt: calculatedAt,
      );
      final ceiling = const LumpSumCalculator(
        roundingPolicy: RoundingPolicy.ceiling,
      ).calculate(value, calculatedAt: calculatedAt);

      expect(
        halfUp.value.futureValue,
        Money.parse('1.00', currency: Currencies.inr),
      );
      expect(
        ceiling.value.futureValue,
        Money.parse('1.01', currency: Currencies.inr),
      );
    });

    test('returns a non-guaranteed projection warning', () {
      final result = const LumpSumCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.hasWarnings, isTrue);
      expect(result.warnings.single.severity, WarningSeverity.info);
      expect(result.warnings.single.code, 'INV-001-PROJECTION-NOT-GUARANTEED');
    });

    test('returns transparent INV-001 metadata', () {
      final result = const LumpSumCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'INV-001');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.inputs['initialInvestment'], '100000');
      expect(result.metadata.inputs['expectedAnnualReturnPercent'], '12');
      expect(result.metadata.inputs['tenureYears'], 10);
      expect(
        result.metadata.assumptions['returnConvention'],
        'effectiveAnnualReturn',
      );
      expect(result.metadata.assumptions['taxesIncluded'], isFalse);
      expect(result.metadata.assumptions['inflationIncluded'], isFalse);
      expect(result.metadata.details['futureValue'], '310584.82');
    });

    test('is deterministic', () {
      final value = input();
      const calculator = LumpSumCalculator();

      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
