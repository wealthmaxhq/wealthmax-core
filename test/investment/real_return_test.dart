import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 2, 12);

  bool closeTo(Decimal actual, String expected, String tolerance) {
    return (actual - Decimal.parse(expected)).abs() <= Decimal.parse(tolerance);
  }

  group('RealReturnInput', () {
    test('stores nominal return and inflation', () {
      final input = RealReturnInput(
        nominalReturn: Percentage.fromPercent('12'),
        inflationRate: Percentage.fromPercent('5'),
      );

      expect(input.nominalReturn, Percentage.fromPercent('12'));
      expect(input.inflationRate, Percentage.fromPercent('5'));
    });

    test('accepts total nominal loss and deflation', () {
      final input = RealReturnInput(
        nominalReturn: Percentage.fromPercent('-100'),
        inflationRate: Percentage.fromPercent('-5'),
      );

      expect(input.nominalReturn, Percentage.fromPercent('-100'));
      expect(input.inflationRate, Percentage.fromPercent('-5'));
    });

    test('rejects invalid nominal return and total-price collapse', () {
      expect(
        () => RealReturnInput(
          nominalReturn: Percentage.fromPercent('-100.01'),
          inflationRate: Percentage.fromPercent('5'),
        ),
        throwsArgumentError,
      );
      expect(
        () => RealReturnInput(
          nominalReturn: Percentage.fromPercent('5'),
          inflationRate: Percentage.fromPercent('-100'),
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith, equality, hashing, and output', () {
      final input = RealReturnInput(
        nominalReturn: Percentage.fromPercent('12'),
        inflationRate: Percentage.fromPercent('5'),
      );
      final changed = input.copyWith(
        inflationRate: Percentage.fromPercent('6'),
      );
      final expected = input.copyWith(
        inflationRate: Percentage.fromPercent('6'),
      );

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('inflationRate: 6%'));
    });
  });

  group('RealReturnResult', () {
    test('reports whether purchasing power is preserved', () {
      final positive = RealReturnResult(
        nominalReturn: Percentage.fromPercent('12'),
        inflationRate: Percentage.fromPercent('5'),
        realReturn: Percentage.fromPercent('6.6666666667'),
      );
      final negative = positive.copyWith(
        realReturn: Percentage.fromPercent('-1'),
      );

      expect(positive.preservesPurchasingPower, isTrue);
      expect(negative.preservesPurchasingPower, isFalse);
    });

    test('rejects real return below total loss', () {
      expect(
        () => RealReturnResult(
          nominalReturn: Percentage.fromPercent('5'),
          inflationRate: Percentage.fromPercent('5'),
          realReturn: Percentage.fromPercent('-100.01'),
        ),
        throwsArgumentError,
      );
    });

    test('supports equality, hashing, and deterministic output', () {
      final first = RealReturnResult(
        nominalReturn: Percentage.fromPercent('12'),
        inflationRate: Percentage.fromPercent('5'),
        realReturn: Percentage.fromPercent('6.6666666667'),
      );
      final second = first.copyWith();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('realReturn'));
    });
  });

  group('RealReturnCalculator', () {
    test('uses the exact Fisher equation', () {
      final result = const RealReturnCalculator().calculate(
        RealReturnInput(
          nominalReturn: Percentage.fromPercent('12'),
          inflationRate: Percentage.fromPercent('5'),
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(
          result.value.realReturn.percent,
          '6.66666666666666666666666666666667',
          '0.000000000000000000000000000001',
        ),
        isTrue,
      );
    });

    test('equal nominal return and inflation produce zero real return', () {
      final result = const RealReturnCalculator().calculate(
        RealReturnInput(
          nominalReturn: Percentage.fromPercent('5'),
          inflationRate: Percentage.fromPercent('5'),
        ),
        calculatedAt: calculatedAt,
      );

      expect(result.value.realReturn.isZero, isTrue);
      expect(result.value.preservesPurchasingPower, isTrue);
    });

    test('supports negative nominal return', () {
      final result = const RealReturnCalculator().calculate(
        RealReturnInput(
          nominalReturn: Percentage.fromPercent('-10'),
          inflationRate: Percentage.fromPercent('5'),
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(
          result.value.realReturn.percent,
          '-14.2857142857142857142857142857143',
          '0.00000000000000000000000000001',
        ),
        isTrue,
      );
    });

    test('deflation raises real return above nominal return', () {
      final result = const RealReturnCalculator().calculate(
        RealReturnInput(
          nominalReturn: Percentage.fromPercent('5'),
          inflationRate: Percentage.fromPercent('-2'),
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.realReturn.compareTo(Percentage.fromPercent('5')),
        greaterThan(0),
      );
    });

    test('total nominal loss remains a total real loss', () {
      final result = const RealReturnCalculator().calculate(
        RealReturnInput(
          nominalReturn: Percentage.fromPercent('-100'),
          inflationRate: Percentage.fromPercent('5'),
        ),
        calculatedAt: calculatedAt,
      );

      expect(result.value.realReturn, Percentage.fromPercent('-100'));
    });

    test('returns transparent warning and INV-007 metadata', () {
      final result = const RealReturnCalculator().calculate(
        RealReturnInput(
          nominalReturn: Percentage.fromPercent('12'),
          inflationRate: Percentage.fromPercent('5'),
        ),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings.single.code, 'INV-007-ASSUMPTION-SENSITIVE');
      expect(result.warnings.single.severity, WarningSeverity.info);
      expect(result.metadata.formulaId, 'INV-007');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.assumptions['formula'], 'exactFisherEquation');
      expect(result.metadata.assumptions['binaryFloatingPointUsed'], isFalse);
    });

    test('is deterministic', () {
      final input = RealReturnInput(
        nominalReturn: Percentage.fromPercent('12'),
        inflationRate: Percentage.fromPercent('5'),
      );
      const calculator = RealReturnCalculator();

      final first = calculator.calculate(input, calculatedAt: calculatedAt);
      final second = calculator.calculate(input, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
