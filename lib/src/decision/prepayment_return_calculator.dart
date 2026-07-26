import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../loan/amortization_schedule.dart';
import '../loan/prepayment_calculator.dart';
import '../loan/scheduled_prepayment.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'prepayment_return_input.dart';
import 'prepayment_return_result.dart';

/// Calculates the effective internal return from a one-time loan prepayment.
///
/// Formula `OPT-004` solves the monthly IRR of incremental cash flows:
/// baseline loan cash flow minus prepayment-strategy loan cash flow.
@immutable
final class PrepaymentReturnCalculator {
  const PrepaymentReturnCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  }) : assert(calculationScale > 0),
       assert(maximumIterations > 0);

  static const String formulaId = 'OPT-004';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<PrepaymentReturnResult> calculate(
    PrepaymentReturnInput input, {
    required DateTime calculatedAt,
  }) {
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
    final cashFlows = _incrementalCashFlows(
      prepayment.baseline,
      prepayment.strategy,
      decisionInstallment: input.decisionInstallment,
    );
    if (cashFlows.length < 2 ||
        !cashFlows.first.amount.isNegative ||
        !cashFlows.any((cashFlow) => cashFlow.amount.isPositive)) {
      throw ArgumentError(
        'Prepayment must create a negative decision cash flow and at least '
        'one later positive loan-payment saving.',
      );
    }

    final monthlyFraction = _solveMonthlyReturn(cashFlows);
    final annualFraction =
        _powExact(Decimal.one + monthlyFraction, 12) - Decimal.one;
    final result = PrepaymentReturnResult(
      loanPrepayment: prepayment,
      cashFlows: cashFlows,
      monthlyReturn: Percentage.fromFraction(monthlyFraction.toString()),
      effectiveAnnualReturn: Percentage.fromFraction(annualFraction.toString()),
    );

    return CalculationResult<PrepaymentReturnResult>(
      value: result,
      warnings: const <CalculationWarning>[
        CalculationWarning(
          code: 'OPT-004-EQUAL-MONTHS-ASSUMED',
          message:
              'Cash flows are modeled at equal monthly intervals rather than '
              'using actual calendar dates.',
          severity: WarningSeverity.info,
        ),
        CalculationWarning(
          code: 'OPT-004-TAX-PENALTY-EXCLUDED',
          message:
              'Tax benefits, lender prepayment penalties, liquidity, and '
              'alternative investment risk are excluded.',
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
        },
        assumptions: <String, Object?>{
          'cashFlowFrequency': 'monthly',
          'cashFlowSpacing': 'equalMonthlyPeriods',
          'cashFlowDefinition':
              'baselineLoanCashFlowMinusPrepaymentStrategyCashFlow',
          'annualization': 'effectiveMonthlyCompoundingFor12Months',
          'prepaymentEffect': 'reduceTenure',
          'taxBenefitsIncluded': false,
          'prepaymentPenaltiesIncluded': false,
          'roundingPolicy': roundingPolicy.name,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'loanPrepaymentFormulaId': PrepaymentCalculator.formulaId,
          'appliedPrepayment': prepayment.appliedPrepayment.amount.toString(),
          'unappliedPrepayment': prepayment.unappliedPrepayment.amount
              .toString(),
          'interestSaved': prepayment.interestSaved.amount.toString(),
          'cashFlowCount': cashFlows.length,
          'netCashFlowTotal': result.netCashFlowTotal.amount.toString(),
          'monthlyReturnPercent': result.monthlyReturn.percent.toString(),
          'effectiveAnnualReturnPercent': result.effectiveAnnualReturn.percent
              .toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
          'cashFlows': cashFlows
              .map(
                (cashFlow) => <String, Object?>{
                  'monthsFromDecision': cashFlow.monthsFromDecision,
                  'amount': cashFlow.amount.amount.toString(),
                },
              )
              .toList(growable: false),
        },
      ),
    );
  }

  List<PrepaymentReturnCashFlow> _incrementalCashFlows(
    AmortizationSchedule baseline,
    AmortizationSchedule strategy, {
    required int decisionInstallment,
  }) {
    final currency = baseline.financedPrincipal.currency;
    final cashFlows = <PrepaymentReturnCashFlow>[];
    for (
      var installment = decisionInstallment;
      installment <= baseline.paymentCount;
      installment++
    ) {
      final baselineCashFlow = baseline.entries[installment - 1].totalCashFlow;
      final strategyCashFlow = installment <= strategy.paymentCount
          ? strategy.entries[installment - 1].totalCashFlow
          : Money.zero(currency);
      final difference = baselineCashFlow - strategyCashFlow;
      if (!difference.isZero) {
        cashFlows.add(
          PrepaymentReturnCashFlow(
            monthsFromDecision: installment - decisionInstallment,
            amount: difference,
          ),
        );
      }
    }
    return cashFlows;
  }

  Decimal _solveMonthlyReturn(List<PrepaymentReturnCashFlow> cashFlows) {
    final zeroNpv = _npv(cashFlows, Decimal.zero);
    final moneyTolerance = Decimal.one.shift(-calculationScale);
    if (zeroNpv.abs() <= moneyTolerance) return Decimal.zero;

    var lower = Decimal.zero;
    var upper = Decimal.one;
    var upperNpv = _npv(cashFlows, upper);
    for (
      var expansion = 0;
      upperNpv > Decimal.zero && expansion < 64;
      expansion++
    ) {
      upper *= Decimal.fromInt(2);
      upperNpv = _npv(cashFlows, upper);
    }
    if (upperNpv > Decimal.zero) {
      throw StateError('Unable to bracket the monthly prepayment return.');
    }

    final rateTolerance = Decimal.one.shift(-calculationScale);
    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      final midpoint = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final midpointNpv = _npv(cashFlows, midpoint);
      if (midpointNpv.abs() <= moneyTolerance ||
          upper - lower <= rateTolerance) {
        return midpoint;
      }
      if (midpointNpv > Decimal.zero) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
    }
    return ((lower + upper) / Decimal.fromInt(2)).toDecimal(
      scaleOnInfinitePrecision: calculationScale,
    );
  }

  Decimal _npv(List<PrepaymentReturnCashFlow> cashFlows, Decimal monthlyRate) {
    final growthFactor = Decimal.one + monthlyRate;
    var result = Decimal.zero;
    for (final cashFlow in cashFlows) {
      final denominator = _powExact(growthFactor, cashFlow.monthsFromDecision);
      result += (cashFlow.amount.amount / denominator).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
    }
    return result;
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
