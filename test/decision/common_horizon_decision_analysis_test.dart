import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 14, 12);

  HybridStrategyInput strategy({
    String principal = '10000',
    String rate = '10',
    int months = 12,
    String extraCash = '1000',
    int installment = 1,
    String investmentReturn = '20',
    String expenseRatio = '0',
    int allocationStep = 25,
    Currency currency = Currencies.inr,
  }) {
    return HybridStrategyInput(
      loan: LoanInput(
        principal: Money.parse(principal, currency: currency),
        annualInterestRate: Percentage.fromPercent(rate),
        tenureMonths: months,
      ),
      extraCash: Money.parse(extraCash, currency: currency),
      decisionInstallment: installment,
      grossAnnualInvestmentReturn: Percentage.fromPercent(investmentReturn),
      annualExpenseRatio: Percentage.fromPercent(expenseRatio),
      allocationStepPercent: allocationStep,
    );
  }

  CommonHorizonDecisionAnalysisInput input({
    HybridStrategyInput? hybridStrategy,
    CommonHorizonStrategyObjective objective =
        CommonHorizonStrategyObjective.maximumFutureValue,
    Iterable<String> returns = const <String>['0', '20', '30'],
  }) {
    return CommonHorizonDecisionAnalysisInput(
      selection: CommonHorizonStrategySelectionInput(
        hybridStrategy: hybridStrategy ?? strategy(),
        objective: objective,
      ),
      grossAnnualReturnScenarios: returns.map(Percentage.fromPercent),
    );
  }

  late CalculationResult<CommonHorizonDecisionAnalysisResult>
  defaultCalculation;

  setUpAll(() {
    defaultCalculation = const CommonHorizonDecisionAnalysisCalculator()
        .calculate(input(), calculatedAt: calculatedAt);
  });

  group('CommonHorizonDecisionAnalysisInput', () {
    test('sorts scenarios and requires the selected return', () {
      final value = input(returns: const <String>['30', '0', '20']);

      expect(value.grossAnnualReturnScenarios, <Percentage>[
        Percentage.fromPercent('0'),
        Percentage.fromPercent('20'),
        Percentage.fromPercent('30'),
      ]);
      expect(
        () => input(returns: const <String>['0', '30']),
        throwsArgumentError,
      );
    });

    test('supports copyWith, equality, hashing, and output', () {
      final original = input();
      final same = original.copyWith();
      final changed = original.copyWith(
        selection: original.selection.copyWith(
          objective: CommonHorizonStrategyObjective.fastestDebtFree,
        ),
      );

      expect(same, original);
      expect(same.hashCode, original.hashCode);
      expect(changed, isNot(original));
      expect(original.toString(), contains('grossAnnualReturnScenarios'));
    });
  });

  group('CommonHorizonDecisionAnalysisCalculator', () {
    test('matches standalone normalized selection', () {
      final standalone = const CommonHorizonStrategySelectionCalculator()
          .calculate(input().selection, calculatedAt: calculatedAt);

      expect(defaultCalculation.value.selection, standalone.value);
    });

    test('matches standalone normalized sensitivity', () {
      final source = input();
      final standalone = const CommonHorizonSensitivityCalculator().calculate(
        source.sensitivity,
        calculatedAt: calculatedAt,
      );

      expect(defaultCalculation.value.sensitivity, standalone.value);
    });

    test('reuses selected-return endpoint scenario instances', () {
      final result = defaultCalculation.value;
      final reusedPoint = result.selectedReturnSensitivityPoint;

      expect(
        reusedPoint.comparison.allInvestScenario,
        same(result.optimization.allInvestScenario),
      );
      expect(
        reusedPoint.comparison.allPrepayScenario,
        same(result.optimization.allPrepayScenario),
      );
    });

    test('reports one avoided duplicate strategy evaluation', () {
      final result = defaultCalculation.value;

      expect(result.uniqueStrategyEvaluationCount, 3);
      expect(result.avoidedStrategyEvaluationCount, 1);
      expect(
        defaultCalculation
            .metadata
            .details['standaloneStrategyEvaluationCount'],
        4,
      );
      expect(
        defaultCalculation
            .metadata
            .assumptions['selectedReturnEndpointsReused'],
        isTrue,
      );
    });

    test('public selector reuses an existing optimization', () {
      final result = defaultCalculation.value;
      final selected = const CommonHorizonStrategySelectionCalculator()
          .selectFrom(
            result.optimization,
            CommonHorizonStrategyObjective.fastestDebtFree,
          );

      expect(
        selected.selectedScenario,
        selected.optimization.allPrepayScenario,
      );
      expect(selected.optimization, same(result.optimization));
    });

    test('preserves another currency and configured rounding', () {
      final result =
          const CommonHorizonDecisionAnalysisCalculator(
            roundingPolicy: RoundingPolicy.floor,
          ).calculate(
            input(hybridStrategy: strategy(currency: Currencies.usd)),
            calculatedAt: calculatedAt,
          );

      expect(
        result.value.selection.selectedScenario.totalFutureValue.currency,
        Currencies.usd,
      );
      expect(
        result.metadata.assumptions['roundingPolicy'],
        RoundingPolicy.floor.name,
      );
    });

    test('propagates material prepayment disclosure', () {
      final result = const CommonHorizonDecisionAnalysisCalculator().calculate(
        input(hybridStrategy: strategy(extraCash: '100000')),
        calculatedAt: calculatedAt,
      );

      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-007-PREPAYMENT-CAPPED'),
      );
      expect(
        result.warnings.map((warning) => warning.code),
        contains('OPT-008-PREPAYMENT-CAPPED'),
      );
    });

    test('returns transparent OPT-011 metadata and limitations', () {
      final result = defaultCalculation;

      expect(result.metadata.formulaId, 'OPT-011');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.assumptions['cashFlowTimingNormalized'], isTrue);
      expect(result.metadata.assumptions['weightedScoreUsed'], isFalse);
      expect(
        result.metadata.details['commonHorizonSelectionFormulaId'],
        CommonHorizonStrategySelectionCalculator.formulaId,
      );
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-011-CONSOLIDATED-ANALYSIS',
          'OPT-011-OBJECTIVE-DEPENDENT',
          'OPT-011-SCENARIOS-NOT-PROBABILITIES',
        ]),
      );
    });

    test('result rejects invalid reuse accounting and missing scenario', () {
      final valid = defaultCalculation.value;

      expect(
        () => CommonHorizonDecisionAnalysisResult(
          selection: valid.selection,
          sensitivity: valid.sensitivity,
          selectedGrossAnnualReturn: valid.selectedGrossAnnualReturn,
          uniqueStrategyEvaluationCount: 99,
          avoidedStrategyEvaluationCount: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => CommonHorizonDecisionAnalysisResult(
          selection: valid.selection,
          sensitivity: valid.sensitivity,
          selectedGrossAnnualReturn: Percentage.fromPercent('25'),
          uniqueStrategyEvaluationCount: valid.sensitivity.points.length,
          avoidedStrategyEvaluationCount: 1,
        ),
        throwsArgumentError,
      );
    });

    test('supports value equality, hashing, and deterministic output', () {
      final second = const CommonHorizonDecisionAnalysisCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(defaultCalculation, second);
      expect(defaultCalculation.value.hashCode, second.value.hashCode);
      expect(
        defaultCalculation.value.toString(),
        contains('avoidedStrategyEvaluationCount: 1'),
      );
    });
  });
}
