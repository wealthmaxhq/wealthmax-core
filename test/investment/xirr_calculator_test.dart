import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 1, 12);

  DatedCashFlow flow(
    String value,
    int year,
    int month,
    int day, {
    Currency currency = Currencies.inr,
  }) {
    return DatedCashFlow(
      date: DateTime.utc(year, month, day),
      amount: Money.parse(value, currency: currency),
    );
  }

  XirrInput input(List<DatedCashFlow> cashFlows) {
    return XirrInput(cashFlows: cashFlows);
  }

  bool closeTo(Decimal actual, String expected, String tolerance) {
    return (actual - Decimal.parse(expected)).abs() <= Decimal.parse(tolerance);
  }

  group('XirrCalculator', () {
    test('calculates ten percent for two flows one year apart', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1),
          flow('1100', 2022, 1, 1),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(result.value.annualizedReturn.percent, '10', '0.00000001'),
        isTrue,
      );
      expect(
        result.value.residualNpv.amount.abs() <= Decimal.parse('0.000001'),
        isTrue,
      );
    });

    test('calculates ten percent for two-year compounding', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1),
          flow('1210', 2023, 1, 1),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(result.value.annualizedReturn.percent, '10', '0.00000001'),
        isTrue,
      );
    });

    test('calculates a negative realized return', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1),
          flow('900', 2022, 1, 1),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(result.value.annualizedReturn.percent, '-10', '0.00000001'),
        isTrue,
      );
      expect(result.value.dailyEquivalentReturn.isNegative, isTrue);
    });

    test('calculates zero return', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1),
          flow('1000', 2022, 1, 1),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(result.value.annualizedReturn.percent, '0', '0.00000001'),
        isTrue,
      );
      expect(
        closeTo(result.value.dailyEquivalentReturn.percent, '0', '0.00000001'),
        isTrue,
      );
    });

    test('annualizes an irregular short holding period', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1),
          flow('1100', 2021, 7, 2),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.annualizedReturn.compareTo(Percentage.fromPercent('20')),
        greaterThan(0),
      );
      expect(result.value.daySpan, 182);
    });

    test('supports multiple contributions before distribution', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1),
          flow('-100', 2021, 4, 11),
          flow('1300', 2022, 1, 1),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(result.value.annualizedReturn.isPositive, isTrue);
      expect(result.value.totalContributions.amount, Decimal.parse('1100'));
      expect(result.value.totalDistributions.amount, Decimal.parse('1300'));
      expect(result.value.cashFlowCount, 3);
      expect(
        result.value.residualNpv.amount.abs() <= Decimal.parse('0.000001'),
        isTrue,
      );
    });

    test('aggregates cash flows that occur on the same date', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1),
          flow('-500', 2021, 1, 1),
          flow('1650', 2022, 1, 1),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(result.value.annualizedReturn.percent, '10', '0.00000001'),
        isTrue,
      );
      expect(result.metadata.inputs['cashFlowCount'], 3);
      expect(result.metadata.inputs['aggregatedCashFlowCount'], 2);
    });

    test('supports reversed conventional financing cash flows', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('1000', 2021, 1, 1),
          flow('-1100', 2022, 1, 1),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(result.value.annualizedReturn.percent, '10', '0.00000001'),
        isTrue,
      );
      expect(result.warnings, hasLength(1));
      expect(
        result.warnings.single.code,
        'INV-006-REVERSED-CASH-FLOW-DIRECTION',
      );
    });

    test('uses no warning for normal investment cash-flow direction', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1),
          flow('1100', 2022, 1, 1),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings, isEmpty);
    });

    test('preserves another currency', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1, currency: Currencies.usd),
          flow('1100', 2022, 1, 1, currency: Currencies.usd),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(result.value.totalContributions.currency, Currencies.usd);
      expect(result.value.totalDistributions.currency, Currencies.usd);
      expect(result.value.residualNpv.currency, Currencies.usd);
    });

    test('returns transparent INV-006 metadata', () {
      final result = const XirrCalculator().calculate(
        input(<DatedCashFlow>[
          flow('-1000', 2021, 1, 1),
          flow('1100', 2022, 1, 1),
        ]),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'INV-006');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.assumptions['dayCountConvention'], 'actual/365');
      expect(result.metadata.assumptions['requiredSignTransitions'], 1);
      expect(
        result.metadata.assumptions['multipleRootPatternsAccepted'],
        isFalse,
      );
      expect(result.metadata.assumptions['binaryFloatingPointUsed'], isFalse);
    });

    test('is deterministic', () {
      final value = input(<DatedCashFlow>[
        flow('-1000', 2021, 1, 1),
        flow('-100', 2021, 4, 11),
        flow('1300', 2022, 1, 1),
      ]);
      const calculator = XirrCalculator();

      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
