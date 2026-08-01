import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'decision_analysis_report_calculator.dart';
import 'weighted_decision_analysis_input.dart';
import 'weighted_decision_analysis_result.dart';

/// Calculates probability-weighted selected outcomes across REP-001 cases.
///
/// Formula `REP-003` uses exact decimal weights and rounds monetary aggregates
/// only after every weighted case contribution has been summed.
@immutable
final class WeightedDecisionAnalysisCalculator {
  const WeightedDecisionAnalysisCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
  });

  static const String formulaId = 'REP-003';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;

  CalculationResult<WeightedDecisionAnalysisResult> calculate(
    WeightedDecisionAnalysisInput input, {
    required DateTime calculatedAt,
  }) {
    final report = input.report;
    final currency = report.value.selectedRealValueRange.currency;
    var rawAfterTax = Decimal.zero;
    var rawRealAfterTax = Decimal.zero;
    var rawTax = Decimal.zero;
    var expectedAllocationPercent = Decimal.zero;
    var changedProbabilityPercent = Decimal.zero;

    for (final reportCase in report.value.cases) {
      final probability = input.weightFor(reportCase.id).probability;
      final fraction = probability.fraction;
      final selected = reportCase.analysis.selectedScenario;
      rawAfterTax += selected.afterTaxFutureValue.amount * fraction;
      rawRealAfterTax += selected.realAfterTaxFutureValue.amount * fraction;
      rawTax += selected.estimatedTax.amount * fraction;
      expectedAllocationPercent +=
          selected.nominalScenario.requestedPrepaymentAllocation.percent *
          fraction;
      if (reportCase.analysis.selectionChangedByTax) {
        changedProbabilityPercent += probability.percent;
      }
    }

    Money roundedMoney(Decimal amount) => Money(
      amount: roundingPolicy.round(
        amount,
        decimalPlaces: currency.decimalPlaces,
      ),
      currency: currency,
    );

    final result = WeightedDecisionAnalysisResult(
      report: report,
      weights: input.weights,
      expectedAfterTaxFutureValue: roundedMoney(rawAfterTax),
      expectedRealAfterTaxFutureValue: roundedMoney(rawRealAfterTax),
      expectedEstimatedTax: roundedMoney(rawTax),
      expectedPrepaymentAllocation: Percentage.fromPercent(
        expectedAllocationPercent.toString(),
      ),
      probabilitySelectionChangedByTax: Percentage.fromPercent(
        changedProbabilityPercent.toString(),
      ),
    );
    final warningsByCode = <String, CalculationWarning>{
      for (final warning in report.warnings) warning.code: warning,
      'REP-003-SUBJECTIVE-PROBABILITIES': const CalculationWarning(
        code: 'REP-003-SUBJECTIVE-PROBABILITIES',
        message:
            'Scenario probabilities are user-supplied assumptions and are '
            'not inferred from historical or forecast data.',
        severity: WarningSeverity.caution,
      ),
      'REP-003-EXPECTED-VALUE-NOT-FORECAST': const CalculationWarning(
        code: 'REP-003-EXPECTED-VALUE-NOT-FORECAST',
        message:
            'Probability-weighted expected values are mathematical averages, '
            'not forecasts, guarantees, or likely realized outcomes.',
        severity: WarningSeverity.caution,
      ),
    };

    return CalculationResult<WeightedDecisionAnalysisResult>(
      value: result,
      warnings: warningsByCode.values,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'sourceFormulaId': report.metadata.formulaId,
          'sourceFormulaVersion': report.metadata.formulaVersion,
          'caseWeightsPercent': <String, Object?>{
            for (final weight in input.weights)
              weight.caseId: weight.probability.percent.toString(),
          },
          'currency': currency.code,
        },
        assumptions: <String, Object?>{
          'probabilitiesUserSupplied': true,
          'probabilitiesSumExactlyToOneHundredPercent': true,
          'casesMutuallyExclusive': true,
          'casesCollectivelyExhaustive': true,
          'financialValuesRecalculated': false,
          'aggregationMethod': 'probabilityWeightedArithmeticMean',
          'roundingTiming': 'afterWeightedSummation',
          'roundingPolicy': roundingPolicy.name,
          'financialAdvice': false,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'sourceReportFormulaId': DecisionAnalysisReportCalculator.formulaId,
          'expectedAfterTaxFutureValue': result
              .expectedAfterTaxFutureValue
              .amount
              .toString(),
          'expectedRealAfterTaxFutureValue': result
              .expectedRealAfterTaxFutureValue
              .amount
              .toString(),
          'expectedEstimatedTax': result.expectedEstimatedTax.amount.toString(),
          'expectedPrepaymentAllocationPercent': result
              .expectedPrepaymentAllocation
              .percent
              .toString(),
          'probabilitySelectionChangedByTaxPercent': result
              .probabilitySelectionChangedByTax
              .percent
              .toString(),
          'currencyDecimalPlaces': currency.decimalPlaces,
        },
      ),
    );
  }
}
