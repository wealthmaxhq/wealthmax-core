import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'expense_ratio_impact_input.dart';
import 'expense_ratio_impact_result.dart';

/// Projects the wealth impact of an annual asset-based expense ratio.
///
/// Formula `INV-009` applies the fee at each year end:
/// `netGrowth = (1 + grossReturn) * (1 - expenseRatio)`.
@immutable
final class ExpenseRatioImpactCalculator {
  const ExpenseRatioImpactCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
  });

  static const String formulaId = 'INV-009';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;

  CalculationResult<ExpenseRatioImpactResult> calculate(
    ExpenseRatioImpactInput input, {
    required DateTime calculatedAt,
  }) {
    final grossGrowthFactor = Decimal.one + input.grossAnnualReturn.fraction;
    final feeRetentionFactor = Decimal.one - input.annualExpenseRatio.fraction;
    final netGrowthFactor = grossGrowthFactor * feeRetentionFactor;
    final netAnnualReturn = Percentage.fromFraction(
      (netGrowthFactor - Decimal.one).toString(),
    );
    final rawGrossValue =
        input.initialInvestment.amount *
        _powExact(grossGrowthFactor, input.tenureYears);
    final rawNetValue =
        input.initialInvestment.amount *
        _powExact(netGrowthFactor, input.tenureYears);
    final currency = input.initialInvestment.currency;
    final grossFutureValue = Money(
      amount: roundingPolicy.round(
        rawGrossValue,
        decimalPlaces: currency.decimalPlaces,
      ),
      currency: currency,
    );
    final netFutureValue = Money(
      amount: roundingPolicy.round(
        rawNetValue,
        decimalPlaces: currency.decimalPlaces,
      ),
      currency: currency,
    );
    final result = ExpenseRatioImpactResult(
      initialInvestment: input.initialInvestment,
      grossFutureValue: grossFutureValue,
      netFutureValue: netFutureValue,
      grossAnnualReturn: input.grossAnnualReturn,
      annualExpenseRatio: input.annualExpenseRatio,
      netAnnualReturn: netAnnualReturn,
      tenureYears: input.tenureYears,
    );

    return CalculationResult<ExpenseRatioImpactResult>(
      value: result,
      warnings: _warnings(input, netAnnualReturn),
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'initialInvestment': input.initialInvestment.amount.toString(),
          'currency': currency.code,
          'grossAnnualReturnPercent': input.grossAnnualReturn.percent
              .toString(),
          'annualExpenseRatioPercent': input.annualExpenseRatio.percent
              .toString(),
          'tenureYears': input.tenureYears,
        },
        assumptions: <String, Object?>{
          'grossReturnConvention': 'effectiveAnnualReturn',
          'feeConvention': 'endOfYearAssetBasedFee',
          'feeTiming': 'afterAnnualGrossReturn',
          'constantGrossReturn': true,
          'constantExpenseRatio': true,
          'additionalContributions': false,
          'taxesIncluded': false,
          'inflationIncluded': false,
          'roundingTiming': 'finalValuesOnly',
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'grossGrowthFactor': grossGrowthFactor.toString(),
          'feeRetentionFactor': feeRetentionFactor.toString(),
          'netGrowthFactor': netGrowthFactor.toString(),
          'netAnnualReturnPercent': netAnnualReturn.percent.toString(),
          'grossFutureValue': grossFutureValue.amount.toString(),
          'netFutureValue': netFutureValue.amount.toString(),
          'wealthLostToFees': result.wealthLostToFees.amount.toString(),
          'currencyDecimalPlaces': currency.decimalPlaces,
        },
      ),
    );
  }

  List<CalculationWarning> _warnings(
    ExpenseRatioImpactInput input,
    Percentage netAnnualReturn,
  ) {
    final warnings = <CalculationWarning>[
      const CalculationWarning(
        code: 'INV-009-PROJECTION-NOT-GUARANTEED',
        message:
            'Fee impact is a projection based on constant return and expense '
            'ratio assumptions and is not guaranteed.',
        severity: WarningSeverity.info,
      ),
    ];
    if (input.annualExpenseRatio.percent >= Decimal.fromInt(2)) {
      warnings.add(
        const CalculationWarning(
          code: 'INV-009-HIGH-EXPENSE-RATIO',
          message:
              'An annual expense ratio of 2% or more can materially reduce '
              'long-term wealth.',
          severity: WarningSeverity.caution,
        ),
      );
    }
    if (netAnnualReturn.isNegative) {
      warnings.add(
        const CalculationWarning(
          code: 'INV-009-NEGATIVE-NET-RETURN',
          message:
              'The supplied assumptions produce a negative annual return '
              'after fees.',
          severity: WarningSeverity.caution,
        ),
      );
    }
    return warnings;
  }

  Decimal _powExact(Decimal base, int exponent) {
    var result = Decimal.one;
    var factor = base;
    var remainingExponent = exponent;

    while (remainingExponent > 0) {
      if (remainingExponent.isOdd) {
        result *= factor;
      }
      remainingExponent ~/= 2;
      if (remainingExponent > 0) {
        factor *= factor;
      }
    }
    return result;
  }
}
