import 'dart:collection';

import 'package:meta/meta.dart';

import 'amortization_schedule.dart';
import 'variable_rate_period.dart';

/// A variable-rate schedule and all rate/EMI periods actually applied.
@immutable
final class VariableRateLoanResult {
  factory VariableRateLoanResult({
    required AmortizationSchedule schedule,
    required List<VariableRatePeriod> periods,
  }) {
    if (periods.isEmpty) {
      throw ArgumentError('At least one rate period is required.');
    }
    final snapshot = List<VariableRatePeriod>.of(periods);
    if (snapshot.first.effectiveInstallment != 1) {
      throw ArgumentError('The first rate period must start at installment 1.');
    }
    for (var index = 0; index < snapshot.length; index++) {
      final period = snapshot[index];
      if (period.scheduledEmi.currency != schedule.financedPrincipal.currency) {
        throw ArgumentError(
          'Every rate period must use the schedule currency.',
        );
      }
      if (index > 0 &&
          period.effectiveInstallment <=
              snapshot[index - 1].effectiveInstallment) {
        throw ArgumentError(
          'Rate periods must have strictly increasing installments.',
        );
      }
      if (period.effectiveInstallment > schedule.paymentCount &&
          schedule.paymentCount > 0) {
        throw ArgumentError(
          'Applied rate period must not start after loan closure.',
        );
      }
    }

    return VariableRateLoanResult._(
      schedule: schedule,
      periods: UnmodifiableListView<VariableRatePeriod>(snapshot),
    );
  }

  const VariableRateLoanResult._({
    required this.schedule,
    required this.periods,
  });

  final AmortizationSchedule schedule;
  final List<VariableRatePeriod> periods;

  int get emiChangeCount => periods.length - 1;

  VariableRatePeriod get initialPeriod => periods.first;

  VariableRatePeriod get finalPeriod => periods.last;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VariableRateLoanResult &&
            schedule == other.schedule &&
            _listsEqual(periods, other.periods);
  }

  @override
  int get hashCode => Object.hash(schedule, Object.hashAll(periods));

  static bool _listsEqual(
    List<VariableRatePeriod> first,
    List<VariableRatePeriod> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'VariableRateLoanResult('
        'periods: $periods, schedule: $schedule'
        ')';
  }
}
