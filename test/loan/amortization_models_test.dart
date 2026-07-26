import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);
  Money usd(String value) => Money.parse(value, currency: Currencies.usd);

  AmortizationEntry entry({
    int number = 1,
    String opening = '100',
    String payment = '11',
    String interest = '1',
    String principal = '10',
    String closing = '90',
  }) {
    return AmortizationEntry(
      installmentNumber: number,
      openingBalance: inr(opening),
      payment: inr(payment),
      interest: inr(interest),
      principal: inr(principal),
      closingBalance: inr(closing),
    );
  }

  group('AmortizationEntry', () {
    test('stores a reconciled installment', () {
      final value = entry();

      expect(value.installmentNumber, 1);
      expect(value.openingBalance, inr('100'));
      expect(value.payment, inr('11'));
      expect(value.interest, inr('1'));
      expect(value.principal, inr('10'));
      expect(value.closingBalance, inr('90'));
    });

    test('rejects a non-positive installment number', () {
      expect(() => entry(number: 0), throwsArgumentError);
    });

    test('rejects negative monetary components', () {
      expect(() => entry(interest: '-1', principal: '12'), throwsArgumentError);
    });

    test('rejects a mixed currency', () {
      expect(
        () => AmortizationEntry(
          installmentNumber: 1,
          openingBalance: inr('100'),
          payment: usd('11'),
          interest: inr('1'),
          principal: inr('10'),
          closingBalance: inr('90'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a payment that does not reconcile', () {
      expect(() => entry(payment: '12'), throwsArgumentError);
    });

    test('rejects balances that do not reconcile', () {
      expect(() => entry(closing: '89'), throwsArgumentError);
    });

    test('supports value equality and matching hashes', () {
      expect(entry(), entry());
      expect(entry().hashCode, entry().hashCode);
    });

    test('has deterministic string output', () {
      expect(
        entry().toString(),
        'AmortizationEntry(installmentNumber: 1, '
        'openingBalance: INR 100, payment: INR 11, interest: INR 1, '
        'principal: INR 10, prepayment: INR 0, closingBalance: INR 90)',
      );
    });
  });

  group('AmortizationSchedule', () {
    test('derives totals from entries', () {
      final schedule = AmortizationSchedule(
        scheduledEmi: inr('55'),
        financedPrincipal: inr('100'),
        entries: <AmortizationEntry>[
          entry(payment: '55', interest: '5', principal: '50', closing: '50'),
          entry(
            number: 2,
            opening: '50',
            payment: '52.50',
            interest: '2.50',
            principal: '50',
            closing: '0',
          ),
        ],
      );

      expect(schedule.paymentCount, 2);
      expect(schedule.totalPrincipal, inr('100'));
      expect(schedule.totalInterest, inr('7.50'));
      expect(schedule.totalPayment, inr('107.50'));
      expect(schedule.closingBalance, inr('0'));
      expect(schedule.finalPayment, inr('52.50'));
    });

    test('defensively copies and freezes entries', () {
      final source = <AmortizationEntry>[
        entry(payment: '100', interest: '0', principal: '100', closing: '0'),
      ];
      final schedule = AmortizationSchedule(
        scheduledEmi: inr('100'),
        financedPrincipal: inr('100'),
        entries: source,
      );

      source.clear();

      expect(schedule.entries, hasLength(1));
      expect(() => schedule.entries.add(entry()), throwsUnsupportedError);
    });

    test('supports an empty schedule for zero financed principal', () {
      final schedule = AmortizationSchedule(
        scheduledEmi: inr('0'),
        financedPrincipal: inr('0'),
        entries: const <AmortizationEntry>[],
      );

      expect(schedule.paymentCount, 0);
      expect(schedule.totalPayment, inr('0'));
      expect(schedule.closingBalance, inr('0'));
      expect(schedule.finalPayment, isNull);
    });

    test('rejects empty entries for a positive principal', () {
      expect(
        () => AmortizationSchedule(
          scheduledEmi: inr('10'),
          financedPrincipal: inr('100'),
          entries: const <AmortizationEntry>[],
        ),
        throwsArgumentError,
      );
    });

    test('rejects entries for a zero principal', () {
      expect(
        () => AmortizationSchedule(
          scheduledEmi: inr('0'),
          financedPrincipal: inr('0'),
          entries: <AmortizationEntry>[
            entry(
              opening: '0',
              payment: '0',
              interest: '0',
              principal: '0',
              closing: '0',
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-consecutive installments', () {
      expect(
        () => AmortizationSchedule(
          scheduledEmi: inr('100'),
          financedPrincipal: inr('100'),
          entries: <AmortizationEntry>[
            entry(
              number: 2,
              payment: '100',
              interest: '0',
              principal: '100',
              closing: '0',
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a discontinuous balance chain', () {
      expect(
        () => AmortizationSchedule(
          scheduledEmi: inr('50'),
          financedPrincipal: inr('100'),
          entries: <AmortizationEntry>[
            entry(payment: '50', interest: '0', principal: '50', closing: '50'),
            entry(
              number: 2,
              opening: '40',
              payment: '40',
              interest: '0',
              principal: '40',
              closing: '0',
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a nonzero final balance', () {
      expect(
        () => AmortizationSchedule(
          scheduledEmi: inr('50'),
          financedPrincipal: inr('100'),
          entries: <AmortizationEntry>[
            entry(payment: '50', interest: '0', principal: '50', closing: '50'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('supports deep value equality', () {
      AmortizationSchedule build() => AmortizationSchedule(
        scheduledEmi: inr('100'),
        financedPrincipal: inr('100'),
        entries: <AmortizationEntry>[
          entry(payment: '100', interest: '0', principal: '100', closing: '0'),
        ],
      );

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });
  });
}
