import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  group('MoratoriumPlan', () {
    test('stores explicit moratorium assumptions', () {
      final plan = MoratoriumPlan(
        months: 6,
        type: MoratoriumType.fullPayment,
        tenureTreatment: MoratoriumTenureTreatment.extendTenure,
      );

      expect(plan.months, 6);
      expect(plan.type, MoratoriumType.fullPayment);
      expect(plan.tenureTreatment, MoratoriumTenureTreatment.extendTenure);
    });

    test('rejects negative months', () {
      expect(
        () => MoratoriumPlan(
          months: -1,
          type: MoratoriumType.fullPayment,
          tenureTreatment: MoratoriumTenureTreatment.extendTenure,
        ),
        throwsArgumentError,
      );
    });

    test('preserves repayment tenure when extending', () {
      final plan = MoratoriumPlan(
        months: 6,
        type: MoratoriumType.fullPayment,
        tenureTreatment: MoratoriumTenureTreatment.extendTenure,
      );

      expect(plan.repaymentTenureMonths(120), 120);
    });

    test('subtracts moratorium when kept within original tenure', () {
      final plan = MoratoriumPlan(
        months: 6,
        type: MoratoriumType.fullPayment,
        tenureTreatment: MoratoriumTenureTreatment.withinOriginalTenure,
      );

      expect(plan.repaymentTenureMonths(120), 114);
    });

    test('requires a repayment month within original tenure', () {
      final plan = MoratoriumPlan(
        months: 12,
        type: MoratoriumType.fullPayment,
        tenureTreatment: MoratoriumTenureTreatment.withinOriginalTenure,
      );

      expect(() => plan.repaymentTenureMonths(12), throwsArgumentError);
    });

    test('supports copyWith, equality, and deterministic output', () {
      final plan = MoratoriumPlan(
        months: 6,
        type: MoratoriumType.fullPayment,
        tenureTreatment: MoratoriumTenureTreatment.extendTenure,
      );
      final changed = plan.copyWith(type: MoratoriumType.interestOnly);

      expect(changed, plan.copyWith(type: MoratoriumType.interestOnly));
      expect(
        changed.hashCode,
        plan.copyWith(type: MoratoriumType.interestOnly).hashCode,
      );
      expect(changed.toString(), contains('type: interestOnly'));
    });
  });

  group('MoratoriumEntry', () {
    test('stores a reconciled capitalized-interest period', () {
      final entry = MoratoriumEntry(
        installmentNumber: 1,
        openingBalance: inr('100000'),
        interestAccrued: inr('1000'),
        payment: inr('0'),
        interestCapitalized: inr('1000'),
        closingBalance: inr('101000'),
      );

      expect(entry.interestCapitalized, inr('1000'));
      expect(entry.closingBalance, inr('101000'));
    });

    test('stores a reconciled interest-only period', () {
      final entry = MoratoriumEntry(
        installmentNumber: 1,
        openingBalance: inr('100000'),
        interestAccrued: inr('1000'),
        payment: inr('1000'),
        interestCapitalized: inr('0'),
        closingBalance: inr('100000'),
      );

      expect(entry.payment, inr('1000'));
      expect(entry.closingBalance, inr('100000'));
    });

    test('rejects non-positive installment number', () {
      expect(
        () => MoratoriumEntry(
          installmentNumber: 0,
          openingBalance: inr('100000'),
          interestAccrued: inr('1000'),
          payment: inr('0'),
          interestCapitalized: inr('1000'),
          closingBalance: inr('101000'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects mixed currency', () {
      expect(
        () => MoratoriumEntry(
          installmentNumber: 1,
          openingBalance: inr('100000'),
          interestAccrued: Money.parse('10', currency: Currencies.usd),
          payment: inr('0'),
          interestCapitalized: inr('10'),
          closingBalance: inr('100010'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects unreconciled interest', () {
      expect(
        () => MoratoriumEntry(
          installmentNumber: 1,
          openingBalance: inr('100000'),
          interestAccrued: inr('1000'),
          payment: inr('0'),
          interestCapitalized: inr('999'),
          closingBalance: inr('100999'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects unreconciled closing balance', () {
      expect(
        () => MoratoriumEntry(
          installmentNumber: 1,
          openingBalance: inr('100000'),
          interestAccrued: inr('1000'),
          payment: inr('0'),
          interestCapitalized: inr('1000'),
          closingBalance: inr('100999'),
        ),
        throwsArgumentError,
      );
    });

    test('supports value equality and deterministic output', () {
      MoratoriumEntry entry() => MoratoriumEntry(
        installmentNumber: 1,
        openingBalance: inr('100000'),
        interestAccrued: inr('1000'),
        payment: inr('0'),
        interestCapitalized: inr('1000'),
        closingBalance: inr('101000'),
      );

      expect(entry(), entry());
      expect(entry().hashCode, entry().hashCode);
      expect(entry().toString(), contains('interestCapitalized: INR 1000'));
    });
  });
}
