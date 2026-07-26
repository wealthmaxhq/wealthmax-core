import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);
  Money usd(String value) => Money.parse(value, currency: Currencies.usd);

  RefinanceInput input({
    String principal = '1000000',
    String currentRate = '10',
    int remainingMonths = 120,
    String newRate = '8',
    int newTenureMonths = 120,
    String? fees,
  }) {
    return RefinanceInput(
      outstandingPrincipal: inr(principal),
      currentAnnualInterestRate: Percentage.fromPercent(currentRate),
      remainingMonths: remainingMonths,
      newAnnualInterestRate: Percentage.fromPercent(newRate),
      newTenureMonths: newTenureMonths,
      refinancingFees: fees == null ? null : inr(fees),
    );
  }

  group('RefinanceInput', () {
    test('stores comparison assumptions', () {
      final value = input(fees: '10000');

      expect(value.outstandingPrincipal, inr('1000000'));
      expect(value.currentAnnualInterestRate, Percentage.fromPercent('10'));
      expect(value.remainingMonths, 120);
      expect(value.newAnnualInterestRate, Percentage.fromPercent('8'));
      expect(value.newTenureMonths, 120);
      expect(value.refinancingFees, inr('10000'));
    });

    test('defaults fees to zero in principal currency', () {
      expect(input().refinancingFees, inr('0'));
    });

    test('accepts zero current and new rates', () {
      expect(() => input(currentRate: '0', newRate: '0'), returnsNormally);
    });

    test('rejects zero outstanding principal', () {
      expect(() => input(principal: '0'), throwsArgumentError);
    });

    test('rejects negative outstanding principal', () {
      expect(() => input(principal: '-1'), throwsArgumentError);
    });

    test('rejects negative current rate', () {
      expect(() => input(currentRate: '-0.01'), throwsArgumentError);
    });

    test('rejects negative new rate', () {
      expect(() => input(newRate: '-0.01'), throwsArgumentError);
    });

    test('rejects non-positive remaining tenure', () {
      expect(() => input(remainingMonths: 0), throwsArgumentError);
    });

    test('rejects non-positive new tenure', () {
      expect(() => input(newTenureMonths: 0), throwsArgumentError);
    });

    test('rejects negative fees', () {
      expect(() => input(fees: '-1'), throwsArgumentError);
    });

    test('rejects fees in another currency', () {
      expect(
        () => RefinanceInput(
          outstandingPrincipal: inr('1000'),
          currentAnnualInterestRate: Percentage.fromPercent('10'),
          remainingMonths: 12,
          newAnnualInterestRate: Percentage.fromPercent('8'),
          newTenureMonths: 12,
          refinancingFees: usd('10'),
        ),
        throwsArgumentError,
      );
    });

    test('copyWith replaces selected assumptions', () {
      final original = input(fees: '10000');
      final copy = original.copyWith(
        newAnnualInterestRate: Percentage.fromPercent('7.5'),
        newTenureMonths: 96,
      );

      expect(copy.outstandingPrincipal, original.outstandingPrincipal);
      expect(copy.newAnnualInterestRate, Percentage.fromPercent('7.5'));
      expect(copy.newTenureMonths, 96);
      expect(copy.refinancingFees, original.refinancingFees);
    });

    test('supports value equality and matching hashes', () {
      expect(input(fees: '10000'), input(fees: '10000'));
      expect(input(fees: '10000').hashCode, input(fees: '10000').hashCode);
    });

    test('has deterministic string output', () {
      expect(
        input(fees: '10000').toString(),
        'RefinanceInput(outstandingPrincipal: INR 1000000, '
        'currentAnnualInterestRate: 10%, remainingMonths: 120, '
        'newAnnualInterestRate: 8%, newTenureMonths: 120, '
        'refinancingFees: INR 10000)',
      );
    });
  });
}
