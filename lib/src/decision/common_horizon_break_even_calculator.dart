import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'break_even_return_input.dart';
import 'common_horizon_break_even_result.dart';
import 'common_horizon_strategy_calculator.dart';
import 'common_horizon_strategy_result.dart';
import 'hybrid_strategy_input.dart';

/// Solves the common-horizon return where all-invest equals all-prepay.
///
/// Formula `OPT-008` uses bisection over OPT-007 future values and reconciles
/// the endpoint strategies within one currency minor unit.
@immutable
final class CommonHorizonBreakEvenCalculator {
  const CommonHorizonBreakEvenCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'OPT-008';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<CommonHorizonBreakEvenResult> calculate(
    BreakEvenReturnInput input, {
    required DateTime calculatedAt,
  }) {
    final zeroEvaluation = _evaluate(
      input,
      Decimal.zero,
      calculatedAt: calculatedAt,
    );
    if (!zeroEvaluation
            .comparison
            .allPrepayScenario
            .allocation
            .appliedPrepayment
            .isPositive ||
        zeroEvaluation.comparison.commonHorizonInstallment <=
            input.decisionInstallment) {
      throw ArgumentError(
        'Normalized break-even analysis requires a positive applied '
        'prepayment and at least one remaining month before payoff.',
      );
    }

    final currency = input.loan.principal.currency;
    final moneyTolerance = Decimal.one.shift(-currency.decimalPlaces);
    var lower = _evaluate(input, -Decimal.one, calculatedAt: calculatedAt);
    if (lower.difference.amount > moneyTolerance) {
      throw StateError(
        'All-invest already exceeds all-prepay at a -100% gross return.',
      );
    }

    var upperGrossFraction = Decimal.one;
    var upper = _evaluate(
      input,
      upperGrossFraction,
      calculatedAt: calculatedAt,
    );
    for (
      var expansion = 0;
      upper.difference.amount < -moneyTolerance && expansion < 64;
      expansion++
    ) {
      upperGrossFraction =
          (upperGrossFraction + Decimal.one) * Decimal.fromInt(2) - Decimal.one;
      upper = _evaluate(input, upperGrossFraction, calculatedAt: calculatedAt);
    }
    if (upper.difference.amount < -moneyTolerance) {
      throw StateError('Unable to bracket the normalized break-even return.');
    }

    var best = _closer(lower, upper);
    final rateTolerance = Decimal.one.shift(-calculationScale);
    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      final midpointFraction =
          ((lower.grossFraction + upper.grossFraction) / Decimal.fromInt(2))
              .toDecimal(scaleOnInfinitePrecision: calculationScale);
      final midpoint = _evaluate(
        input,
        midpointFraction,
        calculatedAt: calculatedAt,
      );
      best = _closer(best, midpoint);
      if (midpoint.difference.amount.abs() <= moneyTolerance) {
        best = midpoint;
        break;
      }
      if (upper.grossFraction - lower.grossFraction <= rateTolerance) {
        break;
      }
      if (midpoint.difference.isNegative) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
    }
    if (best.difference.amount.abs() > moneyTolerance) {
      throw StateError(
        'The normalized break-even return did not reconcile within one '
        'currency minor unit.',
      );
    }

    final feeRetentionFactor = Decimal.one - input.annualExpenseRatio.fraction;
    final netAnnualFraction =
        (Decimal.one + best.grossFraction) * feeRetentionFactor - Decimal.one;
    final result = CommonHorizonBreakEvenResult(
      comparison: best.comparison,
      annualExpenseRatio: input.annualExpenseRatio,
      breakEvenNetAnnualReturn: Percentage.fromFraction(
        netAnnualFraction.toString(),
      ),
      breakEvenGrossAnnualReturn: Percentage.fromFraction(
        best.grossFraction.toString(),
      ),
    );

