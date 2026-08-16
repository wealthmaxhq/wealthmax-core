import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  EffectiveRateResult result({
    Money? netProceeds,
    Money? totalRepayment,
    String monthlyRate = '1',
    String nominalApr = '12',
    String effectiveAnnualRate = '12.6825030131969720661201',
    int paymentCount = 12,
  }) {
    return EffectiveRateResult(
      netProceeds: netProceeds ?? inr('100000'),
      totalRepayment: totalRepayment ?? inr('106618.56'),
      monthlyEffectiveRate: Percentage.fromPercent(monthlyRate),
      nominalAnnualPercentageRate: Percentage.fromPercent(nominalApr),
      effectiveAnnualRate: Percentage.fromPercent(effectiveAnnualRate),
      paymentCount: paymentCount,
    );
  }

  group('EffectiveRateResult', () {
    test('stores a complete effective-cost summary', () {
      final value = result();

      expect(value.netProceeds, inr('100000'));
      expect(value.totalRepayment, inr('106618.56'));
      expect(value.monthlyEffectiveRate, Percentage.fromPercent('1'));
      expect(value.nominalAnnualPercentageRate, Percentage.fromPercent('12'));
      expect(value.paymentCount, 12);
    });

    test('derives the finance charge from actual proceeds', () {
      final value = result();

      expect(value.financeCharge, inr('6618.56'));
    });

    test('accepts a zero-cost loan', () {
      final value = result(
        totalRepayment: inr('100000'),
        monthlyRate: '0',
        nominalApr: '0',
        effectiveAnnualRate: '0',
      );

      expect(value.financeCharge, inr('0'));
    });

    test('rejects zero net proceeds', () {
      expect(() => result(netProceeds: inr('0')), throwsArgumentError);
    });

    test('rejects a repayment in another currency', () {
      expect(
        () => result(
          totalRepayment: Money.parse('106618.56', currency: Currencies.usd),
        ),
        throwsArgumentError,
      );
    });

    test('rejects repayment below net proceeds', () {
      expect(() => result(totalRepayment: inr('99999')), throwsArgumentError);
    });

    test('rejects negative rates', () {
      expect(() => result(monthlyRate: '-0.1'), throwsArgumentError);
      expect(() => result(nominalApr: '-1'), throwsArgumentError);
      expect(() => result(effectiveAnnualRate: '-1'), throwsArgumentError);
    });

    test('rejects a non-positive payment count', () {
      expect(() => result(paymentCount: 0), throwsArgumentError);
    });

    test('copyWith replaces selected fields', () {
      final original = result();
      final changed = original.copyWith(
        netProceeds: inr('99000'),
        paymentCount: 24,
      );

      expect(changed.netProceeds, inr('99000'));
      expect(changed.paymentCount, 24);
      expect(changed.totalRepayment, original.totalRepayment);
      expect(changed.monthlyEffectiveRate, original.monthlyEffectiveRate);
    });

    test('supports value equality and matching hashes', () {
      final first = result();
      final second = result();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('has deterministic string output', () {
      expect(result().toString(), contains('nominalAnnualPercentageRate: 12%'));
      expect(result().toString(), contains('financeCharge: INR 6618.56'));
    });
  });
}
