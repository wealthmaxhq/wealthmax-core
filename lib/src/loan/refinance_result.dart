import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import 'amortization_schedule.dart';

/// Nominal cash-flow comparison between continuing and refinancing a loan.
@immutable
final class RefinanceResult {
  factory RefinanceResult({
    required AmortizationSchedule currentLoan,
    required AmortizationSchedule refinancedLoan,
    required Money refinancingFees,
  }) {
    final currency = currentLoan.financedPrincipal.currency;
    if (refinancedLoan.financedPrincipal.currency != currency ||
        refinancingFees.currency != currency) {
      throw ArgumentError('All refinance result currencies must match.');
    }
    if (currentLoan.financedPrincipal != refinancedLoan.financedPrincipal) {
      throw ArgumentError(
        'Current and refinanced loans must use the same principal.',
      );
    }
    if (refinancingFees.isNegative) {
      throw ArgumentError.value(
        refinancingFees,
        'refinancingFees',
        'Refinancing fees must not be negative.',
      );
    }

    return RefinanceResult._(
      currentLoan: currentLoan,
      refinancedLoan: refinancedLoan,
      refinancingFees: refinancingFees,
    );
  }

  const RefinanceResult._({
    required this.currentLoan,
    required this.refinancedLoan,
    required this.refinancingFees,
  });

  final AmortizationSchedule currentLoan;
  final AmortizationSchedule refinancedLoan;
  final Money refinancingFees;

  Money get currentEmi => currentLoan.scheduledEmi;

  Money get newEmi => refinancedLoan.scheduledEmi;

  Money get monthlyCashFlowSavings => currentEmi - newEmi;

  Money get currentRemainingCost => currentLoan.totalPayment;

  Money get refinancedLoanPayments => refinancedLoan.totalPayment;

  Money get refinancedTotalCost => refinancedLoanPayments + refinancingFees;

  Money get totalCostSavings => currentRemainingCost - refinancedTotalCost;

  Money get grossInterestSavings =>
      currentLoan.totalInterest - refinancedLoan.totalInterest;

  int get tenureDifference =>
      refinancedLoan.paymentCount - currentLoan.paymentCount;

  bool get isNominallyBeneficial => totalCostSavings.isPositive;

  /// Months of EMI savings required to recover fees during overlapping terms.
  ///
  /// Returns `null` when the new EMI is not lower or fees cannot be recovered
  /// before either compared payment stream ends.
  int? get feeRecoveryInstallments {
    if (!monthlyCashFlowSavings.isPositive) return null;
    if (refinancingFees.isZero) return 0;

    final rawMonths = (refinancingFees.amount / monthlyCashFlowSavings.amount)
        .toDecimal(scaleOnInfinitePrecision: 16);
    final months = rawMonths.ceil().toBigInt().toInt();
    final overlappingPayments =
        currentLoan.paymentCount < refinancedLoan.paymentCount
        ? currentLoan.paymentCount
        : refinancedLoan.paymentCount;
    return months <= overlappingPayments ? months : null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RefinanceResult &&
            currentLoan == other.currentLoan &&
            refinancedLoan == other.refinancedLoan &&
            refinancingFees == other.refinancingFees;
  }

  @override
  int get hashCode => Object.hash(currentLoan, refinancedLoan, refinancingFees);

  @override
  String toString() {
    return 'RefinanceResult('
        'currentEmi: $currentEmi, newEmi: $newEmi, '
        'refinancingFees: $refinancingFees, '
        'totalCostSavings: $totalCostSavings, '
        'tenureDifference: $tenureDifference, '
        'feeRecoveryInstallments: $feeRecoveryInstallments, '
        'isNominallyBeneficial: $isNominallyBeneficial'
        ')';
  }
}