    return CalculationResult<CommonHorizonBreakEvenResult>(
      value: result,
      warnings: <CalculationWarning>[
        const CalculationWarning(
          code: 'OPT-008-THRESHOLD-NOT-FORECAST',
          message:
              'The normalized break-even return is a mathematical threshold, '
              'not a forecast or guarantee of investment performance.',
          severity: WarningSeverity.info,
        ),
        const CalculationWarning(
          code: 'OPT-008-REINVESTMENT-DISCIPLINE-ASSUMED',
          message:
              'Every loan-payment saving from prepayment is assumed to be '
              'reinvested when it occurs until the common horizon.',
          severity: WarningSeverity.caution,
        ),
        const CalculationWarning(
          code: 'OPT-008-TAX-INFLATION-RISK-EXCLUDED',
          message:
              'Taxes, inflation, liquidity needs, and investment risk are '
              'excluded and can change the practical threshold.',
          severity: WarningSeverity.caution,
        ),
        if (input.annualExpenseRatio.percent >= Decimal.fromInt(2))
          const CalculationWarning(
            code: 'OPT-008-HIGH-EXPENSE-RATIO',
            message:
                'An expense ratio of 2% or more materially raises the gross '
                'return required to break even.',
            severity: WarningSeverity.caution,
          ),
        if (result.allPrepay.allocation.redirectedToInvestment.isPositive)
          const CalculationWarning(
            code: 'OPT-008-PREPAYMENT-CAPPED',
            message:
                'The loan accepted only part of the requested prepayment; '
                'excess cash is invested in both endpoint comparison logic.',
            severity: WarningSeverity.info,
          ),
      ],
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
          'annualExpenseRatioPercent': input.annualExpenseRatio.percent
              .toString(),
        },
        assumptions: <String, Object?>{
          'equation':
              'allInvestFutureValueEqualsAllPrepayFutureValueAtCommonHorizon',
          'comparisonHorizon': 'baselineLoanPayoffInstallment',
          'cashFlowTimingNormalized': true,
          'savedPaymentTreatment': 'fullyReinvestedToCommonHorizon',
          'solver': 'bisection',
          'lowerGrossReturnBoundPercent': '-100',
          'upperBoundExpansion': 'doublingAnnualGrowthFactor',
          'reconciliationTolerance': 'oneCurrencyMinorUnit',
          'feeConvention': 'endOfYearAssetBasedFee',
          'taxesIncluded': false,
          'inflationIncluded': false,
          'riskAdjusted': false,
          'financialAdvice': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'commonHorizonStrategyFormulaId':
              CommonHorizonStrategyCalculator.formulaId,
          'commonHorizonInstallment':
              result.comparison.commonHorizonInstallment,
          'appliedPrepayment': result
              .allPrepay
              .allocation
              .appliedPrepayment
              .amount
              .toString(),
          'redirectedToInvestment': result
              .allPrepay
              .allocation
              .redirectedToInvestment
              .amount
              .toString(),
          'allInvestFutureValue': result.allInvest.totalFutureValue.amount
              .toString(),
          'allPrepayFutureValue': result.allPrepay.totalFutureValue.amount
              .toString(),
          'futureValueDifference': result.futureValueDifference.amount
              .toString(),
          'absoluteFutureValueDifference': result
              .absoluteFutureValueDifference
              .amount
              .toString(),
          'moneyTolerance': moneyTolerance.toString(),
          'breakEvenNetAnnualReturnPercent': result
              .breakEvenNetAnnualReturn
              .percent
              .toString(),
          'breakEvenGrossAnnualReturnPercent': result
              .breakEvenGrossAnnualReturn
              .percent
              .toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }

  _BreakEvenEvaluation _evaluate(
    BreakEvenReturnInput input,
    Decimal grossFraction, {
    required DateTime calculatedAt,
  }) {
    final calculation =
        CommonHorizonStrategyCalculator(
          roundingPolicy: roundingPolicy,
          calculationScale: calculationScale,
          maximumIterations: maximumIterations,
        ).calculate(
          HybridStrategyInput(
            loan: input.loan,
            extraCash: input.extraCash,
            decisionInstallment: input.decisionInstallment,
            grossAnnualInvestmentReturn: Percentage.fromFraction(
              grossFraction.toString(),
            ),
            annualExpenseRatio: input.annualExpenseRatio,
            allocationStepPercent: 100,
          ),
          calculatedAt: calculatedAt,
        );
    return _BreakEvenEvaluation(
      grossFraction: grossFraction,
      comparison: calculation.value,
    );
  }

  _BreakEvenEvaluation _closer(
    _BreakEvenEvaluation first,
    _BreakEvenEvaluation second,
  ) {
    return first.difference.amount.abs() <= second.difference.amount.abs()
        ? first
        : second;
  }
}

final class _BreakEvenEvaluation {
  const _BreakEvenEvaluation({
    required this.grossFraction,
    required this.comparison,
  });

  final Decimal grossFraction;
  final CommonHorizonStrategyResult comparison;

  Money get difference =>
      comparison.allInvestScenario.totalFutureValue -
      comparison.allPrepayScenario.totalFutureValue;
}
