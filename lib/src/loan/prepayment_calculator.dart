import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_calculator.dart';
import 'loan_input.dart';
import 'loan_prepayment_result.dart';
import 'scheduled_prepayment.dart';

/// Compares scheduled reduce-tenure prepayments with a no-prepayment baseline.
@immutable
final class PrepaymentCalculator {
  const PrepaymentCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
  }) : assert(calculationScale > 0);

  static const String formulaId = 'LN-003';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;

  CalculationResult<LoanPrepaymentResult> calculate(
    LoanInput input, {
    required PrepaymentPlan prepaymentPlan,
    required DateTime calculatedAt,
  }) {
    prepaymentPlan.validateFor(
      currency: input.principal.currency,
      tenureMonths: input.tenureMonths,
    );
    final calculator = AmortizationCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
    );
    final baseline = calculator
        .calculate(input, calculatedAt: calculatedAt)
        .value;
    final strategy = calculator
        .calculate(
          input,
          calculatedAt: calculatedAt,
          prepaymentPlan: prepaymentPlan,
        )
        .value;
    final requestedPrepayment = prepaymentPlan.total(input.principal.currency);
    final result = LoanPrepaymentResult(
      baseline: baseline,
      strategy: strategy,
      requestedPrepayment: requestedPrepayment,
    );

    return CalculationResult<LoanPrepaymentResult>(
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
          'scheduledPrepayments': prepaymentPlan.prepayments
              .map(
                (prepayment) => <String, Object?>{
                  'installmentNumber': prepayment.installmentNumber,
                  'amount': prepayment.amount.amount.toString(),
                },
              )
              .toList(growable: false),
        },
        assumptions: <String, Object?>{
          'prepaymentTiming': 'afterScheduledInstallment',
          'prepaymentEffect': 'reduceTenure',
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'amortizationFormulaId': AmortizationCalculator.formulaId,
          'baselinePaymentCount': baseline.paymentCount,
          'strategyPaymentCount': strategy.paymentCount,
          'installmentsReduced': result.installmentsReduced,
          'requestedPrepayment': requestedPrepayment.amount.toString(),
          'appliedPrepayment': result.appliedPrepayment.amount.toString(),
          'unappliedPrepayment': result.unappliedPrepayment.amount.toString(),
          'interestSaved': result.interestSaved.amount.toString(),
        },
      ),
    );
  }
}
