import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  group('SwpInput', () {
    SwpInput input({
      Money? initialInvestment,
      Money? monthlyWithdrawal,
      String annualReturn = '8',
      int months = 120,
      WithdrawalTiming timing = WithdrawalTiming.endOfPeriod,
    }) {
      return SwpInput(
        initialInvestment: initialInvestment ?? inr('1000000'),
        monthlyWithdrawal: monthlyWithdrawal ?? inr('10000'),
        expectedAnnualReturn: Percentage.fromPercent(annualReturn),
        tenureMonths: months,
        withdrawalTiming: timing,
      );
    }

    test('stores explicit withdrawal assumptions', () {
      final value = input(timing: WithdrawalTiming.beginningOfPeriod);

      expect(value.initialInvestment, inr('1000000'));
      expect(value.monthlyWithdrawal, inr('10000'));
      expect(value.expectedAnnualReturn, Percentage.fromPercent('8'));
      expect(value.tenureMonths, 120);
      expect(value.withdrawalTiming, WithdrawalTiming.beginningOfPeriod);
    });

    test('accepts zero and total-loss returns', () {
      expect(input(annualReturn: '0').expectedAnnualReturn.isZero, isTrue);
      expect(
        input(annualReturn: '-100').expectedAnnualReturn,
        Percentage.fromPercent('-100'),
      );
    });

    test('rejects non-positive investment and withdrawal', () {
      expect(() => input(initialInvestment: inr('0')), throwsArgumentError);
      expect(() => input(monthlyWithdrawal: inr('-1')), throwsArgumentError);
    });

    test('rejects mixed currencies', () {
      expect(
        () => input(
          monthlyWithdrawal: Money.parse('10000', currency: Currencies.usd),
        ),
        throwsArgumentError,
      );
    });

    test('rejects return below total loss and non-positive tenure', () {
      expect(() => input(annualReturn: '-100.01'), throwsArgumentError);
      expect(() => input(months: 0), throwsArgumentError);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final value = input();
      final changed = value.copyWith(
        withdrawalTiming: WithdrawalTiming.beginningOfPeriod,
      );
      final expected = value.copyWith(
        withdrawalTiming: WithdrawalTiming.beginningOfPeriod,
      );

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('beginningOfPeriod'));
    });
  });

  group('SwpResult', () {
    SwpResult result({
      Money? monthlyWithdrawal,
      Money? totalWithdrawn,
      Money? endingBalance,
      int tenureMonths = 12,
      int monthsProcessed = 12,
      int withdrawalsMade = 12,
      int fullWithdrawalsMade = 12,
      int? depletionMonth,
      String monthlyReturn = '1',
    }) {
      return SwpResult(
        initialInvestment: inr('20000'),
        monthlyWithdrawal: monthlyWithdrawal ?? inr('1000'),
        totalWithdrawn: totalWithdrawn ?? inr('12000'),
        endingBalance: endingBalance ?? inr('9500'),
        monthlyEquivalentReturn: Percentage.fromPercent(monthlyReturn),
        tenureMonths: tenureMonths,
        monthsProcessed: monthsProcessed,
        withdrawalsMade: withdrawalsMade,
        fullWithdrawalsMade: fullWithdrawalsMade,
        depletionMonth: depletionMonth,
        withdrawalTiming: WithdrawalTiming.endOfPeriod,
      );
    }

    test('derives requested withdrawals, value received, and net gain', () {
      final value = result();

      expect(value.requestedTotalWithdrawal, inr('12000'));
      expect(value.withdrawalShortfall, inr('0'));
      expect(value.totalValueReceived, inr('21500'));
      expect(value.netGain, inr('1500'));
      expect(value.isFullyFunded, isTrue);
      expect(value.isDepleted, isFalse);
    });

    test('represents early depletion and withdrawal shortfall', () {
      final value = result(
        totalWithdrawn: inr('5000'),
        endingBalance: inr('0'),
        monthsProcessed: 5,
        withdrawalsMade: 5,
        fullWithdrawalsMade: 5,
        depletionMonth: 5,
      );

      expect(value.withdrawalShortfall, inr('7000'));
      expect(value.isFullyFunded, isFalse);
      expect(value.isDepleted, isTrue);
      expect(value.isDepletedEarly, isTrue);
    });

    test('distinguishes depletion in the final month', () {
      final value = result(endingBalance: inr('0'), depletionMonth: 12);

      expect(value.isDepleted, isTrue);
      expect(value.isDepletedEarly, isFalse);
      expect(value.isFullyFunded, isTrue);
    });

    test('rejects mixed currencies and negative outputs', () {
      expect(
        () => result(
          endingBalance: Money.parse('9500', currency: Currencies.usd),
        ),
        throwsArgumentError,
      );
      expect(() => result(totalWithdrawn: inr('-1')), throwsArgumentError);
    });

    test('rejects invalid month and withdrawal counters', () {
      expect(() => result(monthsProcessed: 0), throwsArgumentError);
      expect(() => result(withdrawalsMade: 13), throwsArgumentError);
      expect(() => result(fullWithdrawalsMade: 13), throwsArgumentError);
    });

    test('rejects inconsistent depletion details', () {
      expect(() => result(depletionMonth: 5), throwsArgumentError);
      expect(
        () => result(
          endingBalance: inr('0'),
          monthsProcessed: 4,
          withdrawalsMade: 4,
          fullWithdrawalsMade: 4,
          depletionMonth: 5,
        ),
        throwsArgumentError,
      );
    });

    test('rejects incomplete non-depleted projection', () {
      expect(
        () => result(
          monthsProcessed: 5,
          withdrawalsMade: 5,
          fullWithdrawalsMade: 5,
        ),
        throwsArgumentError,
      );
    });

    test('rejects excessive withdrawals and invalid monthly return', () {
      expect(
        () => result(totalWithdrawn: inr('12000.01')),
        throwsArgumentError,
      );
      expect(() => result(monthlyReturn: '-100.01'), throwsArgumentError);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final value = result();
      final changed = value.copyWith(endingBalance: inr('10000'));
      final expected = value.copyWith(endingBalance: inr('10000'));

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('netGain: INR 2000'));
    });

    test('copyWith can clear depletion state consistently', () {
      final depleted = result(endingBalance: inr('0'), depletionMonth: 12);
      final sustained = depleted.copyWith(
        endingBalance: inr('1'),
        clearDepletionMonth: true,
      );

      expect(sustained.depletionMonth, isNull);
      expect(sustained.isDepleted, isFalse);
    });
  });
}
