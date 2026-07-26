import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 11, 12);

  BreakEvenReturnInput input({
    String principal = '100000',
    String rate = '10',
    int months = 24,
    String extraCash = '10000',
    int installment = 1,
    String expenseRatio = '0',
    Currency currency = Currencies.inr,
  }) {
    return BreakEvenReturnInput(
      loan: LoanInput(
        principal: Money.parse(principal, currency: currency),
        annualInterestRate: Percentage.fromPercent(rate),
        tenureMonths: months,
      ),
      extraCash: Money.parse(extraCash, currency: currency),
      decisionInstallment: installment,
      annualExpenseRatio: Percentage.fromPercent(expenseRatio),
    );
  }

  group('CommonHorizonBreakEvenCalculator', () {
    test('zero-rate loan without fees has zero break-even return', () {
      final result = const CommonHorizonBreakEvenCalculator()
          .calculate(input(rate: '0'), calculatedAt: calculatedAt)
          .value;

      expect(
        result.breakEvenGrossAnnualReturn.percent.abs(),
        lessThan(Decimal.parse('0.01')),
      );
      expect(
        result.breakEvenNetAnnualReturn.percent.abs(),
        lessThan(Decimal.parse('0.01')),
      );
    });

    test(
      'fixed-rate threshold approximates the effective annual loan rate',
      () {
        final result = const CommonHorizonBreakEvenCalculator()
            .calculate(input(), calculatedAt: calculatedAt)
            .value;
        final monthlyRate = (Decimal.parse('0.10') / Decimal.fromInt(12))
            .toDecimal(scaleOnInfinitePrecision: 24);
        final expected =
            (_pow(Decimal.one + monthlyRate, 12) - Decimal.one) *
            Decimal.fromInt(100);

        expect(
          (result.breakEvenGrossAnnualReturn.percent - expected).abs(),
          lessThan(Decimal.parse('0.10')),
        );
      },
    );

    test('reconciles endpoint future values within one minor unit', () {
      final result = const CommonHorizonBreakEvenCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      expect(
        result.absoluteFutureValueDifference.amount,
        lessThanOrEqualTo(Decimal.parse('0.01')),
      );
      expect(result.allInvest.totalFutureValue.currency, Currencies.inr);
      expect(result.allPrepay.totalFutureValue.currency, Currencies.inr);
    });

    test('returned threshold reconciles when independently re-evaluated', () {
      final threshold = const CommonHorizonBreakEvenCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;
      final comparison = const CommonHorizonStrategyCalculator()
          .calculate(
            HybridStrategyInput(
              loan: input().loan,
              extraCash: input().extraCash,
              decisionInstallment: input().decisionInstallment,
              grossAnnualInvestmentReturn: threshold.breakEvenGrossAnnualReturn,
              annualExpenseRatio: input().annualExpenseRatio,
              allocationStepPercent: 100,
            ),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(
        (comparison.allInvestScenario.totalFutureValue -
                comparison.allPrepayScenario.totalFutureValue)
            .amount
            .abs(),
        lessThanOrEqualTo(Decimal.parse('0.01')),
      );
    });

    test('returns below threshold favor prepay and above favor invest', () {
      final threshold = const CommonHorizonBreakEvenCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value
          .breakEvenGrossAnnualReturn;
      final onePoint = Percentage.fromPercent('1');
      final below = _comparison(input(), threshold - onePoint, calculatedAt);
      final above = _comparison(input(), threshold + onePoint, calculatedAt);

      expect(
        below.allInvestScenario.totalFutureValue.compareTo(
          below.allPrepayScenario.totalFutureValue,
        ),
        lessThan(0),
      );
      expect(
        above.allInvestScenario.totalFutureValue.compareTo(
          above.allPrepayScenario.totalFutureValue,
        ),
        greaterThan(0),
      );
    });

    test(
      'expense ratio raises gross threshold while preserving net threshold',
      () {
        const calculator = CommonHorizonBreakEvenCalculator();
        final noFee = calculator
            .calculate(input(expenseRatio: '0'), calculatedAt: calculatedAt)
            .value;
        final fee = calculator
            .calculate(input(expenseRatio: '2'), calculatedAt: calculatedAt)
            .value;

        expect(
          fee.breakEvenGrossAnnualReturn.compareTo(
            noFee.breakEvenGrossAnnualReturn,
          ),
          greaterThan(0),
        );
        expect(
          (fee.breakEvenNetAnnualReturn.percent -
                  noFee.breakEvenNetAnnualReturn.percent)
              .abs(),
          lessThan(Decimal.parse('0.05')),
        );
      },
    );

    test('zero-rate loan fee threshold offsets the fee', () {
      final result = const CommonHorizonBreakEvenCalculator()
          .calculate(
            input(rate: '0', expenseRatio: '2'),
            calculatedAt: calculatedAt,
          )
          .value;
      final expectedGross =
          ((Decimal.one / Decimal.parse('0.98')).toDecimal(
                scaleOnInfinitePrecision: 24,
              ) -
              Decimal.one) *
          Decimal.fromInt(100);

      expect(
        (result.breakEvenGrossAnnualReturn.percent - expectedGross).abs(),
        lessThan(Decimal.parse('0.02')),
      );
      expect(
        result.breakEvenNetAnnualReturn.percent.abs(),
        lessThan(Decimal.parse('0.02')),
      );
    });

    test('supports partially accepted prepayment and invested excess', () {
      final result = const CommonHorizonBreakEvenCalculator().calculate(
        input(principal: '1000', extraCash: '100000'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.allPrepay.allocation.redirectedToInvestment.isPositive,
        isTrue,
      );
      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-008-PREPAYMENT-CAPPED'),
      );
      expect(
        result.value.absoluteFutureValueDifference.amount,
        lessThanOrEqualTo(Decimal.parse('0.01')),
      );
    });

    test('rejects a final-installment decision without a valid horizon', () {
      expect(
        () => const CommonHorizonBreakEvenCalculator().calculate(
          input(installment: 24),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('preserves another currency and configured rounding', () {
      final result = const CommonHorizonBreakEvenCalculator(
        roundingPolicy: RoundingPolicy.floor,
      ).calculate(input(currency: Currencies.usd), calculatedAt: calculatedAt);

      expect(result.value.allInvest.totalFutureValue.currency, Currencies.usd);
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('returns transparent OPT-008 metadata and limitations', () {
      final result = const CommonHorizonBreakEvenCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'OPT-008');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.assumptions['cashFlowTimingNormalized'], isTrue);
      expect(
        result.metadata.assumptions['reconciliationTolerance'],
        'oneCurrencyMinorUnit',
      );
      expect(result.metadata.assumptions['solver'], 'bisection');
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-008-THRESHOLD-NOT-FORECAST',
          'OPT-008-REINVESTMENT-DISCIPLINE-ASSUMED',
          'OPT-008-TAX-INFLATION-RISK-EXCLUDED',
        ]),
      );
    });

    test('supports value semantics and deterministic output', () {
      const calculator = CommonHorizonBreakEvenCalculator();
      final first = calculator.calculate(input(), calculatedAt: calculatedAt);
      final second = calculator.calculate(input(), calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.value.hashCode, second.value.hashCode);
      expect(first.value.toString(), contains('futureValueDifference'));
      expect(first.value.toString(), contains('breakEvenGrossAnnualReturn'));
    });

    test('result rejects inconsistent rates and unreconciled endpoints', () {
      final valid = const CommonHorizonBreakEvenCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      expect(
        () => CommonHorizonBreakEvenResult(
          comparison: valid.comparison,
          annualExpenseRatio: valid.annualExpenseRatio,
          breakEvenNetAnnualReturn: Percentage.fromPercent(
            (valid.breakEvenNetAnnualReturn.percent + Decimal.parse('0.01'))
                .toString(),
          ),
          breakEvenGrossAnnualReturn: valid.breakEvenGrossAnnualReturn,
        ),
        throwsArgumentError,
      );

      expect(
        () => CommonHorizonBreakEvenResult(
          comparison: _comparison(
            input(),
            Percentage.fromPercent('0'),
            calculatedAt,
          ),
          annualExpenseRatio: Percentage.fromPercent('0'),
          breakEvenNetAnnualReturn: Percentage.fromPercent('0'),
          breakEvenGrossAnnualReturn: Percentage.fromPercent('0'),
        ),
        throwsArgumentError,
      );
    });
  });
}

CommonHorizonStrategyResult _comparison(
  BreakEvenReturnInput input,
  Percentage grossReturn,
  DateTime calculatedAt,
) {
  return const CommonHorizonStrategyCalculator()
      .calculate(
        HybridStrategyInput(
          loan: input.loan,
          extraCash: input.extraCash,
          decisionInstallment: input.decisionInstallment,
          grossAnnualInvestmentReturn: grossReturn,
          annualExpenseRatio: input.annualExpenseRatio,
          allocationStepPercent: 100,
        ),
        calculatedAt: calculatedAt,
      )
      .value;
}

Decimal _pow(Decimal base, int exponent) {
  var result = Decimal.one;
  for (var index = 0; index < exponent; index++) {
    result *= base;
  }
  return result;
}
