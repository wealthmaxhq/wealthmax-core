import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  group('SipInput', () {
    test('stores explicit monthly projection assumptions', () {
      final input = SipInput(
        monthlyContribution: inr('10000'),
        expectedAnnualReturn: Percentage.fromPercent('12'),
        tenureMonths: 120,
        contributionTiming: ContributionTiming.beginningOfPeriod,
      );

      expect(input.monthlyContribution, inr('10000'));
      expect(input.expectedAnnualReturn, Percentage.fromPercent('12'));
      expect(input.tenureMonths, 120);
      expect(input.contributionTiming, ContributionTiming.beginningOfPeriod);
    });

    test('accepts a total-loss annual return', () {
      final input = SipInput(
        monthlyContribution: inr('10000'),
        expectedAnnualReturn: Percentage.fromPercent('-100'),
        tenureMonths: 12,
        contributionTiming: ContributionTiming.endOfPeriod,
      );

      expect(input.expectedAnnualReturn, Percentage.fromPercent('-100'));
    });

    test('rejects zero contribution', () {
      expect(
        () => SipInput(
          monthlyContribution: inr('0'),
          expectedAnnualReturn: Percentage.fromPercent('12'),
          tenureMonths: 120,
          contributionTiming: ContributionTiming.endOfPeriod,
        ),
        throwsArgumentError,
      );
    });

    test('rejects return below total loss', () {
      expect(
        () => SipInput(
          monthlyContribution: inr('10000'),
          expectedAnnualReturn: Percentage.fromPercent('-100.01'),
          tenureMonths: 120,
          contributionTiming: ContributionTiming.endOfPeriod,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive tenure', () {
      expect(
        () => SipInput(
          monthlyContribution: inr('10000'),
          expectedAnnualReturn: Percentage.fromPercent('12'),
          tenureMonths: 0,
          contributionTiming: ContributionTiming.endOfPeriod,
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith and value equality', () {
      final input = SipInput(
        monthlyContribution: inr('10000'),
        expectedAnnualReturn: Percentage.fromPercent('12'),
        tenureMonths: 120,
        contributionTiming: ContributionTiming.endOfPeriod,
      );
      final changed = input.copyWith(
        contributionTiming: ContributionTiming.beginningOfPeriod,
      );
      final expected = input.copyWith(
        contributionTiming: ContributionTiming.beginningOfPeriod,
      );

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('beginningOfPeriod'));
    });
  });

  group('SipResult', () {
    SipResult result({
      Money? futureValue,
      String cumulativeReturn = '20',
      String monthlyReturn = '1',
    }) {
      return SipResult(
        monthlyContribution: inr('1000'),
        totalInvested: inr('12000'),
        futureValue: futureValue ?? inr('14400'),
        monthlyEquivalentReturn: Percentage.fromPercent(monthlyReturn),
        cumulativeReturn: Percentage.fromPercent(cumulativeReturn),
        tenureMonths: 12,
        contributionTiming: ContributionTiming.endOfPeriod,
      );
    }

    test('derives gain and sign flags', () {
      final value = result();

      expect(value.totalGain, inr('2400'));
      expect(value.isGain, isTrue);
      expect(value.isLoss, isFalse);
    });

    test('supports a projected loss', () {
      final value = result(
        futureValue: inr('10000'),
        cumulativeReturn: '-16.6666666667',
        monthlyReturn: '-1',
      );

      expect(value.totalGain, inr('-2000'));
      expect(value.isLoss, isTrue);
    });

    test('rejects a mixed currency', () {
      expect(
        () =>
            result(futureValue: Money.parse('14400', currency: Currencies.usd)),
        throwsArgumentError,
      );
    });

    test('rejects inconsistent total invested', () {
      expect(
        () => SipResult(
          monthlyContribution: inr('1000'),
          totalInvested: inr('11999'),
          futureValue: inr('14400'),
          monthlyEquivalentReturn: Percentage.fromPercent('1'),
          cumulativeReturn: Percentage.fromPercent('20'),
          tenureMonths: 12,
          contributionTiming: ContributionTiming.endOfPeriod,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive result tenure', () {
      expect(
        () => SipResult(
          monthlyContribution: inr('1000'),
          totalInvested: inr('12000'),
          futureValue: inr('14400'),
          monthlyEquivalentReturn: Percentage.fromPercent('1'),
          cumulativeReturn: Percentage.fromPercent('20'),
          tenureMonths: 0,
          contributionTiming: ContributionTiming.endOfPeriod,
        ),
        throwsArgumentError,
      );
    });

    test('rejects return below total loss', () {
      expect(() => result(cumulativeReturn: '-100.01'), throwsArgumentError);
    });

    test('supports copyWith, equality, and deterministic output', () {
      final value = result();
      final changed = value.copyWith(futureValue: inr('15000'));
      final expected = value.copyWith(futureValue: inr('15000'));

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('totalGain: INR 3000'));
    });
  });
}
