import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 3, 12);

  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  InflationAdjustmentInput input({
    Money? nominalValue,
    String inflation = '6',
    int months = 12,
  }) {
    return InflationAdjustmentInput(
      nominalFutureValue: nominalValue ?? inr('106'),
      annualInflationRate: Percentage.fromPercent(inflation),
      horizonMonths: months,
    );
  }

  bool closeTo(Decimal actual, String expected, String tolerance) {
    return (actual - Decimal.parse(expected)).abs() <= Decimal.parse(tolerance);
  }

  group('InflationAdjustmentInput', () {
    test('stores future value, inflation, and monthly horizon', () {
      final value = input();

      expect(value.nominalFutureValue, inr('106'));
      expect(value.annualInflationRate, Percentage.fromPercent('6'));
      expect(value.horizonMonths, 12);
    });

    test('accepts zero value, deflation, and zero horizon', () {
      final value = input(nominalValue: inr('0'), inflation: '-10', months: 0);

      expect(value.nominalFutureValue.isZero, isTrue);
      expect(value.annualInflationRate.isNegative, isTrue);
      expect(value.horizonMonths, 0);
    });

    test('rejects invalid value, inflation, and horizon', () {
      expect(() => input(nominalValue: inr('-1')), throwsArgumentError);
      expect(() => input(inflation: '-100'), throwsArgumentError);
      expect(() => input(months: -1), throwsArgumentError);
      expect(
        () => input(
          months: InflationAdjustmentCalculatorLimits.maximumMonths + 1,
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith, equality, hashing, and output', () {
      final value = input();
      final changed = value.copyWith(horizonMonths: 24);
      final expected = value.copyWith(horizonMonths: 24);

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('horizonMonths: 24'));
    });
  });

  group('InflationAdjustmentResult', () {
    InflationAdjustmentResult result({
      Money? realValue,
      String inflation = '6',
      String cumulativeInflation = '6',
      int months = 12,
    }) {
      return InflationAdjustmentResult(
        nominalFutureValue: inr('106'),
        realValue: realValue ?? inr('100'),
        annualInflationRate: Percentage.fromPercent(inflation),
        cumulativeInflation: Percentage.fromPercent(cumulativeInflation),
        horizonMonths: months,
      );
    }

    test('derives purchasing-power erosion', () {
      final value = result();

      expect(value.purchasingPowerDifference, inr('6'));
      expect(value.hasErosion, isTrue);
      expect(value.hasDeflationGain, isFalse);
    });

    test('represents a purchasing-power gain under deflation', () {
      final value = result(
        realValue: inr('117.78'),
        inflation: '-10',
        cumulativeInflation: '-10',
      );

      expect(value.purchasingPowerDifference, inr('-11.78'));
      expect(value.hasDeflationGain, isTrue);
    });

    test('rejects invalid values, currency, rates, and horizon', () {
      expect(() => result(realValue: inr('-1')), throwsArgumentError);
      expect(
        () => result(realValue: Money.parse('100', currency: Currencies.usd)),
        throwsArgumentError,
      );
      expect(() => result(inflation: '-100'), throwsArgumentError);
      expect(() => result(cumulativeInflation: '-100'), throwsArgumentError);
      expect(() => result(months: -1), throwsArgumentError);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final value = result();
      final changed = value.copyWith(realValue: inr('99'));
      final expected = value.copyWith(realValue: inr('99'));

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('purchasingPowerDifference: INR 7'));
    });
  });

  group('InflationAdjustmentCalculator', () {
    test('discounts one year at six percent', () {
      final result = const InflationAdjustmentCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.value.realValue, inr('100.00'));
      expect(
        closeTo(result.value.cumulativeInflation.percent, '6', '0.0000000001'),
        isTrue,
      );
      expect(result.value.purchasingPowerDifference, inr('6.00'));
    });

    test('discounts two years using effective compounding', () {
      final result = const InflationAdjustmentCalculator().calculate(
        input(nominalValue: inr('112.36'), months: 24),
        calculatedAt: calculatedAt,
      );

      expect(result.value.realValue, inr('100.00'));
      expect(
        closeTo(
          result.value.cumulativeInflation.percent,
          '12.36',
          '0.00000001',
        ),
        isTrue,
      );
    });

    test('zero inflation preserves nominal value', () {
      final result = const InflationAdjustmentCalculator().calculate(
        input(nominalValue: inr('123.45'), inflation: '0', months: 240),
        calculatedAt: calculatedAt,
      );

      expect(result.value.realValue, inr('123.45'));
      expect(result.value.cumulativeInflation.isZero, isTrue);
    });

    test('zero horizon preserves nominal value', () {
      final result = const InflationAdjustmentCalculator().calculate(
        input(nominalValue: inr('123.45'), months: 0),
        calculatedAt: calculatedAt,
      );

      expect(result.value.realValue, inr('123.45'));
      expect(result.value.cumulativeInflation.isZero, isTrue);
    });

    test('deflation increases present purchasing power', () {
      final result = const InflationAdjustmentCalculator().calculate(
        input(nominalValue: inr('90'), inflation: '-10'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.realValue, inr('100.00'));
      expect(result.value.hasDeflationGain, isTrue);
    });

    test('zero nominal value remains zero', () {
      final result = const InflationAdjustmentCalculator().calculate(
        input(nominalValue: inr('0')),
        calculatedAt: calculatedAt,
      );

      expect(result.value.realValue, Money.zero(Currencies.inr));
    });

    test('honors final-value rounding policy', () {
      final value = input(nominalValue: inr('1'), inflation: '1', months: 1);
      final halfUp = const InflationAdjustmentCalculator().calculate(
        value,
        calculatedAt: calculatedAt,
      );
      final floor = const InflationAdjustmentCalculator(
        roundingPolicy: RoundingPolicy.floor,
      ).calculate(value, calculatedAt: calculatedAt);

      expect(halfUp.value.realValue, inr('1.00'));
      expect(floor.value.realValue, inr('0.99'));
    });

    test('preserves another currency', () {
      final result = const InflationAdjustmentCalculator().calculate(
        input(nominalValue: Money.parse('106', currency: Currencies.usd)),
        calculatedAt: calculatedAt,
      );

      expect(result.value.nominalFutureValue.currency, Currencies.usd);
      expect(result.value.realValue.currency, Currencies.usd);
    });

    test('adds long-horizon caution after thirty years', () {
      final result = const InflationAdjustmentCalculator().calculate(
        input(months: 361),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings, hasLength(2));
      expect(result.warnings.last.code, 'INV-008-LONG-HORIZON');
      expect(result.warnings.last.severity, WarningSeverity.caution);
    });

    test('returns transparent INV-008 metadata', () {
      final result = const InflationAdjustmentCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings.first.code, 'INV-008-INFLATION-ASSUMPTION');
      expect(result.metadata.formulaId, 'INV-008');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(
        result.metadata.assumptions['monthlyFactorConversion'],
        'twelfthRootOfAnnualGrowthFactor',
      );
      expect(result.metadata.assumptions['binaryFloatingPointUsed'], isFalse);
    });

    test('is deterministic', () {
      final value = input(months: 240);
      const calculator = InflationAdjustmentCalculator();

      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
