import 'dart:collection';

import 'package:meta/meta.dart';

import '../money/money.dart';
import 'amortization_schedule.dart';
import 'emi_payment_period.dart';

/// Comparison of a scheduled-EMI strategy with the original loan schedule.
@immutable
final class EmiChangeResult {
  factory EmiChangeResult({
    required AmortizationSchedule baseline,
    required AmortizationSchedule strategy,
    required List<EmiPaymentPeriod> periods,
  }) {
    if (baseline.financedPrincipal != strategy.financedPrincipal) {
      throw ArgumentError(
        'Baseline and strategy must use the same financed principal.',
      );
    }
    if (periods.isEmpty || periods.first.effectiveInstallment != 1) {
      throw ArgumentError('EMI periods must begin at installment one.');
    }
    final snapshot = List<EmiPaymentPeriod>.of(periods);
    for (var index = 0; index < snapshot.length; index++) {
      final period = snapshot[index];
      if (period.scheduledEmi.currency != strategy.financedPrincipal.currency) {
        throw ArgumentError('Every EMI period must use strategy currency.');
      }
      if (index > 0 &&
          period.effectiveInstallment <=
              snapshot[index - 1].effectiveInstallment) {
        throw ArgumentError(
          'EMI periods must have strictly increasing installments.',
        );
      }
    }
    return EmiChangeResult._(
      baseline: baseline,
      strategy: strategy,
      periods: UnmodifiableListView<EmiPaymentPeriod>(snapshot),
    );
  }

  const EmiChangeResult._({
    required this.baseline,
    required this.strategy,
    required this.periods,
  });

  final AmortizationSchedule baseline;
  final AmortizationSchedule strategy;
  final List<EmiPaymentPeriod> periods;

  int get emiChangeCount => periods.length - 1;

  int get installmentDifference =>
      strategy.paymentCount - baseline.paymentCount;

  Money get interestDifference =>
      strategy.totalInterest - baseline.totalInterest;

  Money get interestSaved => baseline.totalInterest - strategy.totalInterest;

  bool get closesEarlier => installmentDifference < 0;

  bool get extendsTenure => installmentDifference > 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EmiChangeResult &&
            baseline == other.baseline &&
            strategy == other.strategy &&
            _listsEqual(periods, other.periods);
  }

  @override
  int get hashCode => Object.hash(baseline, strategy, Object.hashAll(periods));

  static bool _listsEqual(
    List<EmiPaymentPeriod> first,
    List<EmiPaymentPeriod> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'EmiChangeResult('
        'emiChangeCount: $emiChangeCount, '
        'installmentDifference: $installmentDifference, '
        'interestDifference: $interestDifference, '
        'closesEarlier: $closesEarlier, extendsTenure: $extendsTenure'
        ')';
  }
}
