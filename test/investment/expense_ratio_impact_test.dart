import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 3, 12);

  ExpenseRatioImpactInput input({
    String principal = '100000',
    String grossReturn = '10',
    String expenseRatio = '1',
    int years = 10,
    Currency currency = Currencies.inr,
  }) {
    return ExpenseRatioImpactInput(
      initialInvestment: Money.parse(principal, currency: currency),
      grossAnnualReturn: Percentage.fromPercent(grossReturn),
      annualExpenseRatio: Percentage.fromPercent(expenseRatio),
      tenureYears: years,
    );
  }

  group('ExpenseRatioImpactInput', () {
    test('stores valid assumptions', () {
      final value = input();

      expect(value.initialInvestment.amount, Decimal.fromInt(100000));
      expect(value.grossAnnualReturn, Percentage.fromPercent('10'));
      expect(value.annualExpenseRatio, Percentage.fromPercent('1'));
      expect(value.tenureYears, 10);
    });

    test('accepts total gross loss, zero fee, and zero tenure', () {
      final value = input(grossReturn: '-100', expenseRatio: '0', years: 0);

      expect(value.grossAnnualReturn, Percentage.fromPercent('-100'));
      expect(value.tenureYears, 0);
    });

    test('rejects non-positive investment', () {
      expect(() => input(principal: '0'), throwsArgumentError);
      expect(() => input(principal: '-1'), throwsArgumentError);
    });

    test('rejects gross return below total loss', () {
      expect(() => input(grossReturn: '-100.01'), throwsArgumentError);
    });

    test('rejects invalid expense ratios', () {
      expect(() => input(expenseRatio: '-0.01'), throwsArgumentError);
      expect(() => input(expenseRatio: '100'), throwsArgumentError);
    });

    test('rejects negative tenure', () {
      expect(() => input(years: -1), throwsArgumentError);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final original = input();
      final changed = original.copyWith(tenureYears: 20);
      final expected = original.copyWith(tenureYears: 20);

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('tenureYears: 20'));
    });
  });

  group('ExpenseRatioImpactResult', () {
    test('exposes gains, fee loss, and fee-impact state', () {
      final result = ExpenseRatioImpactResult(
        initialInvestment: Money.parse('100', currency: Currencies.inr),
        grossFutureValue: Money.parse('121', currency: Currencies.inr),
        netFutureValue: Money.parse('118', currency: Currencies.inr),
        grossAnnualReturn: Percentage.fromPercent('10'),
        annualExpenseRatio: Percentage.fromPercent('1'),
        netAnnualReturn: Percentage.fromPercent('8.9'),
        tenureYears: 2,
      );

      expect(result.grossGain.amount, Decimal.parse('21'));
      expect(result.netGain.amount, Decimal.parse('18'));
      expect(result.wealthLostToFees.amount, Decimal.parse('3'));
      expect(result.hasFeeImpact, isTrue);
    });

    test('rejects mismatched currencies and invalid ordering', () {
      final initial = Money.parse('100', currency: Currencies.inr);

      expect(
        () => ExpenseRatioImpactResult(
          initialInvestment: initial,
          grossFutureValue: Money.parse('121', currency: Currencies.usd),
          netFutureValue: Money.parse('118', currency: Currencies.inr),
          grossAnnualReturn: Percentage.fromPercent('10'),
          annualExpenseRatio: Percentage.fromPercent('1'),
          netAnnualReturn: Percentage.fromPercent('8.9'),
          tenureYears: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExpenseRatioImpactResult(
          initialInvestment: initial,
          grossFutureValue: Money.parse('110', currency: Currencies.inr),
          netFutureValue: Money.parse('111', currency: Currencies.inr),
          grossAnnualReturn: Percentage.fromPercent('10'),
          annualExpenseRatio: Percentage.fromPercent('1'),
          netAnnualReturn: Percentage.fromPercent('8.9'),
          tenureYears: 1,
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith, equality, hashing, and output', () {
      final calculated = const ExpenseRatioImpactCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );
      final changed = calculated.value.copyWith(tenureYears: 11);
      final expected = calculated.value.copyWith(tenureYears: 11);

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('wealthLostToFees'));
    });
  });

  group('ExpenseRatioImpactCalculator', () {
    test('applies a one-percent fee after a ten-percent annual return', () {
      final result = const ExpenseRatioImpactCalculator().calculate(
        input(principal: '100', years: 1),
        calculatedAt: calculatedAt,
      );

      expect(result.value.grossFutureValue.amount, Decimal.parse('110'));
      expect(result.value.netFutureValue.amount, Decimal.parse('108.9'));
      expect(result.value.wealthLostToFees.amount, Decimal.parse('1.1'));
      expect(result.value.netAnnualReturn.percent, Decimal.parse('8.9'));
    });

    test('compounds fee drag over multiple years', () {
      final result = const ExpenseRatioImpactCalculator().calculate(
        input(principal: '100000', years: 10),
        calculatedAt: calculatedAt,
      );

      expect(result.value.grossFutureValue.amount, Decimal.parse('259374.25'));
      expect(result.value.netFutureValue.amount, Decimal.parse('234573.42'));
      expect(result.value.wealthLostToFees.amount, Decimal.parse('24800.83'));
    });

    test('zero fee produces no wealth loss', () {
      final result = const ExpenseRatioImpactCalculator().calculate(
        input(expenseRatio: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.grossFutureValue, result.value.netFutureValue);
      expect(result.value.wealthLostToFees.isZero, isTrue);
      expect(result.value.hasFeeImpact, isFalse);
    });

    test('zero tenure preserves the initial value', () {
      final result = const ExpenseRatioImpactCalculator().calculate(
        input(years: 0),
        calculatedAt: calculatedAt,
      );

      expect(result.value.grossFutureValue, result.value.initialInvestment);
      expect(result.value.netFutureValue, result.value.initialInvestment);
    });

    test('supports a total gross loss', () {
      final result = const ExpenseRatioImpactCalculator().calculate(
        input(grossReturn: '-100', years: 1),
        calculatedAt: calculatedAt,
      );

      expect(result.value.grossFutureValue.isZero, isTrue);
      expect(result.value.netFutureValue.isZero, isTrue);
      expect(result.value.netAnnualReturn.percent, Decimal.fromInt(-100));
    });

    test('preserves currency and configured final rounding', () {
      final result =
          const ExpenseRatioImpactCalculator(
            roundingPolicy: RoundingPolicy.floor,
          ).calculate(
            input(
              principal: '100.01',
              grossReturn: '7.25',
              expenseRatio: '0.65',
              years: 3,
              currency: Currencies.usd,
            ),
            calculatedAt: calculatedAt,
          );

      expect(result.value.netFutureValue.currency, Currencies.usd);
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('adds a caution for a high expense ratio', () {
      final result = const ExpenseRatioImpactCalculator().calculate(
        input(expenseRatio: '2'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.warnings.map((warning) => warning.code),
        contains('INV-009-HIGH-EXPENSE-RATIO'),
      );
    });

    test('adds a caution when the net annual return is negative', () {
      final result = const ExpenseRatioImpactCalculator().calculate(
        input(grossReturn: '1', expenseRatio: '2'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.netAnnualReturn.isNegative, isTrue);
      expect(
        result.warnings.map((warning) => warning.code),
        contains('INV-009-NEGATIVE-NET-RETURN'),
      );
    });

    test('returns transparent INV-009 metadata', () {
      final result = const ExpenseRatioImpactCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'INV-009');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(
        result.metadata.assumptions['feeConvention'],
        'endOfYearAssetBasedFee',
      );
      expect(result.metadata.assumptions['taxesIncluded'], isFalse);
      expect(result.metadata.details['wealthLostToFees'], isNotNull);
    });

    test('is deterministic for identical inputs and timestamp', () {
      const calculator = ExpenseRatioImpactCalculator();
      final value = input();

      expect(
        calculator.calculate(value, calculatedAt: calculatedAt),
        calculator.calculate(value, calculatedAt: calculatedAt),
      );
    });
  });
}
