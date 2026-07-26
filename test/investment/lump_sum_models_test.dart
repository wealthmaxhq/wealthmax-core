import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  group('LumpSumInput', () {
    test('stores valid projection assumptions', () {
      final input = LumpSumInput(
        initialInvestment: inr('100000'),
        expectedAnnualReturn: Percentage.fromPercent('12'),
        tenureYears: 10,
      );

      expect(input.initialInvestment, inr('100000'));
      expect(input.expectedAnnualReturn, Percentage.fromPercent('12'));
      expect(input.tenureYears, 10);
    });

    test('accepts zero tenure', () {
      final input = LumpSumInput(
        initialInvestment: inr('100000'),
        expectedAnnualReturn: Percentage.fromPercent('12'),
        tenureYears: 0,
      );

      expect(input.tenureYears, 0);
    });

    test('accepts a total-loss annual return', () {
      final input = LumpSumInput(
        initialInvestment: inr('100000'),
        expectedAnnualReturn: Percentage.fromPercent('-100'),
        tenureYears: 1,
      );

      expect(input.expectedAnnualReturn, Percentage.fromPercent('-100'));
    });

    test('rejects zero initial investment', () {
      expect(
        () => LumpSumInput(
          initialInvestment: inr('0'),
          expectedAnnualReturn: Percentage.fromPercent('12'),
          tenureYears: 10,
        ),
        throwsArgumentError,
      );
    });

    test('rejects return below total loss', () {
      expect(
        () => LumpSumInput(
          initialInvestment: inr('100000'),
          expectedAnnualReturn: Percentage.fromPercent('-100.01'),
          tenureYears: 10,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative tenure', () {
      expect(
        () => LumpSumInput(
          initialInvestment: inr('100000'),
          expectedAnnualReturn: Percentage.fromPercent('12'),
          tenureYears: -1,
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith and value equality', () {
      final input = LumpSumInput(
        initialInvestment: inr('100000'),
        expectedAnnualReturn: Percentage.fromPercent('12'),
        tenureYears: 10,
      );
      final changed = input.copyWith(tenureYears: 20);
      final expected = input.copyWith(tenureYears: 20);

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.initialInvestment, input.initialInvestment);
    });

    test('has deterministic string output', () {
      final input = LumpSumInput(
        initialInvestment: inr('100000'),
        expectedAnnualReturn: Percentage.fromPercent('12'),
        tenureYears: 10,
      );

      expect(input.toString(), contains('expectedAnnualReturn: 12%'));
      expect(input.toString(), contains('tenureYears: 10'));
    });
  });

  group('LumpSumResult', () {
    LumpSumResult result({
      Money? initial,
      Money? future,
      String cumulativeReturn = '50',
      int years = 5,
    }) {
      return LumpSumResult(
        initialInvestment: initial ?? inr('100000'),
        futureValue: future ?? inr('150000'),
        cumulativeReturn: Percentage.fromPercent(cumulativeReturn),
        tenureYears: years,
      );
    }

    test('derives gain and sign flags', () {
      final value = result();

      expect(value.totalGain, inr('50000'));
      expect(value.isGain, isTrue);
      expect(value.isLoss, isFalse);
    });

    test('supports a projected loss', () {
      final value = result(future: inr('80000'), cumulativeReturn: '-20');

      expect(value.totalGain, inr('-20000'));
      expect(value.isGain, isFalse);
      expect(value.isLoss, isTrue);
    });

    test('rejects future value in another currency', () {
      expect(
        () => result(future: Money.parse('150000', currency: Currencies.usd)),
        throwsArgumentError,
      );
    });

    test('rejects a negative future value', () {
      expect(() => result(future: inr('-1')), throwsArgumentError);
    });

    test('rejects cumulative return below total loss', () {
      expect(() => result(cumulativeReturn: '-100.01'), throwsArgumentError);
    });

    test('supports copyWith, equality, and deterministic output', () {
      final value = result();
      final changed = value.copyWith(futureValue: inr('160000'));
      final expected = value.copyWith(futureValue: inr('160000'));

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('totalGain: INR 60000'));
    });
  });
}
