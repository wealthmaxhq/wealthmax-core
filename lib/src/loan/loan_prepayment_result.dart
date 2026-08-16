import 'package:meta/meta.dart';

import '../money/money.dart';
import 'amortization_schedule.dart';

/// Comparison between a baseline loan and a reduce-tenure prepayment plan.
@immutable
final class LoanPrepaymentResult {
  factory LoanPrepaymentResult({
    required AmortizationSchedule baseline,
    required AmortizationSchedule strategy,
    required Money requestedPrepayment,
  }) {
    final currency = baseline.financedPrincipal.currency;
    if (strategy.financedPrincipal.currency != currency ||
        requestedPrepayment.currency != currency) {
      throw ArgumentError('All prepayment result currencies must match.');
    }
    if (baseline.financedPrincipal != strategy.financedPrincipal) {
      throw ArgumentError(
        'Baseline and strategy must use the same financed principal.',
      );
    }
    if (requestedPrepayment.isNegative) {
      throw ArgumentError.value(
        requestedPrepayment,
        'requestedPrepayment',
        'Requested prepayment must not be negative.',
      );
    }
    if (strategy.totalInterest.compareTo(baseline.totalInterest) > 0) {
      throw ArgumentError(
        'Prepayment strategy interest must not exceed baseline interest.',
      );
    }
    if (strategy.paymentCount > baseline.paymentCount) {
      throw ArgumentError(
        'Reduce-tenure strategy must not extend the baseline tenure.',
      );
    }

    return LoanPrepaymentResult._(
      baseline: baseline,
      strategy: strategy,
      requestedPrepayment: requestedPrepayment,
    );
  }

  const LoanPrepaymentResult._({
    required this.baseline,
    required this.strategy,
    required this.requestedPrepayment,
  });

  final AmortizationSchedule baseline;
  final AmortizationSchedule strategy;
  final Money requestedPrepayment;

  Money get appliedPrepayment => strategy.totalPrepayment;

  Money get unappliedPrepayment => requestedPrepayment - appliedPrepayment;

  Money get interestSaved => baseline.totalInterest - strategy.totalInterest;

  int get installmentsReduced => baseline.paymentCount - strategy.paymentCount;

  bool get closesEarly => installmentsReduced > 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LoanPrepaymentResult &&
            baseline == other.baseline &&
            strategy == other.strategy &&
            requestedPrepayment == other.requestedPrepayment;
  }

  @override
  int get hashCode => Object.hash(baseline, strategy, requestedPrepayment);

  @override
  String toString() {
    return 'LoanPrepaymentResult('
        'requestedPrepayment: $requestedPrepayment, '
        'appliedPrepayment: $appliedPrepayment, '
        'interestSaved: $interestSaved, '
        'installmentsReduced: $installmentsReduced, '
        'closesEarly: $closesEarly'
        ')';
  }
}
