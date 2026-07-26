import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);
  Money usd(String value) => Money.parse(value, currency: Currencies.usd);

  ScheduledEmiChange change(int month, String emi) {
    return ScheduledEmiChange(effectiveInstallment: month, newEmi: inr(emi));
  }

  group('ScheduledEmiChange', () {
    test('stores effective installment and new EMI', () {
      final value = change(13, '25000');

      expect(value.effectiveInstallment, 13);
      expect(value.newEmi, inr('25000'));
    });

    test('rejects installment one', () {
      expect(() => change(1, '100'), throwsArgumentError);
    });

    test('rejects zero EMI', () {
      expect(() => change(2, '0'), throwsArgumentError);
    });

    test('rejects negative EMI', () {
      expect(() => change(2, '-1'), throwsArgumentError);
    });

    test('supports value equality and hash codes', () {
      expect(change(13, '25000'), change(13, '25000'));
      expect(change(13, '25000').hashCode, change(13, '25000').hashCode);
    });

    test('has deterministic string output', () {
      expect(
        change(13, '25000').toString(),
        'ScheduledEmiChange(effectiveInstallment: 13, newEmi: INR 25000)',
      );
    });
  });

  group('EmiChangePlan', () {
    test('sorts changes chronologically', () {
      final plan = EmiChangePlan(<ScheduledEmiChange>[
        change(25, '30000'),
        change(13, '25000'),
      ]);

      expect(plan.changes.map((value) => value.effectiveInstallment), <int>[
        13,
        25,
      ]);
    });

    test('rejects duplicate installments', () {
      expect(
        () => EmiChangePlan(<ScheduledEmiChange>[
          change(13, '25000'),
          change(13, '30000'),
        ]),
        throwsArgumentError,
      );
    });

    test('defensively copies and freezes changes', () {
      final source = <ScheduledEmiChange>[change(13, '25000')];
      final plan = EmiChangePlan(source);

      source.clear();

      expect(plan.changes, hasLength(1));
      expect(
        () => plan.changes.add(change(25, '30000')),
        throwsUnsupportedError,
      );
    });

    test('supports an empty plan', () {
      final plan = EmiChangePlan.empty();

      expect(plan.isEmpty, isTrue);
      expect(plan.changeAt(13), isNull);
    });

    test('looks up changes by installment', () {
      final plan = EmiChangePlan(<ScheduledEmiChange>[change(13, '25000')]);

      expect(plan.changeAt(13), change(13, '25000'));
      expect(plan.changeAt(12), isNull);
    });

    test('rejects a mixed currency during validation', () {
      final plan = EmiChangePlan(<ScheduledEmiChange>[
        ScheduledEmiChange(effectiveInstallment: 2, newEmi: usd('100')),
      ]);

      expect(
        () => plan.validateFor(currency: Currencies.inr, maxInstallments: 12),
        throwsArgumentError,
      );
    });

    test('rejects a change after calculation limit', () {
      final plan = EmiChangePlan(<ScheduledEmiChange>[change(13, '100')]);

      expect(
        () => plan.validateFor(currency: Currencies.inr, maxInstallments: 12),
        throwsArgumentError,
      );
    });

    test('supports deep value equality after sorting', () {
      final first = EmiChangePlan(<ScheduledEmiChange>[
        change(25, '30000'),
        change(13, '25000'),
      ]);
      final second = EmiChangePlan(<ScheduledEmiChange>[
        change(13, '25000'),
        change(25, '30000'),
      ]);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });

  group('EmiPaymentPeriod', () {
    test('stores installment and EMI', () {
      final period = EmiPaymentPeriod(
        effectiveInstallment: 1,
        scheduledEmi: inr('100'),
      );

      expect(period.effectiveInstallment, 1);
      expect(period.scheduledEmi, inr('100'));
    });

    test('accepts zero EMI for a fully prepaid loan', () {
      expect(
        () => EmiPaymentPeriod(effectiveInstallment: 1, scheduledEmi: inr('0')),
        returnsNormally,
      );
    });

    test('rejects negative EMI', () {
      expect(
        () =>
            EmiPaymentPeriod(effectiveInstallment: 1, scheduledEmi: inr('-1')),
        throwsArgumentError,
      );
    });

    test('supports value equality and deterministic output', () {
      final first = EmiPaymentPeriod(
        effectiveInstallment: 1,
        scheduledEmi: inr('100'),
      );
      final second = EmiPaymentPeriod(
        effectiveInstallment: 1,
        scheduledEmi: inr('100'),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first.toString(),
        'EmiPaymentPeriod(effectiveInstallment: 1, scheduledEmi: INR 100)',
      );
    });
  });
}
