import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../investment/inflation_adjustment_calculator.dart';
import '../investment/inflation_adjustment_input.dart';
import '../money/money.dart';
import '../rounding/rounding_policy.dart';
import 'adjusted_decision_analysis_input.dart';
import 'adjusted_decision_analysis_result.dart';
import 'common_horizon_decision_analysis_calculator.dart';
import 'common_horizon_strategy_selection_input.dart';

/// Applies a transparent end-of-horizon tax and inflation layer to OPT-011.
///
/// Formula `OPT-012` taxes positive investment gains only. Investment basis is
/// the initial invested amount plus nominal reinvested payment savings.
/// Inflation then discounts every after-tax common-horizon value with INV-008.
@immutable
final class AdjustedDecisionAnalysisCalculator {
  const AdjustedDecisionAnalysisCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'OPT-012';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<AdjustedDecisionAnalysisResult> calculate(
    AdjustedDecisionAnalysisInput input, {
    required DateTime calculatedAt,
  }) {
    final nominalCalculation = CommonHorizonDecisionAnalysisCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    ).calculate(input.analysis, calculatedAt: calculatedAt);
    final nominal = nominalCalculation.value;
    final horizonMonths = nominal.optimization.commonHorizonInstallment;
    final inflationCalculator = InflationAdjustmentCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    );
    final adjusted = nominal.optimization.scenarios
        .map((scenario) {
          final currency = scenario.totalFutureValue.currency;
          final basis =
              scenario.allocation.investedAmount +
              scenario.nominalPaymentSavings;
          final rawGain = scenario.totalFutureValue - basis;
          final taxableGain = rawGain.isPositive
              ? rawGain
              : Money.zero(currency);
          final tax = Money(
            amount: roundingPolicy.round(
              taxableGain.amount * input.investmentGainTaxRate.fraction,
              decimalPlaces: currency.decimalPlaces,
            ),
            currency: currency,
          );
          final afterTax = scenario.totalFutureValue - tax;
          final realValue = inflationCalculator
              .calculate(
                InflationAdjustmentInput(
                  nominalFutureValue: afterTax,
                  annualInflationRate: input.annualInflationRate,
                  horizonMonths: horizonMonths,
                ),
                calculatedAt: calculatedAt,
              )
              .value
              .realValue;
          return AdjustedDecisionScenario(
            nominalScenario: scenario,
            taxableInvestmentGain: taxableGain,
            estimatedTax: tax,
            afterTaxFutureValue: afterTax,
            realAfterTaxFutureValue: realValue,
          );
        })
        .toList(growable: false);
    final selectedIndex = _selectIndex(
      adjusted,
      input.analysis.selection.objective,
    );
    final result = AdjustedDecisionAnalysisResult(
      nominalAnalysis: nominal,
      scenarios: adjusted,
      selectedScenarioIndex: selectedIndex,
      investmentGainTaxRate: input.investmentGainTaxRate,
      annualInflationRate: input.annualInflationRate,
    );

    final warnings = <String, CalculationWarning>{
      for (final warning in nominalCalculation.warnings) warning.code: warning,
      'OPT-012-TAX-SIMPLIFICATION': const CalculationWarning(
        code: 'OPT-012-TAX-SIMPLIFICATION',
        message:
            'Tax is estimated with one flat rate on positive investment gains '
            'at the common horizon; exemptions, loss offsets, tax lots, and '
            'interim taxable events are not modeled.',
        severity: WarningSeverity.caution,
      ),
      'OPT-012-INFLATION-ASSUMPTION': const CalculationWarning(
        code: 'OPT-012-INFLATION-ASSUMPTION',
        message:
            'Real values depend on a constant inflation assumption and are '
            'estimates of present purchasing power.',
        severity: WarningSeverity.info,
      ),
    };

    return CalculationResult<AdjustedDecisionAnalysisResult>(
      value: result,
      warnings: warnings.values,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'investmentGainTaxRatePercent': input.investmentGainTaxRate.percent
              .toString(),
          'annualInflationRatePercent': input.annualInflationRate.percent
              .toString(),
          'objective': input.analysis.selection.objective.name,
        },
        assumptions: <String, Object?>{
          'taxBase': 'positiveInvestmentGainOnly',
          'investmentBasis':
              'initialInvestedAmountPlusNominalReinvestedPaymentSavings',
          'taxTiming': 'commonHorizon',
          'flatTaxRate': true,
          'lossTaxBenefitIncluded': false,
          'inflationConvention': 'effectiveAnnualRate',
          'inflationRateConstant': true,
          'inflationChangesRanking': false,
          'financialAdvice': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'nominalAnalysisFormulaId':
              CommonHorizonDecisionAnalysisCalculator.formulaId,
          'inflationAdjustmentFormulaId':
              InflationAdjustmentCalculator.formulaId,
          'commonHorizonMonths': horizonMonths,
          'scenarioCount': adjusted.length,
          'nominalSelectedScenarioIndex':
              nominal.selection.selectedScenarioIndex,
          'adjustedSelectedScenarioIndex': selectedIndex,
          'selectionChangedByTax': result.selectionChangedByTax,
          'selectedEstimatedTax': result.selectedScenario.estimatedTax.amount
              .toString(),
          'selectedAfterTaxFutureValue': result
              .selectedScenario
              .afterTaxFutureValue
              .amount
              .toString(),
          'selectedRealAfterTaxFutureValue': result
              .selectedScenario
              .realAfterTaxFutureValue
              .amount
              .toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }

  int _selectIndex(
    List<AdjustedDecisionScenario> scenarios,
    CommonHorizonStrategyObjective objective,
  ) {
    var selected = 0;
    for (var index = 1; index < scenarios.length; index++) {
      if (_compare(scenarios[index], scenarios[selected], objective) > 0) {
        selected = index;
      }
    }
    return selected;
  }

  int _compare(
    AdjustedDecisionScenario candidate,
    AdjustedDecisionScenario current,
    CommonHorizonStrategyObjective objective,
  ) {
    final candidateAllocation = candidate.nominalScenario.allocation;
    final currentAllocation = current.nominalScenario.allocation;
    final futureValueComparison = candidate.afterTaxFutureValue.compareTo(
      current.afterTaxFutureValue,
    );
    final comparisons = switch (objective) {
      CommonHorizonStrategyObjective.maximumFutureValue => <int>[
        futureValueComparison,
        candidateAllocation.investedAmount.compareTo(
          currentAllocation.investedAmount,
        ),
      ],
      CommonHorizonStrategyObjective.minimumInterestCost => <int>[
        candidateAllocation.interestSaved.compareTo(
          currentAllocation.interestSaved,
        ),
        candidateAllocation.installmentsReduced.compareTo(
          currentAllocation.installmentsReduced,
        ),
        futureValueComparison,
        candidateAllocation.investedAmount.compareTo(
          currentAllocation.investedAmount,
        ),
      ],
      CommonHorizonStrategyObjective.fastestDebtFree => <int>[
        candidateAllocation.installmentsReduced.compareTo(
          currentAllocation.installmentsReduced,
        ),
        candidateAllocation.interestSaved.compareTo(
          currentAllocation.interestSaved,
        ),
        futureValueComparison,
        candidateAllocation.investedAmount.compareTo(
          currentAllocation.investedAmount,
        ),
      ],
      CommonHorizonStrategyObjective.maximumInvestedCapital => <int>[
        candidateAllocation.investedAmount.compareTo(
          currentAllocation.investedAmount,
        ),
        futureValueComparison,
      ],
    };
    for (final comparison in comparisons) {
      if (comparison != 0) return comparison;
    }
    return 0;
  }
}
