import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_calculator.dart';
import 'loan_input.dart';
import 'refinance_input.dart';
import 'refinance_result.dart';

/// Compares nominal remaining loan cash flows with a replacement loan.
@immutable
final class RefinanceCalculator {
  const RefinanceCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
  }) : assert(calculationScale > 0);

  static const String formulaId = 'LN-006';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;

  CalculationResult<RefinanceResult> calculate(
    RefinanceInput input, {
    required DateTime calculatedAt,
  }) {
    final calculator = AmortizationCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
    );
    final currentLoan = calculator
        .calculate(
          LoanInput(
            principal: input.outstandingPrincipal,
            annualInterestRate: input.currentAnnualInterestRate,
            tenureMonths: input.remainingMonths,
          ),
          calculatedAt: calculatedAt,
        )
        .value;
    final refinancedLoan = calculator
        .calculate(
          LoanInput(
            principal: input.outstandingPrincipal,
            annualInterestRate: input.newAnnualInterestRate,
            tenureMonths: input.newTenureMonths,
          ),
          calculatedAt: calculatedAt,
        )
        .value;
    final result = RefinanceResult(
      currentLoan: currentLoan,
      refinancedLoan: refinancedLoan,
      refinancingFees: input.refinancingFees,
    );

    return CalculationResult<RefinanceResult>(
      value: result,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'outstandingPrincipal': input.outstandingPrincipal.amount.toString(),
          'currency': input.outstandingPrincipal.currency.code,
          'currentAnnualInterestRatePercent': input
              .currentAnnualInterestRate
              .percent
              .toString(),
          'remainingMonths': input.remainingMonths,
          'newAnnualInterestRatePercent': input.newAnnualInterestRate.percent
              .toString(),
          'newTenureMonths': input.newTenureMonths,
          'refinancingFees': input.refinancingFees.amount.toString(),
        },
        assumptions: <String, Object?>{
          'comparisonBasis': 'nominalCashFlows',
          'feePaymentTiming': 'upfront',
          'taxEffectsIncluded': false,
          'timeValueDiscountingIncluded': false,
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'amortizationFormulaId': AmortizationCalculator.formulaId,
          'currentEmi': result.currentEmi.amount.toString(),
          'newEmi': result.newEmi.amount.toString(),
          'monthlyCashFlowSavings': result.monthlyCashFlowSavings.amount
              .toString(),
          'currentRemainingCost': result.currentRemainingCost.amount.toString(),
          'refinancedTotalCost': result.refinancedTotalCost.amount.toString(),
          'totalCostSavings': result.totalCostSavings.amount.toString(),
          'grossInterestSavings': result.grossInterestSavings.amount.toString(),
          'tenureDifference': result.tenureDifference,
          'feeRecoveryInstallments': result.feeRecoveryInstallments,
          'isNominallyBeneficial': result.isNominallyBeneficial,
        },
      ),
    );
  }
}
