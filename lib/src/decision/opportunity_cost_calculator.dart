import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../loan/prepayment_calculator.dart';
import '../loan/scheduled_prepayment.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'opportunity_cost_input.dart';
import 'opportunity_cost_result.dart';

/// Compares a one-time reduce-tenure prepayment with investing the same amount.
///
/// Formula `OPT-001` compares total nominal loan interest saved with the
/// after-fee nominal investment gain at the baseline loan payoff date.
@immutable
final class OpportunityCostCalculator {
  const OpportunityCostCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'OPT-001';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<OpportunityCostResult> calculate(
    OpportunityCostInput input, {
    required DateTime calculatedAt,
  }) {
    final plan = PrepaymentPlan(<ScheduledPrepayment>[
      ScheduledPrepayment(
        installmentNumber: input.decisionInstallment,
        amount: input.extraCash,
      ),
    ]);
    final prepaymentCalculation = PrepaymentCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
    ).calculate(input.loan, prepaymentPlan: plan, calculatedAt: calculatedAt);
    final prepayment = prepaymentCalculation.value;
    if (input.decisionInstallment > prepayment.baseline.paymentCount) {
      throw ArgumentError.value(
        input.decisionInstallment,
        'decisionInstallment',
        'Decision installment occurs after the baseline loan closes.',
      );
    }

    final investedAmount = prepayment.appliedPrepayment;
    final horizonMonths =
        prepayment.baseline.paymentCount - input.decisionInstallment;
    final grossAnnualFactor =
        Decimal.one + input.grossAnnualInvestmentReturn.fraction;
    final feeRetentionFactor = Decimal.one - input.annualExpenseRatio.fraction;
    final netAnnualFactor = grossAnnualFactor * feeRetentionFactor;
    final netAnnualReturn = Percentage.fromFraction(
      (netAnnualFactor - Decimal.one).toString(),
    );
    final monthlyFactor = horizonMonths == 0
        ? Decimal.one
        : _monthlyFactor(netAnnualFactor);
    final cumulativeFactor = _powExact(monthlyFactor, horizonMonths);
    final rawFutureValue = investedAmount.amount * cumulativeFactor;
    final currency = input.loan.principal.currency;
    final investmentFutureValue = Money(
      amount: roundingPolicy.round(
        rawFutureValue,
        decimalPlaces: currency.decimalPlaces,
      ),
      currency: currency,
    );
    final result = OpportunityCostResult(
      loanPrepayment: prepayment,
      investedAmount: investedAmount,
      investmentFutureValue: investmentFutureValue,
      netAnnualInvestmentReturn: netAnnualReturn,
      investmentHorizonMonths: horizonMonths,
    );

    return CalculationResult<OpportunityCostResult>(
      value: result,
      warnings: _warnings(input, prepayment.unappliedPrepayment),
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'loanPrincipal': input.loan.principal.amount.toString(),
          'currency': currency.code,
          'loanAnnualInterestRatePercent': input.loan.annualInterestRate.percent
              .toString(),
          'loanTenureMonths': input.loan.tenureMonths,
          'extraCash': input.extraCash.amount.toString(),
          'decisionInstallment': input.decisionInstallment,
          'grossAnnualInvestmentReturnPercent': input
              .grossAnnualInvestmentReturn
              .percent
              .toString(),
          'annualExpenseRatioPercent': input.annualExpenseRatio.percent
              .toString(),
        },
        assumptions: <String, Object?>{
          'prepaymentTiming': 'afterSelectedInstallment',
          'prepaymentEffect': 'reduceTenure',
          'comparisonHorizon': 'baselineLoanPayoff',
          'investmentTiming': 'afterSelectedInstallment',
          'investmentRateConvention': 'effectiveAnnualReturn',
          'feeConvention': 'endOfYearAssetBasedFee',
          'monthlyFactorConversion': 'twelfthRootOfNetAnnualGrowthFactor',
          'investmentRiskAdjusted': false,
          'taxesIncluded': false,
          'inflationIncluded': false,
          'cashFlowTimingNormalized': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'loanPrepaymentFormulaId': PrepaymentCalculator.formulaId,
          'appliedPrepayment': investedAmount.amount.toString(),
          'unappliedPrepayment': prepayment.unappliedPrepayment.amount
              .toString(),
          'interestSaved': result.interestSaved.amount.toString(),
          'investmentHorizonMonths': horizonMonths,
          'netAnnualInvestmentReturnPercent': netAnnualReturn.percent
              .toString(),
          'monthlyNetGrowthFactor': monthlyFactor.toString(),
          'cumulativeInvestmentFactor': cumulativeFactor.toString(),
          'investmentFutureValue': investmentFutureValue.amount.toString(),
          'investmentGain': result.investmentGain.amount.toString(),
          'nominalAdvantage': result.nominalAdvantage.amount.toString(),
          'preferredOption': result.preferredOption.name,
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }

  List<CalculationWarning> _warnings(
    OpportunityCostInput input,
    Money unappliedPrepayment,
  ) {
    return <CalculationWarning>[
      const CalculationWarning(
        code: 'OPT-001-PROJECTION-NOT-GUARANTEED',
        message:
            'Investment returns are assumptions and are not guaranteed; the '
            'numerically favored option is not financial advice.',
        severity: WarningSeverity.info,
      ),
      const CalculationWarning(
        code: 'OPT-001-TIMING-NOT-NORMALIZED',
        message:
            'This first comparison contrasts total nominal interest saved '
            'with investment gain at loan maturity without discounting the '
            'timing of each saved loan cash flow.',
        severity: WarningSeverity.caution,
      ),
      const CalculationWarning(
        code: 'OPT-001-TAX-INFLATION-EXCLUDED',
        message:
            'Taxes, inflation, liquidity, and investment risk are excluded '
            'and can change the decision.',
        severity: WarningSeverity.caution,
      ),
      if (unappliedPrepayment.isPositive)
        CalculationWarning(
          code: 'OPT-001-PARTIAL-PREPAYMENT',
          message:
              'Only ${unappliedPrepayment.currency.code} '
              '${(input.extraCash - unappliedPrepayment).amount} of the '
              'available cash can be applied to the loan at this installment.',
          severity: WarningSeverity.info,
        ),
    ];
  }

  Decimal _monthlyFactor(Decimal annualGrowthFactor) {
    if (annualGrowthFactor == Decimal.zero) return Decimal.zero;
    if (annualGrowthFactor == Decimal.one) return Decimal.one;

    var lower = annualGrowthFactor < Decimal.one ? Decimal.zero : Decimal.one;
    var upper = annualGrowthFactor < Decimal.one
        ? Decimal.one
        : annualGrowthFactor;
    final tolerance = Decimal.one.shift(-calculationScale);

    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      final midpoint = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final difference = _powExact(midpoint, 12) - annualGrowthFactor;
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
