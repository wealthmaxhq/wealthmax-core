import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_schedule.dart';
import 'fixed_loan_schedule_kernel.dart';
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
  });

  static const String formulaId = FixedLoanScheduleKernel.emiFormulaId;
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
    if (calculationScale <= 0) {
      throw ArgumentError.value(
        calculationScale,
        'calculationScale',
        'Must be greater than zero.',
      );
    }

    final financedPrincipal = input.financedPrincipal;
    final decimalPlaces = financedPrincipal.currency.decimalPlaces;
    final kernel = FixedLoanScheduleKernel(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
    );
    final emi = kernel.calculateScheduledEmi(input);
    final schedule = AmortizationSchedule(
      scheduledEmi: emi,
      financedPrincipal: financedPrincipal,
      entries: kernel.buildEntries(input, scheduledEmi: emi),
    );
    final result = LoanResult(
      emi: emi,
      totalInterest: schedule.totalInterest,
      totalPayment: schedule.totalPayment,
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
          'paymentCount': schedule.paymentCount,
          'finalPaymentAdjustment': true,
        },
      ),
    );
  }
}
