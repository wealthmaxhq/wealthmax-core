import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  DatedCashFlow flow(String value, DateTime date) {
    return DatedCashFlow(date: date, amount: inr(value));
  }

  group('DatedCashFlow', () {
    test('normalizes dates and exposes the cash-flow direction', () {
      final contribution = flow('-1000', DateTime(2021, 1, 1, 17, 30));
      final distribution = flow('1100', DateTime.utc(2022, 1, 1, 8));

      expect(contribution.date, DateTime.utc(2021, 1, 1));
      expect(contribution.isContribution, isTrue);
      expect(distribution.isDistribution, isTrue);
    });

    test('rejects zero cash flow', () {
      expect(() => flow('0', DateTime.utc(2021, 1, 1)), throwsArgumentError);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final value = flow('-1000', DateTime.utc(2021, 1, 1));
      final changed = value.copyWith(amount: inr('-1200'));
      final expected = value.copyWith(amount: inr('-1200'));

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('2021-01-01'));
    });
  });

  group('XirrInput', () {
    XirrInput conventional() {
      return XirrInput(
        cashFlows: <DatedCashFlow>[
          flow('1100', DateTime.utc(2022, 1, 1)),
          flow('-1000', DateTime.utc(2021, 1, 1)),
        ],
      );
    }

    test('sorts cash flows chronologically', () {
      final input = conventional();

      expect(input.cashFlows.first.amount, inr('-1000'));
      expect(input.cashFlows.last.amount, inr('1100'));
    });

    test('defensively copies and exposes an unmodifiable list', () {
      final source = <DatedCashFlow>[
        flow('-1000', DateTime.utc(2021, 1, 1)),
        flow('1100', DateTime.utc(2022, 1, 1)),
      ];
      final input = XirrInput(cashFlows: source);
      source.add(flow('1', DateTime.utc(2023, 1, 1)));

      expect(input.cashFlows, hasLength(2));
      expect(
        () => input.cashFlows.add(flow('1', DateTime.utc(2023, 1, 1))),
        throwsUnsupportedError,
      );
    });

    test('accepts multiple same-sign flows before the transition', () {
      final input = XirrInput(
        cashFlows: <DatedCashFlow>[
          flow('-1000', DateTime.utc(2021, 1, 1)),
          flow('-500', DateTime.utc(2021, 6, 1)),
          flow('1800', DateTime.utc(2022, 1, 1)),
        ],
      );

      expect(input.cashFlows, hasLength(3));
    });

    test('rejects too few, same-sign, mixed-currency, and same-date flows', () {
      expect(
        () => XirrInput(
          cashFlows: <DatedCashFlow>[flow('-1000', DateTime.utc(2021, 1, 1))],
        ),
        throwsArgumentError,
      );
      expect(
        () => XirrInput(
          cashFlows: <DatedCashFlow>[
            flow('1000', DateTime.utc(2021, 1, 1)),
            flow('1100', DateTime.utc(2022, 1, 1)),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => XirrInput(
          cashFlows: <DatedCashFlow>[
            flow('-1000', DateTime.utc(2021, 1, 1)),
            DatedCashFlow(
              date: DateTime.utc(2022, 1, 1),
              amount: Money.parse('1100', currency: Currencies.usd),
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => XirrInput(
          cashFlows: <DatedCashFlow>[
            flow('-1000', DateTime.utc(2021, 1, 1)),
            flow('1100', DateTime.utc(2021, 1, 1)),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects multiple sign transitions to avoid ambiguous roots', () {
      expect(
        () => XirrInput(
          cashFlows: <DatedCashFlow>[
            flow('-1000', DateTime.utc(2021, 1, 1)),
            flow('1500', DateTime.utc(2022, 1, 1)),
            flow('-200', DateTime.utc(2023, 1, 1)),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith, equality, hashing, and output', () {
      final input = conventional();
      final copied = input.copyWith();

      expect(copied, input);
      expect(copied.hashCode, input.hashCode);
      expect(copied.toString(), contains('DatedCashFlow'));
    });
  });

  group('XirrResult', () {
    XirrResult result({
      Money? distributions,
      Money? residual,
      DateTime? endDate,
      int cashFlowCount = 2,
    }) {
      return XirrResult(
        annualizedReturn: Percentage.fromPercent('10'),
        dailyEquivalentReturn: Percentage.fromPercent('0.0261157877'),
        totalContributions: inr('1000'),
        totalDistributions: distributions ?? inr('1100'),
        residualNpv: residual ?? inr('0'),
        startDate: DateTime.utc(2021, 1, 1),
        endDate: endDate ?? DateTime.utc(2022, 1, 1),
        cashFlowCount: cashFlowCount,
      );
    }

    test('derives net cash flow and day span', () {
      final value = result();

      expect(value.netCashFlow, inr('100'));
      expect(value.daySpan, 365);
    });

    test('normalizes output dates', () {
      final value = XirrResult(
        annualizedReturn: Percentage.fromPercent('10'),
        dailyEquivalentReturn: Percentage.fromPercent('0.02'),
        totalContributions: inr('1000'),
        totalDistributions: inr('1100'),
        residualNpv: inr('0'),
        startDate: DateTime(2021, 1, 1, 10),
        endDate: DateTime(2022, 1, 1, 20),
        cashFlowCount: 2,
      );

      expect(value.startDate, DateTime.utc(2021, 1, 1));
      expect(value.endDate, DateTime.utc(2022, 1, 1));
    });

    test('rejects invalid amounts, dates, rates, and count', () {
      expect(() => result(distributions: inr('0')), throwsArgumentError);
      expect(
        () => result(residual: Money.parse('0', currency: Currencies.usd)),
        throwsArgumentError,
      );
      expect(
        () => result(endDate: DateTime.utc(2021, 1, 1)),
        throwsArgumentError,
      );
      expect(() => result(cashFlowCount: 1), throwsArgumentError);
    });

    test('supports copyWith, equality, hashing, and output', () {
      final value = result();
      final changed = value.copyWith(totalDistributions: inr('1200'));
      final expected = value.copyWith(totalDistributions: inr('1200'));

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('netCashFlow: INR 200'));
    });
  });
}
