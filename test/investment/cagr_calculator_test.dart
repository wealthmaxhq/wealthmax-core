import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 31, 12);

  CagrInput input({
    String initialValue = '100',
    String finalValue = '121',
    int days = 730,
    Currency currency = Currencies.inr,
  }) {
    return CagrInput(
      initialValue: Money.parse(initialValue, currency: currency),
      finalValue: Money.parse(finalValue, currency: currency),
      holdingPeriodDays: days,
    );
  }

  bool closeTo(Decimal actual, String expected, String tolerance) {
    return (actual - Decimal.parse(expected)).abs() <= Decimal.parse(tolerance);
  }

  group('CagrCalculator', () {
    test('calculates ten percent CAGR over two years', () {
      final result = const CagrCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.value.totalReturn, Percentage.fromPercent('21'));
      expect(
        closeTo(result.value.annualizedReturn.percent, '10', '0.0000000001'),
        isTrue,
      );
    });

    test('one-year CAGR equals total return', () {
      final result = const CagrCalculator().calculate(
        input(finalValue: '110', days: 365),
        calculatedAt: calculatedAt,
      );

      expect(result.value.totalReturn, Percentage.fromPercent('10'));
      expect(
        closeTo(result.value.annualizedReturn.percent, '10', '0.0000000001'),
        isTrue,
      );
    });

    test('supports zero growth', () {
      final result = const CagrCalculator().calculate(
        input(finalValue: '100'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.totalReturn.isZero, isTrue);
      expect(result.value.annualizedReturn.isZero, isTrue);
      expect(result.value.absoluteGain.isZero, isTrue);
    });

    test('supports a complete loss', () {
      final result = const CagrCalculator().calculate(
        input(finalValue: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.totalReturn, Percentage.fromPercent('-100'));
      expect(result.value.annualizedReturn, Percentage.fromPercent('-100'));
    });

    test('annualizes a multi-year doubling correctly', () {
      final result = const CagrCalculator().calculate(
        input(finalValue: '400', days: 730),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(result.value.annualizedReturn.percent, '100', '0.000000001'),
        isTrue,
      );
    });

    test('annualizes a loss correctly', () {
      final result = const CagrCalculator().calculate(
        input(finalValue: '81', days: 730),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(result.value.annualizedReturn.percent, '-10', '0.0000000001'),
        isTrue,
        reason: 'actual: ${result.value.annualizedReturn.percent}',
      );
    });

    test('short holding period produces annualization caution', () {
      final result = const CagrCalculator().calculate(
        input(finalValue: '110', days: 182),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.code, 'INV-005-SHORT-PERIOD-ANNUALIZATION');
      expect(result.warnings.single.severity, WarningSeverity.caution);
      expect(
        result.value.annualizedReturn.compareTo(Percentage.fromPercent('10')),
        greaterThan(0),
      );
    });

    test('one-year or longer period has no warning', () {
      final result = const CagrCalculator().calculate(
        input(days: 365),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings, isEmpty);
    });

    test('preserves another currency', () {
      final result = const CagrCalculator().calculate(
        input(currency: Currencies.usd),
        calculatedAt: calculatedAt,
      );

      expect(result.value.initialValue.currency, Currencies.usd);
      expect(result.value.finalValue.currency, Currencies.usd);
      expect(result.value.absoluteGain.currency, Currencies.usd);
    });

    test('returns transparent INV-005 metadata', () {
      final result = const CagrCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'INV-005');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.inputs['holdingPeriodDays'], 730);
      expect(result.metadata.assumptions['dayCountConvention'], 'actual/365');
      expect(result.metadata.assumptions['binaryFloatingPointUsed'], isFalse);
    });

    test('is deterministic', () {
      final value = input();
      const calculator = CagrCalculator();

      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
