import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../rounding/rounding_policy.dart';
import 'loan_input.dart';
import 'loan_result.dart';

/// Calculates fixed monthly installments for a reducing-balance loan.
///
/// Formula `LN-001`:
///
/// `EMI = P × r × (1 + r)^n / ((1 + r)^n - 1)`
///
/// where `P` is financed principal, `r` is the nominal annual rate divided
/// by 12, and `n` is the number of monthly installments.
@immutable
final class EmiCalculator {
  const EmiCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
  }) : assert(calculationScale > 0);

  static const String formulaId = 'LN-001';
  static const String formulaVersion = '1.0.0';

  /// Rounding applied to currency outputs.
  final RoundingPolicy roundingPolicy;

  /// Intermediate decimal precision used for non-terminating division.
  final int calculationScale;

  /// Calculates the loan summary using [input].
  ///
  /// [calculatedAt] is required so callers control the audit timestamp and
  /// identical inputs can remain reproducible.
  CalculationResult<LoanResult> calculate(
    LoanInput input, {
    required DateTime calculatedAt,
  }) {
    final financedPrincipal = input.financedPrincipal;
    final decimalPlaces = financedPrincipal.currency.decimalPlaces;
    final rawEmi = _calculateRawEmi(input);
    final roundedEmi = roundingPolicy.round(
      rawEmi,
      decimalPlaces: decimalPlaces,
    );
    final emi = Money(amount: roundedEmi, currency: financedPrincipal.currency);
    final isZeroInterest = input.annualInterestRate.isZero;
    final totalPayment = isZeroInterest
        ? financedPrincipal
        : emi.multiply(Decimal.fromInt(input.tenureMonths));
    final totalInterest = isZeroInterest
        ? Money.zero(financedPrincipal.currency)
        : totalPayment - financedPrincipal;
    final result = LoanResult(
      emi: emi,
      totalInterest: totalInterest,
      totalPayment: totalPayment,
    );

    return CalculationResult<LoanResult>(
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
          'processingFee': input.processingFee?.amount.toString(),
          'prepayment': input.prepayment?.amount.toString(),
        },
        assumptions: <String, Object?>{
          'repaymentFrequency': 'monthly',
          'interestMethod': 'reducingBalance',
          'rateConvention': 'nominalAnnualRateDividedBy12',
          'paymentTiming': 'endOfPeriod',
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'financedPrincipal': financedPrincipal.amount.toString(),
          'calculationScale': calculationScale,
          'currencyDecimalPlaces': decimalPlaces,
        },
      ),
    );
  }

  Decimal _calculateRawEmi(LoanInput input) {
    final principal = input.financedPrincipal.amount;
    if (principal == Decimal.zero) return Decimal.zero;

    final periods = Decimal.fromInt(input.tenureMonths);
    if (input.annualInterestRate.isZero) {
      return (principal / periods).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
    }

    final monthlyRate =
        (input.annualInterestRate.fraction / Decimal.fromInt(12)).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        );
    final growthFactor = Decimal.one + monthlyRate;
    final compounded = _powAtScale(growthFactor, input.tenureMonths);
    final numerator = principal * monthlyRate * compounded;
    final denominator = compounded - Decimal.one;

    return (numerator / denominator).toDecimal(
      scaleOnInfinitePrecision: calculationScale,
    );
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
