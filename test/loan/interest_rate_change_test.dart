import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  InterestRateChange change(int month, String rate) {
    return InterestRateChange(
      effectiveInstallment: month,
      annualInterestRate: Percentage.fromPercent(rate),
    );
  }

  group('InterestRateChange', () {
    test('stores its effective installment and rate', () {
      final value = change(13, '8.25');

      expect(value.effectiveInstallment, 13);
      expect(value.annualInterestRate, Percentage.fromPercent('8.25'));
    });

    test('rejects installment one because LoanInput owns the initial rate', () {
      expect(() => change(1, '8'), throwsArgumentError);
    });

    test('rejects a negative rate', () {
      expect(() => change(2, '-0.01'), throwsArgumentError);
    });

    test('accepts a zero rate', () {
      expect(() => change(2, '0'), returnsNormally);
    });

    test('supports value equality and matching hash codes', () {
      expect(change(13, '8.25'), change(13, '8.25'));
      expect(change(13, '8.25').hashCode, change(13, '8.25').hashCode);
    });

    test('has deterministic string output', () {
      expect(
        change(13, '8.25').toString(),
        'InterestRateChange(effectiveInstallment: 13, '
        'annualInterestRate: 8.25%)',
      );
    });
  });

  group('InterestRatePlan', () {
    test('sorts rate changes chronologically', () {
      final plan = InterestRatePlan(<InterestRateChange>[
        change(25, '9'),
        change(13, '8'),
      ]);

      expect(plan.changes.map((value) => value.effectiveInstallment), <int>[
        13,
        25,
      ]);
    });

    test('rejects duplicate effective installments', () {
      expect(
        () => InterestRatePlan(<InterestRateChange>[
          change(13, '8'),
          change(13, '9'),
        ]),
        throwsArgumentError,
      );
    });

    test('defensively copies and freezes changes', () {
      final source = <InterestRateChange>[change(13, '8')];
      final plan = InterestRatePlan(source);

      source.clear();

      expect(plan.changes, hasLength(1));
      expect(() => plan.changes.add(change(25, '9')), throwsUnsupportedError);
    });

    test('supports an empty plan', () {
      final plan = InterestRatePlan.empty();

      expect(plan.isEmpty, isTrue);
      expect(plan.changeAt(10), isNull);
    });

    test('looks up a change by installment', () {
      final plan = InterestRatePlan(<InterestRateChange>[change(13, '8')]);

      expect(plan.changeAt(13), change(13, '8'));
      expect(plan.changeAt(12), isNull);
    });

    test('rejects a change after contractual tenure', () {
      final plan = InterestRatePlan(<InterestRateChange>[change(25, '8')]);

      expect(() => plan.validateForTenure(24), throwsArgumentError);
    });

    test('supports deep value equality after sorting', () {
      final first = InterestRatePlan(<InterestRateChange>[
        change(25, '9'),
        change(13, '8'),
      ]);
      final second = InterestRatePlan(<InterestRateChange>[
        change(13, '8'),
        change(25, '9'),
      ]);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
