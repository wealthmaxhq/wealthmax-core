import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  group('Percentage construction', () {
    test('creates a percentage from percentage points', () {
      final percentage = Percentage.fromPercent('12.5');

      expect(percentage.percent, Decimal.parse('12.5'));
      expect(percentage.fraction, Decimal.parse('0.125'));
    });

    test('creates a percentage from a fraction', () {
      final percentage = Percentage.fromFraction('0.08');

      expect(percentage.percent, Decimal.parse('8'));
      expect(percentage.fraction, Decimal.parse('0.08'));
    });

    test('preserves exact decimal precision', () {
      final percentage = Percentage.fromPercent('12.3456789');

      expect(percentage.percent, Decimal.parse('12.3456789'));
      expect(percentage.fraction, Decimal.parse('0.123456789'));
    });

    test('does not clamp values above one hundred percent', () {
      final percentage = Percentage.fromPercent('125');

      expect(percentage.percent, Decimal.parse('125'));
      expect(percentage.fraction, Decimal.parse('1.25'));
    });

    test('does not clamp negative values', () {
      final percentage = Percentage.fromPercent('-2.5');

      expect(percentage.percent, Decimal.parse('-2.5'));
      expect(percentage.fraction, Decimal.parse('-0.025'));
    });

    test('rejects an invalid decimal string', () {
      expect(
        () => Percentage.fromPercent('not-a-number'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Percentage sign checks', () {
    test('identifies zero', () {
      final percentage = Percentage.fromPercent('0');

      expect(percentage.isZero, isTrue);
      expect(percentage.isPositive, isFalse);
      expect(percentage.isNegative, isFalse);
    });

    test('identifies a positive value', () {
      final percentage = Percentage.fromPercent('0.0001');

      expect(percentage.isZero, isFalse);
      expect(percentage.isPositive, isTrue);
      expect(percentage.isNegative, isFalse);
    });

    test('identifies a negative value', () {
      final percentage = Percentage.fromPercent('-0.0001');

      expect(percentage.isZero, isFalse);
      expect(percentage.isPositive, isFalse);
      expect(percentage.isNegative, isTrue);
    });
  });

  group('Percentage arithmetic', () {
    test('adds percentage points', () {
      final result =
          Percentage.fromPercent('8.5') + Percentage.fromPercent('1.25');

      expect(result.percent, Decimal.parse('9.75'));
    });

    test('subtracts percentage points', () {
      final result =
          Percentage.fromPercent('8.5') - Percentage.fromPercent('1.25');

      expect(result.percent, Decimal.parse('7.25'));
    });

    test('supports a negative arithmetic result', () {
      final result =
          Percentage.fromPercent('5') - Percentage.fromPercent('7.5');

      expect(result.percent, Decimal.parse('-2.5'));
    });

    test('multiplies using the operator', () {
      final result = Percentage.fromPercent('6.25') * Decimal.parse('1.5');

      expect(result.percent, Decimal.parse('9.375'));
    });

    test('multiplies using the named method', () {
      final result = Percentage.fromPercent(
        '6.25',
      ).multiply(Decimal.parse('2'));

      expect(result.percent, Decimal.parse('12.5'));
    });

    test('multiplication by zero returns zero', () {
      final result = Percentage.fromPercent('6.25') * Decimal.zero;

      expect(result.isZero, isTrue);
    });
  });

  group('Percentage comparison', () {
    test('compares lower and higher values', () {
      final lower = Percentage.fromPercent('8.49');
      final higher = Percentage.fromPercent('8.5');

      expect(lower.compareTo(higher), lessThan(0));
      expect(higher.compareTo(lower), greaterThan(0));
    });

    test('compares equal values', () {
      final first = Percentage.fromPercent('8.50');
      final second = Percentage.fromFraction('0.085');

      expect(first.compareTo(second), 0);
    });
  });

  group('Percentage value semantics', () {
    test('equal percentages have value equality', () {
      final first = Percentage.fromPercent('8.50');
      final second = Percentage.fromPercent('8.5');

      expect(first, equals(second));
    });

    test('equal percentages have equal hash codes', () {
      final first = Percentage.fromPercent('8.50');
      final second = Percentage.fromFraction('0.085');

      expect(first.hashCode, equals(second.hashCode));
    });

    test('different percentages are not equal', () {
      final first = Percentage.fromPercent('8.5');
      final second = Percentage.fromPercent('8.6');

      expect(first, isNot(equals(second)));
    });
  });

  group('Percentage string representation', () {
    test('uses a deterministic percentage-point representation', () {
      final percentage = Percentage.fromPercent('12.50');

      expect(percentage.toString(), '12.5%');
    });

    test('represents a negative percentage', () {
      final percentage = Percentage.fromPercent('-2.5');

      expect(percentage.toString(), '-2.5%');
    });
  });
}
