import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_schedule.dart';
import 'fixed_loan_schedule_kernel.dart';
import 'loan_input.dart';
import 'scheduled_prepayment.dart';

/// Builds a month-by-month reducing-balance amortization schedule.
@immutable
final class AmortizationCalculator {
  const AmortizationCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
  });

  static const String formulaId = 'LN-002';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;

  CalculationResult<AmortizationSchedule> calculate(
    LoanInput input, {
    required DateTime calculatedAt,
    PrepaymentPlan? prepaymentPlan,
  }) {
    if (calculationScale <= 0) {
      throw ArgumentError.value(
        calculationScale,
        'calculationScale',
        'Must be greater than zero.',
      );
    }

    final plan = prepaymentPlan ?? PrepaymentPlan.empty();
    plan.validateFor(
      currency: input.principal.currency,
      tenureMonths: input.tenureMonths,
    );
    final kernel = FixedLoanScheduleKernel(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
    );
    final scheduledEmi = kernel.calculateScheduledEmi(input);
    final financedPrincipal = input.financedPrincipal;

    final schedule = AmortizationSchedule(
      scheduledEmi: scheduledEmi,
      financedPrincipal: financedPrincipal,
      entries: kernel.buildEntries(
        input,
        scheduledEmi: scheduledEmi,
        prepaymentPlan: plan,
      ),
    );

    return CalculationResult<AmortizationSchedule>(
      value: schedule,
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
          'componentRounding': 'eachInstallment',
          'finalPaymentAdjustment': true,
          'prepaymentTiming': 'afterScheduledInstallment',
          'prepaymentEffect': 'reduceTenure',
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'emiFormulaId': FixedLoanScheduleKernel.emiFormulaId,
          'scheduledEmi': schedule.scheduledEmi.amount.toString(),
          'paymentCount': schedule.paymentCount,
          'totalPrincipal': schedule.totalPrincipal.amount.toString(),
          'totalPrepayment': schedule.totalPrepayment.amount.toString(),
          'totalInterest': schedule.totalInterest.amount.toString(),
          'totalPayment': schedule.totalPayment.amount.toString(),
          'calculationScale': calculationScale,
        },
      ),
    );
  }
}
