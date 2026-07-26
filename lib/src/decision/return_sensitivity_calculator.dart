import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../rounding/rounding_policy.dart';
import 'break_even_return_calculator.dart';
import 'break_even_return_input.dart';
import 'opportunity_cost_calculator.dart';
import 'opportunity_cost_input.dart';
import 'return_sensitivity_input.dart';
import 'return_sensitivity_result.dart';

/// Evaluates prepay-versus-invest across ordered return assumptions.
@immutable
final class ReturnSensitivityCalculator {
  const ReturnSensitivityCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'OPT-003';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<ReturnSensitivityResult> calculate(
    ReturnSensitivityInput input, {
    required DateTime calculatedAt,
  }) {
    final breakEven =
        BreakEvenReturnCalculator(
              roundingPolicy: roundingPolicy,
              calculationScale: calculationScale,
              maximumIterations: maximumIterations,
            )
            .calculate(
              BreakEvenReturnInput(
                loan: input.loan,
                extraCash: input.extraCash,
                decisionInstallment: input.decisionInstallment,
                annualExpenseRatio: input.annualExpenseRatio,
              ),
              calculatedAt: calculatedAt,
            )
            .value;
    final comparisonCalculator = OpportunityCostCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    );
    final points = input.grossAnnualReturnScenarios
        .map(
          (scenario) => ReturnSensitivityPoint(
            grossAnnualReturn: scenario,
            comparison: comparisonCalculator
                .calculate(
                  OpportunityCostInput(
                    loan: input.loan,
                    extraCash: input.extraCash,
                    decisionInstallment: input.decisionInstallment,
                    grossAnnualInvestmentReturn: scenario,
                    annualExpenseRatio: input.annualExpenseRatio,
                  ),
                  calculatedAt: calculatedAt,
                )
                .value,
          ),
        )
        .toList(growable: false);
    final result = ReturnSensitivityResult(
      breakEven: breakEven,
      points: points,
    );

    return CalculationResult<ReturnSensitivityResult>(
      value: result,
      warnings: const <CalculationWarning>[
        CalculationWarning(
          code: 'OPT-003-SCENARIOS-NOT-PROBABILITIES',
          message:
              'Return scenarios are deterministic assumptions, not '
              'probabilities or forecasts.',
          severity: WarningSeverity.info,
        ),
        CalculationWarning(
          code: 'OPT-003-TAX-INFLATION-RISK-EXCLUDED',
          message:
              'Taxes, inflation, liquidity, risk, and cash-flow timing '
              'normalization are excluded.',
          severity: WarningSeverity.caution,
        ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'loanPrincipal': input.loan.principal.amount.toString(),
          'currency': input.loan.principal.currency.code,
          'loanAnnualInterestRatePercent': input.loan.annualInterestRate.percent
              .toString(),
          'loanTenureMonths': input.loan.tenureMonths,
          'extraCash': input.extraCash.amount.toString(),
          'decisionInstallment': input.decisionInstallment,
          'annualExpenseRatioPercent': input.annualExpenseRatio.percent
              .toString(),
          'grossAnnualReturnScenariosPercent': input.grossAnnualReturnScenarios
              .map((scenario) => scenario.percent.toString())
              .toList(growable: false),
        },
        assumptions: <String, Object?>{
          'scenarioMeaning': 'deterministicReturnAssumptions',
          'scenarioOrdering': 'ascendingGrossAnnualReturn',
          'breakEvenFormulaId': BreakEvenReturnCalculator.formulaId,
          'comparisonFormulaId': OpportunityCostCalculator.formulaId,
          'taxesIncluded': false,
          'inflationIncluded': false,
          'investmentRiskAdjusted': false,
          'cashFlowTimingNormalized': false,
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'scenarioCount': points.length,
          'breakEvenGrossAnnualReturnPercent': breakEven
              .breakEvenGrossAnnualReturn
              .percent
              .toString(),
          'prepayScenarioCount': result.prepayScenarioCount,
          'investScenarioCount': result.investScenarioCount,
          'equivalentScenarioCount': result.equivalentScenarioCount,
          'firstInvestScenarioPercent': result
              .firstInvestScenario
              ?.grossAnnualReturn
              .percent
              .toString(),
          'scenarios': points
              .map(
                (point) => <String, Object?>{
                  'grossAnnualReturnPercent': point.grossAnnualReturn.percent
                      .toString(),
                  'nominalAdvantage': point.nominalAdvantage.amount.toString(),
                  'preferredOption': point.preferredOption.name,
                },
              )
              .toList(growable: false),
        },
      ),
    );
  }
}
