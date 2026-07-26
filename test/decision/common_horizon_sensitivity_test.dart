import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 12, 12);

  ReturnSensitivityInput input({
    String principal = '10000',
    String rate = '10',
    int months = 12,
    String extraCash = '1000',
    int installment = 1,
    String expenseRatio = '0',
    Currency currency = Currencies.inr,
    Iterable<String> returns = const <String>['0', '10', '20'],
  }) {
    return ReturnSensitivityInput(
      loan: LoanInput(
        principal: Money.parse(principal, currency: currency),
        annualInterestRate: Percentage.fromPercent(rate),
        tenureMonths: months,
      ),
      extraCash: Money.parse(extraCash, currency: currency),
      decisionInstallment: installment,
      annualExpenseRatio: Percentage.fromPercent(expenseRatio),
      grossAnnualReturnScenarios: returns.map(Percentage.fromPercent),
    );
  }

  late CalculationResult<CommonHorizonSensitivityResult> defaultCalculation;

  setUpAll(() {
    defaultCalculation = const CommonHorizonSensitivityCalculator().calculate(
      input(),
      calculatedAt: calculatedAt,
    );
  });

  group('CommonHorizonSensitivityCalculator', () {
    test('evaluates ordered scenarios at one common horizon', () {
      final result = defaultCalculation.value;

      expect(
        result.points.map((point) => point.grossAnnualReturn.percent),
        <Decimal>[Decimal.zero, Decimal.fromInt(10), Decimal.fromInt(20)],
      );
      expect(
        result.points
            .map((point) => point.comparison.commonHorizonInstallment)
            .toSet(),
        hasLength(1),
      );
      expect(
        result.points.every((point) => point.comparison.scenarios.length == 2),
        isTrue,
      );
    });

    test('favors prepay below and invest above the normalized threshold', () {
      final result = defaultCalculation.value;

      expect(
        result.points.first.preferredOption,
        CommonHorizonPreference.prepay,
      );
      expect(
        result.points.last.preferredOption,
        CommonHorizonPreference.invest,
      );
      expect(result.prepayScenarioCount, greaterThan(0));
      expect(result.investScenarioCount, greaterThan(0));
      expect(result.firstInvestScenario, result.points.last);
    });

    test('uses the independently reproducible OPT-008 threshold', () {
      final expected = const CommonHorizonBreakEvenCalculator()
          .calculate(
            BreakEvenReturnInput(
              loan: input().loan,
              extraCash: input().extraCash,
              decisionInstallment: input().decisionInstallment,
              annualExpenseRatio: input().annualExpenseRatio,
            ),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(defaultCalculation.value.breakEven, expected);
      expect(
        defaultCalculation.value.breakEven.absoluteFutureValueDifference.amount,
        lessThanOrEqualTo(Decimal.parse('0.01')),
      );
    });

    test('reports the closest supplied scenario to break-even', () {
      final result = defaultCalculation.value;
      final threshold = result.breakEven.breakEvenGrossAnnualReturn.percent;
      final closest = result.closestScenarioToBreakEven;

      expect(
        (closest.grossAnnualReturn.percent - threshold).abs(),
        lessThanOrEqualTo(
          (result.points.first.grossAnnualReturn.percent - threshold).abs(),
        ),
      );
      expect(
        (closest.grossAnnualReturn.percent - threshold).abs(),
        lessThanOrEqualTo(
          (result.points.last.grossAnnualReturn.percent - threshold).abs(),
        ),
      );
    });

    test('future-value difference is exact and currency safe', () {
      final point = defaultCalculation.value.points.last;

      expect(
        point.futureValueDifference,
        point.comparison.allInvestScenario.totalFutureValue -
            point.comparison.allPrepayScenario.totalFutureValue,
      );
      expect(point.absoluteAdvantage.currency, Currencies.inr);
      expect(point.absoluteAdvantage.isNegative, isFalse);
    });

    test('preserves configured currency and rounding policy', () {
      final result =
          const CommonHorizonSensitivityCalculator(
            roundingPolicy: RoundingPolicy.floor,
          ).calculate(
            input(currency: Currencies.usd, returns: const <String>['0', '20']),
            calculatedAt: calculatedAt,
          );

      expect(
        result.value.points.first.futureValueDifference.currency,
        Currencies.usd,
      );
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('warns for high fees and partially accepted prepayment', () {
      final highFee = const CommonHorizonSensitivityCalculator().calculate(
        input(expenseRatio: '2', returns: const <String>['0']),
        calculatedAt: calculatedAt,
      );
      final capped = const CommonHorizonSensitivityCalculator().calculate(
        input(extraCash: '100000', returns: const <String>['10']),
        calculatedAt: calculatedAt,
      );

      expect(
        highFee.warnings.map((warning) => warning.code),
        contains('OPT-009-HIGH-EXPENSE-RATIO'),
      );
      expect(
        capped.warnings.map((warning) => warning.code),
        contains('OPT-009-PREPAYMENT-CAPPED'),
      );
    });

    test('returns transparent OPT-009 metadata and limitations', () {
      final result = defaultCalculation;

      expect(result.metadata.formulaId, 'OPT-009');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.assumptions['cashFlowTimingNormalized'], isTrue);
      expect(
        result.metadata.assumptions['breakEvenFormulaId'],
        CommonHorizonBreakEvenCalculator.formulaId,
      );
      expect(
        result.metadata.assumptions['comparisonFormulaId'],
        CommonHorizonStrategyCalculator.formulaId,
      );
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-009-SCENARIOS-NOT-PROBABILITIES',
          'OPT-009-REINVESTMENT-DISCIPLINE-ASSUMED',
          'OPT-009-TAX-INFLATION-RISK-EXCLUDED',
        ]),
      );
    });

    test('result points are immutable snapshots', () {
      final result = defaultCalculation.value;

      expect(
        () => result.points.add(result.points.first),
        throwsUnsupportedError,
      );
    });

    test('result rejects empty, mismatched, and inconsistent grids', () {
      final valid = defaultCalculation.value;

      expect(
        () => CommonHorizonSensitivityResult(
          breakEven: valid.breakEven,
          annualExpenseRatio: valid.annualExpenseRatio,
          points: const <CommonHorizonSensitivityPoint>[],
        ),
        throwsArgumentError,
      );
      expect(
        () => CommonHorizonSensitivityResult(
          breakEven: valid.breakEven,
          annualExpenseRatio: Percentage.fromPercent('1'),
          points: valid.points,
        ),
        throwsArgumentError,
      );
      expect(
        () => CommonHorizonSensitivityResult(
          breakEven: valid.breakEven,
          annualExpenseRatio: valid.annualExpenseRatio,
          points: <CommonHorizonSensitivityPoint>[
            CommonHorizonSensitivityPoint(
              grossAnnualReturn: Percentage.fromPercent('1'),
              comparison: valid.points.first.comparison,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('point rejects invalid return and non-endpoint comparison grid', () {
      final valid = defaultCalculation.value;
      final expandedComparison = const CommonHorizonStrategyCalculator()
          .calculate(
            HybridStrategyInput(
              loan: input().loan,
              extraCash: input().extraCash,
              decisionInstallment: input().decisionInstallment,
              grossAnnualInvestmentReturn: Percentage.fromPercent('10'),
              annualExpenseRatio: input().annualExpenseRatio,
              allocationStepPercent: 50,
            ),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(
        () => CommonHorizonSensitivityPoint(
          grossAnnualReturn: Percentage.fromPercent('-100.01'),
          comparison: valid.points.first.comparison,
        ),
        throwsArgumentError,
      );
      expect(
        () => CommonHorizonSensitivityPoint(
          grossAnnualReturn: Percentage.fromPercent('10'),
          comparison: expandedComparison,
        ),
        throwsArgumentError,
      );
    });

    test('supports value equality, hashing, and deterministic output', () {
      final second = const CommonHorizonSensitivityCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(defaultCalculation, second);
      expect(defaultCalculation.value.hashCode, second.value.hashCode);
      expect(
        defaultCalculation.value.toString(),
        contains('breakEvenGrossAnnualReturn'),
      );
      expect(
        defaultCalculation.value.points.first.toString(),
        contains('preferredOption'),
      );
    });
  });
}
