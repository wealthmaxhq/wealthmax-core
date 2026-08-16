import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_calculator.dart';
import 'effective_rate_result.dart';
import 'loan_input.dart';

/// Calculates the effective borrowing cost from monthly loan cash flows.
///
/// Formula `LN-007` solves the periodic internal rate of return where the
/// present value of actual rounded repayments equals net loan proceeds.
@immutable
final class EffectiveRateCalculator {
  const EffectiveRateCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  });

  static const String formulaId = 'LN-007';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<EffectiveRateResult> calculate(
    LoanInput input, {
    required DateTime calculatedAt,
  }) {
    if (calculationScale <= 0) {
      throw ArgumentError.value(
        calculationScale,
        'calculationScale',
        'Must be greater than zero.',
      );
    }
    if (maximumIterations <= 0) {
      throw ArgumentError.value(
        maximumIterations,
        'maximumIterations',
        'Must be greater than zero.',
      );
    }

    final financedPrincipal = input.financedPrincipal;
    if (!financedPrincipal.isPositive) {
      throw ArgumentError.value(
        input.prepayment,
        'prepayment',
        'Effective rate requires positive financed principal.',
      );
    }

    final processingFee =
        input.processingFee ?? Money.zero(financedPrincipal.currency);
    final netProceeds = financedPrincipal - processingFee;
    if (!netProceeds.isPositive) {
      throw ArgumentError.value(
        processingFee,
        'processingFee',
        'Processing fee must be less than financed principal.',
      );
    }

    final schedule = AmortizationCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
    ).calculate(input, calculatedAt: calculatedAt).value;
    final paymentAmounts = schedule.entries
        .map((entry) => entry.totalCashFlow.amount)
        .toList(growable: false);
    final monthlyRate = _solveMonthlyRate(netProceeds.amount, paymentAmounts);
    final nominalAnnualRate = monthlyRate * Decimal.fromInt(12);
    final effectiveAnnualRate =
        _powAtScale(Decimal.one + monthlyRate, 12) - Decimal.one;
    final result = EffectiveRateResult(
      netProceeds: netProceeds,
      totalRepayment: schedule.totalPayment,
      monthlyEffectiveRate: Percentage.fromFraction(monthlyRate.toString()),
      nominalAnnualPercentageRate: Percentage.fromFraction(
        nominalAnnualRate.toString(),
      ),
      effectiveAnnualRate: Percentage.fromFraction(
        effectiveAnnualRate.toString(),
      ),
      paymentCount: schedule.paymentCount,
    );

    return CalculationResult<EffectiveRateResult>(
      value: result,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'principal': input.principal.amount.toString(),
          'currency': input.principal.currency.code,
          'annualInterestRatePercent': input.annualInterestRate.percent
              .toString(),
          'tenureMonths': input.tenureMonths,
          'processingFee': processingFee.amount.toString(),
          'prepayment': input.prepayment?.amount.toString(),
        },
        assumptions: <String, Object?>{
          'cashFlowFrequency': 'monthly',
          'paymentTiming': 'endOfPeriod',
          'processingFeeTiming': 'deductedFromInitialProceeds',
          'rateSolver': 'boundedBisection',
          'nominalAprConvention': 'monthlyRateMultipliedBy12',
          'effectiveAnnualConvention': 'monthlyCompounding',
          'taxEffectsIncluded': false,
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'amortizationFormulaId': AmortizationCalculator.formulaId,
          'netProceeds': result.netProceeds.amount.toString(),
          'totalRepayment': result.totalRepayment.amount.toString(),
          'financeCharge': result.financeCharge.amount.toString(),
          'paymentCount': result.paymentCount,
          'monthlyEffectiveRatePercent': result.monthlyEffectiveRate.percent
              .toString(),
          'nominalAnnualPercentageRate': result
              .nominalAnnualPercentageRate
              .percent
              .toString(),
          'effectiveAnnualRatePercent': result.effectiveAnnualRate.percent
              .toString(),
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
        },
      ),
    );
  }

  Decimal _solveMonthlyRate(Decimal netProceeds, List<Decimal> payments) {
    final undiscounted = payments.fold<Decimal>(
      Decimal.zero,
      (total, payment) => total + payment,
    );
    if (undiscounted == netProceeds) return Decimal.zero;
    if (undiscounted < netProceeds) {
      throw StateError(
        'Repayment cash flows cannot produce a non-negative effective rate.',
      );
    }

    var lower = Decimal.zero;
    var upper = Decimal.one;
    var upperDifference = _presentValue(payments, upper) - netProceeds;
    var expansionCount = 0;
    while (upperDifference > Decimal.zero &&
        expansionCount < maximumIterations) {
      upper *= Decimal.fromInt(2);
      upperDifference = _presentValue(payments, upper) - netProceeds;
      expansionCount++;
    }
    if (upperDifference > Decimal.zero) {
      throw StateError('Unable to bracket the monthly effective rate.');
    }

    final tolerance = Decimal.one.shift(-calculationScale);
    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      final midpoint = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final difference = _presentValue(payments, midpoint) - netProceeds;
      if (difference.abs() <= tolerance || upper - lower <= tolerance) {
        return midpoint;
      }
      if (difference > Decimal.zero) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
    }

    return ((lower + upper) / Decimal.fromInt(2)).toDecimal(
      scaleOnInfinitePrecision: calculationScale,
    );
  }

  Decimal _presentValue(List<Decimal> payments, Decimal monthlyRate) {
    final growthFactor = Decimal.one + monthlyRate;
    var discountFactor = Decimal.one;
    var presentValue = Decimal.zero;

    for (final payment in payments) {
      discountFactor = _roundIntermediate(discountFactor * growthFactor);
      final discountedPayment = (payment / discountFactor).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      presentValue = _roundIntermediate(presentValue + discountedPayment);
    }
    return presentValue;
  }

  Decimal _powAtScale(Decimal base, int exponent) {
    var result = Decimal.one;
    var factor = base;
    var remainingExponent = exponent;

    while (remainingExponent > 0) {
      if (remainingExponent.isOdd) {
        result = _roundIntermediate(result * factor);
      }
      remainingExponent ~/= 2;
      if (remainingExponent > 0) {
        factor = _roundIntermediate(factor * factor);
      }
    }
    return result;
  }

  Decimal _roundIntermediate(Decimal value) {
    return RoundingPolicy.halfEven.round(
      value,
      decimalPlaces: calculationScale,
    );
  }
}
