import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);
  Money usd(String value) => Money.parse(value, currency: Currencies.usd);

  ScheduledPrepayment payment(int month, String amount) {
    return ScheduledPrepayment(installmentNumber: month, amount: inr(amount));
  }

  group('ScheduledPrepayment', () {
    test('stores installment and amount', () {
      final value = payment(12, '50000');

      expect(value.installmentNumber, 12);
      expect(value.amount, inr('50000'));
    });

    test('rejects zero installment', () {
      expect(() => payment(0, '100'), throwsArgumentError);
    });

    test('rejects negative installment', () {
      expect(() => payment(-1, '100'), throwsArgumentError);
    });

    test('rejects zero amount', () {
      expect(() => payment(1, '0'), throwsArgumentError);
    });

    test('rejects negative amount', () {
      expect(() => payment(1, '-1'), throwsArgumentError);
    });

    test('supports value equality and hash codes', () {
      expect(payment(1, '100'), payment(1, '100'));
      expect(payment(1, '100').hashCode, payment(1, '100').hashCode);
    });

    test('has deterministic string output', () {
      expect(
        payment(12, '50000').toString(),
        'ScheduledPrepayment(installmentNumber: 12, amount: INR 50000)',
      );
    });
  });

  group('PrepaymentPlan', () {
    test('sorts events by installment while retaining duplicates', () {
      final plan = PrepaymentPlan(<ScheduledPrepayment>[
        payment(12, '100'),
        payment(2, '50'),
        payment(12, '200'),
      ]);

      expect(plan.prepayments.map((value) => value.installmentNumber), <int>[
        2,
        12,
        12,
      ]);
      expect(plan.totalForInstallment(12, Currencies.inr), inr('300'));
    });

    test('defensively copies and freezes events', () {
      final source = <ScheduledPrepayment>[payment(1, '100')];
      final plan = PrepaymentPlan(source);

      source.clear();

      expect(plan.prepayments, hasLength(1));
      expect(
        () => plan.prepayments.add(payment(2, '100')),
        throwsUnsupportedError,
      );
    });

    test('supports an empty plan', () {
      final plan = PrepaymentPlan.empty();

      expect(plan.isEmpty, isTrue);
      expect(plan.total(Currencies.inr), Money.zero(Currencies.inr));
    });

    test('calculates total requested prepayment', () {
      final plan = PrepaymentPlan(<ScheduledPrepayment>[
        payment(1, '100'),
        payment(2, '250'),
      ]);

      expect(plan.total(Currencies.inr), inr('350'));
    });

    test('rejects a currency mismatch during validation', () {
      final plan = PrepaymentPlan(<ScheduledPrepayment>[
        ScheduledPrepayment(installmentNumber: 1, amount: usd('100')),
      ]);

      expect(
        () => plan.validateFor(currency: Currencies.inr, tenureMonths: 12),
        throwsArgumentError,
      );
    });

    test('rejects a prepayment after contractual tenure', () {
      final plan = PrepaymentPlan(<ScheduledPrepayment>[payment(13, '100')]);

      expect(
        () => plan.validateFor(currency: Currencies.inr, tenureMonths: 12),
        throwsArgumentError,
      );
    });

    test('supports deep value equality and hash codes', () {
      PrepaymentPlan build() => PrepaymentPlan(<ScheduledPrepayment>[
        payment(2, '100'),
        payment(1, '50'),
      ]);

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });
  });
}
