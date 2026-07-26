import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  group('StepUpSipInput', () {
    StepUpSipInput input({
      String contribution = '1000',
      String annualReturn = '12',
      String stepUp = '10',
      int months = 120,
    }) {
      return StepUpSipInput(
        initialMonthlyContribution: inr(contribution),
        expectedAnnualReturn: Percentage.fromPercent(annualReturn),
        annualStepUp: Percentage.fromPercent(stepUp),
        tenureMonths: months,
        contributionTiming: ContributionTiming.endOfPeriod,
      );
    }

    test('stores explicit step-up SIP assumptions', () {
      final value = input();

      expect(value.initialMonthlyContribution, inr('1000'));
      expect(value.expectedAnnualReturn, Percentage.fromPercent('12'));
      expect(value.annualStepUp, Percentage.fromPercent('10'));
      expect(value.tenureMonths, 120);
      expect(value.contributionTiming, ContributionTiming.endOfPeriod);
    });

    test('accepts zero and negative annual step changes', () {
      expect(input(stepUp: '0').annualStepUp.isZero, isTrue);
      expect(input(stepUp: '-25').annualStepUp.isNegative, isTrue);
      expect(input(stepUp: '-100').annualStepUp.percent.toString(), '-100');
    });

    test('rejects non-positive initial contribution', () {
      expect(() => input(contribution: '0'), throwsArgumentError);
      expect(() => input(contribution: '-1'), throwsArgumentError);
    });

    test('rejects return below total loss', () {
      expect(() => input(annualReturn: '-100.01'), throwsArgumentError);
    });

    test('rejects annual step-down below total loss', () {
      expect(() => input(stepUp: '-100.01'), throwsArgumentError);
    });

    test('rejects non-positive tenure', () {
      expect(() => input(months: 0), throwsArgumentError);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final value = input();
      final changed = value.copyWith(
        annualStepUp: Percentage.fromPercent('15'),
      );
      final expected = value.copyWith(
        annualStepUp: Percentage.fromPercent('15'),
      );

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('annualStepUp: 15%'));
    });
  });

  group('StepUpSipResult', () {
    StepUpSipResult result({
      Money? finalContribution,
      Money? totalInvested,
      Money? futureValue,
      String annualStepUp = '10',
      String monthlyReturn = '1',
      String cumulativeReturn = '20',
      int months = 24,
    }) {
      return StepUpSipResult(
        initialMonthlyContribution: inr('1000'),
        finalMonthlyContribution: finalContribution ?? inr('1100'),
        totalInvested: totalInvested ?? inr('25200'),
        futureValue: futureValue ?? inr('30240'),
        monthlyEquivalentReturn: Percentage.fromPercent(monthlyReturn),
        cumulativeReturn: Percentage.fromPercent(cumulativeReturn),
        annualStepUp: Percentage.fromPercent(annualStepUp),
        tenureMonths: months,
        contributionTiming: ContributionTiming.endOfPeriod,
      );
    }

    test('derives gain and sign flags', () {
      final value = result();

      expect(value.totalGain, inr('5040'));
      expect(value.isGain, isTrue);
      expect(value.isLoss, isFalse);
    });

    test('supports a projected loss', () {
      final value = result(
        futureValue: inr('20000'),
        cumulativeReturn: '-20.6349206349',
      );

      expect(value.totalGain, inr('-5200'));
      expect(value.isLoss, isTrue);
    });

    test('permits a zero final contribution after full step-down', () {
      final value = result(
        finalContribution: inr('0'),
        totalInvested: inr('12000'),
        futureValue: inr('12000'),
        annualStepUp: '-100',
        cumulativeReturn: '0',
      );

      expect(value.finalMonthlyContribution.isZero, isTrue);
    });

    test('rejects mixed currencies', () {
      expect(
        () =>
            result(futureValue: Money.parse('30240', currency: Currencies.usd)),
        throwsArgumentError,
      );
    });

    test('rejects negative monetary outputs', () {
      expect(() => result(finalContribution: inr('-1')), throwsArgumentError);
      expect(() => result(futureValue: inr('-1')), throwsArgumentError);
    });

    test('rejects non-positive total invested', () {
      expect(() => result(totalInvested: inr('0')), throwsArgumentError);
    });

    test('rejects invalid percentages and tenure', () {
      expect(() => result(annualStepUp: '-100.01'), throwsArgumentError);
      expect(() => result(monthlyReturn: '-100.01'), throwsArgumentError);
      expect(() => result(cumulativeReturn: '-100.01'), throwsArgumentError);
      expect(() => result(months: 0), throwsArgumentError);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final value = result();
      final changed = value.copyWith(futureValue: inr('31000'));
      final expected = value.copyWith(futureValue: inr('31000'));

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('totalGain: INR 5800'));
    });
  });
}
