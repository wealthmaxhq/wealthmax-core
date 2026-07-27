import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 15, 12);
  final loan = LoanInput(
    principal: Money.parse('10000', currency: Currencies.inr),
    annualInterestRate: Percentage.fromPercent('10'),
    tenureMonths: 12,
  );
  final extraCash = Money.parse('1000', currency: Currencies.inr);
  final expenseRatio = Percentage.fromPercent('1');
  final investmentReturn = Percentage.fromPercent('12');
  final hybridInput = HybridStrategyInput(
    loan: loan,
    extraCash: extraCash,
    decisionInstallment: 1,
    grossAnnualInvestmentReturn: investmentReturn,
    annualExpenseRatio: expenseRatio,
    allocationStepPercent: 25,
  );
  final breakEvenInput = BreakEvenReturnInput(
    loan: loan,
    extraCash: extraCash,
    decisionInstallment: 1,
    annualExpenseRatio: expenseRatio,
  );
  final sensitivityInput = ReturnSensitivityInput(
    loan: loan,
    extraCash: extraCash,
    decisionInstallment: 1,
    annualExpenseRatio: expenseRatio,
    grossAnnualReturnScenarios: <Percentage>[
      Percentage.fromPercent('0'),
      investmentReturn,
      Percentage.fromPercent('20'),
    ],
  );
  final strategySelectionInput = StrategySelectionInput(
    hybridStrategy: hybridInput,
    objective: StrategyObjective.maximumNominalBenefit,
  );
  final commonSelectionInput = CommonHorizonStrategySelectionInput(
    hybridStrategy: hybridInput,
    objective: CommonHorizonStrategyObjective.maximumFutureValue,
  );
  final decisionAnalysisInput = CommonHorizonDecisionAnalysisInput(
    selection: commonSelectionInput,
    grossAnnualReturnScenarios: <Percentage>[
      Percentage.fromPercent('0'),
      investmentReturn,
      Percentage.fromPercent('20'),
    ],
  );

  Matcher invalidConfiguration(String parameterName) {
    return throwsA(
      isA<ArgumentError>().having((error) => error.name, 'name', parameterName),
    );
  }

  final calculators = <({String name, void Function(int, int) calculate})>[
    (
      name: 'BreakEvenReturnCalculator',
      calculate: (scale, iterations) => BreakEvenReturnCalculator(
        calculationScale: scale,
        maximumIterations: iterations,
      ).calculate(breakEvenInput, calculatedAt: calculatedAt),
    ),
    (
      name: 'CommonHorizonBreakEvenCalculator',
      calculate: (scale, iterations) => CommonHorizonBreakEvenCalculator(
        calculationScale: scale,
        maximumIterations: iterations,
      ).calculate(breakEvenInput, calculatedAt: calculatedAt),
    ),
    (
      name: 'CommonHorizonDecisionAnalysisCalculator',
      calculate: (scale, iterations) => CommonHorizonDecisionAnalysisCalculator(
        calculationScale: scale,
        maximumIterations: iterations,
      ).calculate(decisionAnalysisInput, calculatedAt: calculatedAt),
    ),
    (
      name: 'CommonHorizonSensitivityCalculator',
      calculate: (scale, iterations) => CommonHorizonSensitivityCalculator(
        calculationScale: scale,
        maximumIterations: iterations,
      ).calculate(sensitivityInput, calculatedAt: calculatedAt),
    ),
    (
      name: 'CommonHorizonStrategyCalculator',
      calculate: (scale, iterations) => CommonHorizonStrategyCalculator(
        calculationScale: scale,
        maximumIterations: iterations,
      ).calculate(hybridInput, calculatedAt: calculatedAt),
    ),
    (
      name: 'CommonHorizonStrategySelectionCalculator',
      calculate: (scale, iterations) =>
          CommonHorizonStrategySelectionCalculator(
            calculationScale: scale,
            maximumIterations: iterations,
          ).calculate(commonSelectionInput, calculatedAt: calculatedAt),
    ),
    (
      name: 'HybridStrategyCalculator',
      calculate: (scale, iterations) => HybridStrategyCalculator(
        calculationScale: scale,
        maximumIterations: iterations,
      ).calculate(hybridInput, calculatedAt: calculatedAt),
    ),
    (
      name: 'OpportunityCostCalculator',
      calculate: (scale, iterations) =>
          OpportunityCostCalculator(
            calculationScale: scale,
            maximumIterations: iterations,
          ).calculate(
            OpportunityCostInput(
              loan: loan,
              extraCash: extraCash,
              decisionInstallment: 1,
              grossAnnualInvestmentReturn: investmentReturn,
              annualExpenseRatio: expenseRatio,
            ),
            calculatedAt: calculatedAt,
          ),
    ),
    (
      name: 'PrepaymentReturnCalculator',
      calculate: (scale, iterations) =>
          PrepaymentReturnCalculator(
            calculationScale: scale,
            maximumIterations: iterations,
          ).calculate(
            PrepaymentReturnInput(
              loan: loan,
              extraCash: extraCash,
              decisionInstallment: 1,
            ),
            calculatedAt: calculatedAt,
          ),
    ),
    (
      name: 'ReturnSensitivityCalculator',
      calculate: (scale, iterations) => ReturnSensitivityCalculator(
        calculationScale: scale,
        maximumIterations: iterations,
      ).calculate(sensitivityInput, calculatedAt: calculatedAt),
    ),
    (
      name: 'StrategySelectionCalculator',
      calculate: (scale, iterations) => StrategySelectionCalculator(
        calculationScale: scale,
        maximumIterations: iterations,
      ).calculate(strategySelectionInput, calculatedAt: calculatedAt),
    ),
  ];

  group('decision calculator configuration', () {
    for (final calculator in calculators) {
      test('${calculator.name} rejects a non-positive calculation scale', () {
        expect(
          () => calculator.calculate(0, 256),
          invalidConfiguration('calculationScale'),
        );
      });

      test('${calculator.name} rejects a non-positive iteration limit', () {
        expect(
          () => calculator.calculate(32, 0),
          invalidConfiguration('maximumIterations'),
        );
      });
    }
  });
}
