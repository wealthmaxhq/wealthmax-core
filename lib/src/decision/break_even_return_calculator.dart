import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../loan/prepayment_calculator.dart';
import '../loan/scheduled_prepayment.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'break_even_return_input.dart';
import 'break_even_return_result.dart';
import 'calculator_configuration.dart';

/// Finds the gross annual investment return needed to match prepayment.
///
/// Formula `OPT-002` solves:
/// `invested * netAnnualFactor^(months/12) = invested + interestSaved`,
/// then reverses the annual expense-ratio deduction.
@immutable
final class BreakEvenReturnCalculator {
  const BreakEvenReturnCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  });

  static const String formulaId = 'OPT-002';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<BreakEvenReturnResult> calculate(
    BreakEvenReturnInput input, {
    required DateTime calculatedAt,
  }) {
    validateDecisionCalculatorConfiguration(
      calculationScale: calculationScale,
      maximumIterations: maximumIterations,
    );
    final prepayment =
        PrepaymentCalculator(
              roundingPolicy: roundingPolicy,
              calculationScale: calculationScale,
            )
            .calculate(
              input.loan,
              prepaymentPlan: PrepaymentPlan(<ScheduledPrepayment>[
                ScheduledPrepayment(
                  installmentNumber: input.decisionInstallment,
                  amount: input.extraCash,
                ),
              ]),
              calculatedAt: calculatedAt,
            )
            .value;
    final investedAmount = prepayment.appliedPrepayment;
    final horizonMonths =
        prepayment.baseline.paymentCount - input.decisionInstallment;
    if (!investedAmount.isPositive || horizonMonths <= 0) {
      throw ArgumentError(
        'Break-even analysis requires a positive applied prepayment and at '
        'least one remaining month before baseline loan payoff.',
      );
    }

    final requiredFutureValue = investedAmount + prepayment.interestSaved;
    final targetCumulativeFactor =
        (requiredFutureValue.amount / investedAmount.amount).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        );
    final requiredMonthlyFactor = _nthRoot(
      targetCumulativeFactor,
      horizonMonths,
    );
    final requiredNetAnnualFactor = _powExact(requiredMonthlyFactor, 12);
    final feeRetentionFactor = Decimal.one - input.annualExpenseRatio.fraction;
    final requiredGrossAnnualFactor =
        (requiredNetAnnualFactor / feeRetentionFactor).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        );
    final breakEvenNetAnnualReturn = Percentage.fromFraction(
      (requiredNetAnnualFactor - Decimal.one).toString(),
    );
    final breakEvenGrossAnnualReturn = Percentage.fromFraction(
      (requiredGrossAnnualFactor - Decimal.one).toString(),
    );
    final result = BreakEvenReturnResult(
      loanPrepayment: prepayment,
      investedAmount: investedAmount,
      requiredFutureValue: requiredFutureValue,
      annualExpenseRatio: input.annualExpenseRatio,
      breakEvenNetAnnualReturn: breakEvenNetAnnualReturn,
      breakEvenGrossAnnualReturn: breakEvenGrossAnnualReturn,
      investmentHorizonMonths: horizonMonths,
    );

    return CalculationResult<BreakEvenReturnResult>(
      value: result,
      warnings: <CalculationWarning>[
        const CalculationWarning(
          code: 'OPT-002-THRESHOLD-NOT-FORECAST',
          message:
              'The break-even return is a mathematical threshold, not a '
              'forecast or guarantee of investment performance.',
          severity: WarningSeverity.info,
        ),
        const CalculationWarning(
          code: 'OPT-002-TIMING-NOT-NORMALIZED',
          message:
              'The threshold matches total nominal interest saved without '
              'discounting the timing of each saved loan cash flow.',
          severity: WarningSeverity.caution,
        ),
        const CalculationWarning(
          code: 'OPT-002-TAX-INFLATION-RISK-EXCLUDED',
          message:
              'Taxes, inflation, liquidity, and investment risk are excluded.',
          severity: WarningSeverity.caution,
        ),
        if (input.annualExpenseRatio.percent >= Decimal.fromInt(2))
          const CalculationWarning(
            code: 'OPT-002-HIGH-EXPENSE-RATIO',
            message:
                'An expense ratio of 2% or more materially raises the gross '
                'return required to break even.',
            severity: WarningSeverity.caution,
          ),
        if (prepayment.unappliedPrepayment.isPositive)
          CalculationWarning(
            code: 'OPT-002-PARTIAL-PREPAYMENT',
            message:
                'The threshold uses only the prepayment amount actually '
                'accepted by the loan.',
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
        },
        assumptions: <String, Object?>{
          'comparisonTarget': 'investmentGainEqualsInterestSaved',
          'comparisonHorizon': 'baselineLoanPayoff',
          'prepaymentTiming': 'afterSelectedInstallment',
          'prepaymentEffect': 'reduceTenure',
          'feeConvention': 'endOfYearAssetBasedFee',
          'taxesIncluded': false,
          'inflationIncluded': false,
          'investmentRiskAdjusted': false,
          'cashFlowTimingNormalized': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'loanPrepaymentFormulaId': PrepaymentCalculator.formulaId,
          'appliedPrepayment': investedAmount.amount.toString(),
          'unappliedPrepayment': prepayment.unappliedPrepayment.amount
              .toString(),
          'interestSaved': prepayment.interestSaved.amount.toString(),
          'requiredFutureValue': requiredFutureValue.amount.toString(),
          'investmentHorizonMonths': horizonMonths,
          'targetCumulativeFactor': targetCumulativeFactor.toString(),
          'requiredMonthlyFactor': requiredMonthlyFactor.toString(),
          'requiredNetAnnualFactor': requiredNetAnnualFactor.toString(),
          'feeRetentionFactor': feeRetentionFactor.toString(),
          'breakEvenNetAnnualReturnPercent': breakEvenNetAnnualReturn.percent
              .toString(),
          'breakEvenGrossAnnualReturnPercent': breakEvenGrossAnnualReturn
              .percent
              .toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }

  Decimal _nthRoot(Decimal value, int degree) {
    if (value == Decimal.one || degree == 1) return value;
    var lower = Decimal.one;
    var upper = value;
    final tolerance = Decimal.one.shift(-calculationScale);

    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      final midpoint = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final difference = _powExact(midpoint, degree) - value;
      if (difference.abs() <= tolerance || upper - lower <= tolerance) {
        return midpoint;
      }
      if (difference < Decimal.zero) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
    }
    return ((lower + upper) / Decimal.fromInt(2)).toDecimal(
      scaleOnInfinitePrecision: calculationScale,
    );
  }

  Decimal _powExact(Decimal base, int exponent) {
    var result = Decimal.one;
    var factor = base;
    var remainingExponent = exponent;

    while (remainingExponent > 0) {
      if (remainingExponent.isOdd) result *= factor;
      remainingExponent ~/= 2;
      if (remainingExponent > 0) factor *= factor;
    }
    return result;
  }
}
