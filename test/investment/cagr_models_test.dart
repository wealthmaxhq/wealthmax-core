import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  group('CagrInput', () {
    test('stores valid actual-day inputs', () {
      final input = CagrInput(
        initialValue: inr('100000'),
        finalValue: inr('121000'),
        holdingPeriodDays: 730,
      );

      expect(input.initialValue, inr('100000'));
      expect(input.finalValue, inr('121000'));
      expect(input.holdingPeriodDays, 730);
    });

    test('accepts a zero final value', () {
      final input = CagrInput(
        initialValue: inr('100000'),
        finalValue: inr('0'),
        holdingPeriodDays: 365,
      );

      expect(input.finalValue.isZero, isTrue);
    });

    test('rejects invalid values, currencies, and holding periods', () {
      expect(
        () => CagrInput(
          initialValue: inr('0'),
          finalValue: inr('100'),
          holdingPeriodDays: 365,
        ),
        throwsArgumentError,
      );
      expect(
        () => CagrInput(
          initialValue: inr('100'),
          finalValue: inr('-1'),
          holdingPeriodDays: 365,
        ),
        throwsArgumentError,
      );
      expect(
        () => CagrInput(
          initialValue: inr('100'),
          finalValue: Money.parse('110', currency: Currencies.usd),
          holdingPeriodDays: 365,
        ),
        throwsArgumentError,
      );
      expect(
        () => CagrInput(
          initialValue: inr('100'),
          finalValue: inr('110'),
          holdingPeriodDays: 0,
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith, equality, hashing, and output', () {
      final input = CagrInput(
        initialValue: inr('100'),
        finalValue: inr('121'),
        holdingPeriodDays: 730,
      );
      final changed = input.copyWith(holdingPeriodDays: 365);
      final expected = input.copyWith(holdingPeriodDays: 365);

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('holdingPeriodDays: 365'));
    });
  });

  group('CagrResult', () {
    CagrResult result({
      Money? finalValue,
      String totalReturn = '21',
      String annualizedReturn = '10',
      int days = 730,
    }) {
      return CagrResult(
        initialValue: inr('100'),
        finalValue: finalValue ?? inr('121'),
        totalReturn: Percentage.fromPercent(totalReturn),
        annualizedReturn: Percentage.fromPercent(annualizedReturn),
        holdingPeriodDays: days,
      );
    }

    test('derives absolute gain and sign flags', () {
      final value = result();

      expect(value.absoluteGain, inr('21'));
      expect(value.isGain, isTrue);
      expect(value.isLoss, isFalse);
    });

    test('supports a complete loss', () {
      final value = result(
        finalValue: inr('0'),
        totalReturn: '-100',
        annualizedReturn: '-100',
      );

      expect(value.absoluteGain, inr('-100'));
      expect(value.isLoss, isTrue);
    });

    test('rejects invalid values and returns', () {
      expect(
        () => result(finalValue: Money.parse('121', currency: Currencies.usd)),
        throwsArgumentError,
      );
      expect(() => result(totalReturn: '-100.01'), throwsArgumentError);
      expect(() => result(annualizedReturn: '-100.01'), throwsArgumentError);
      expect(() => result(days: 0), throwsArgumentError);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final value = result();
      final changed = value.copyWith(finalValue: inr('125'));
      final expected = value.copyWith(finalValue: inr('125'));

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('absoluteGain: INR 25'));
    });
  });
}
