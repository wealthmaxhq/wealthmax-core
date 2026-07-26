import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../rounding/rounding_policy.dart';
import 'break_even_return_input.dart';
import 'common_horizon_break_even_calculator.dart';
import 'common_horizon_sensitivity_result.dart';
import 'common_horizon_strategy_calculator.dart';
import 'hybrid_strategy_input.dart';
import 'return_sensitivity_input.dart';

/// Evaluates ordered return assumptions at one normalized future horizon.
///
/// Formula `OPT-009` combines the OPT-008 break-even threshold with OPT-007
/// endpoint comparisons so every scenario uses equivalent cash-flow timing.
@immutable
final class CommonHorizonSensitivityCalculator {
  const CommonHorizonSensitivityCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'OPT-009';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<CommonHorizonSensitivityResult> calculate(
    ReturnSensitivityInput input, {
    required DateTime calculatedAt,
  }) {
    final breakEven =
        CommonHorizonBreakEvenCalculator(
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
    final comparisonCalculator = CommonHorizonStrategyCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    );
    final points = input.grossAnnualReturnScenarios
        .map(
          (scenario) => CommonHorizonSensitivityPoint(
            grossAnnualReturn: scenario,
            comparison: comparisonCalculator
                .calculate(
                  HybridStrategyInput(
                    loan: input.loan,
                    extraCash: input.extraCash,
                    decisionInstallment: input.decisionInstallment,
                    grossAnnualInvestmentReturn: scenario,
                    annualExpenseRatio: input.annualExpenseRatio,
                    allocationStepPercent: 100,
                  ),
                  calculatedAt: calculatedAt,
                )
                .value,
          ),
        )
        .toList(growable: false);
    final result = CommonHorizonSensitivityResult(
      breakEven: breakEven,
      annualExpenseRatio: input.annualExpenseRatio,
      points: points,
    );

    return CalculationResult<CommonHorizonSensitivityResult>(
      value: result,
      warnings: <CalculationWarning>[
        const CalculationWarning(
          code: 'OPT-009-SCENARIOS-NOT-PROBABILITIES',
          message:
              'Return scenarios are deterministic assumptions, not '
              'probabilities, forecasts, or guarantees.',
          severity: WarningSeverity.info,
        ),
        const CalculationWarning(
          code: 'OPT-009-REINVESTMENT-DISCIPLINE-ASSUMED',
          message:
              'Every loan-payment saving from prepayment is assumed to be '
              'reinvested when it occurs until the common horizon.',
          severity: WarningSeverity.caution,
        ),
        const CalculationWarning(
          code: 'OPT-009-TAX-INFLATION-RISK-EXCLUDED',
          message:
              'Taxes, inflation, liquidity needs, and investment risk are '
              'excluded and can change the practical comparison.',
          severity: WarningSeverity.caution,
        ),
        if (input.annualExpenseRatio.percent >= Decimal.fromInt(2))
          const CalculationWarning(
            code: 'OPT-009-HIGH-EXPENSE-RATIO',
            message:
                'An expense ratio of 2% or more materially reduces '
                'investment outcomes.',
            severity: WarningSeverity.caution,
          ),
        if (points.any(
          (point) => point
              .comparison
              .allPrepayScenario
              .allocation
              .redirectedToInvestment
              .isPositive,
        ))
          const CalculationWarning(
            code: 'OPT-009-PREPAYMENT-CAPPED',
            message:
                'The loan accepted only part of the requested prepayment; '
                'excess cash is invested in the endpoint comparisons.',
            severity: WarningSeverity.info,
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
          'comparisonHorizon': 'baselineLoanPayoffInstallment',
          'cashFlowTimingNormalized': true,
          'savedPaymentTreatment': 'fullyReinvestedToCommonHorizon',
          'breakEvenFormulaId': CommonHorizonBreakEvenCalculator.formulaId,
          'comparisonFormulaId': CommonHorizonStrategyCalculator.formulaId,
          'feeConvention': 'endOfYearAssetBasedFee',
          'taxesIncluded': false,
          'inflationIncluded': false,
          'investmentRiskAdjusted': false,
          'financialAdvice': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'scenarioCount': points.length,
          'commonHorizonInstallment':
              breakEven.comparison.commonHorizonInstallment,
          'breakEvenGrossAnnualReturnPercent': breakEven
              .breakEvenGrossAnnualReturn
              .percent
              .toString(),
          'breakEvenNetAnnualReturnPercent': breakEven
              .breakEvenNetAnnualReturn
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
          'closestScenarioToBreakEvenPercent': result
              .closestScenarioToBreakEven
              .grossAnnualReturn
              .percent
              .toString(),
          'scenarios': points
              .map(
                (point) => <String, Object?>{
                  'grossAnnualReturnPercent': point.grossAnnualReturn.percent
                      .toString(),
                  'futureValueDifference': point.futureValueDifference.amount
                      .toString(),
                  'preferredOption': point.preferredOption.name,
                },
              )
              .toList(growable: false),
        },
      ),
    );
  }
}
