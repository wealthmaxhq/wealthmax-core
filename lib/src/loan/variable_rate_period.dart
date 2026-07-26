import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// An applied floating-rate period and its recalculated scheduled EMI.
@immutable
final class VariableRatePeriod {
  factory VariableRatePeriod({
    required int effectiveInstallment,
    required Percentage annualInterestRate,
    required Money scheduledEmi,
  }) {
    if (effectiveInstallment <= 0) {
      throw ArgumentError.value(
        effectiveInstallment,
        'effectiveInstallment',
        'Effective installment must be greater than zero.',
      );
    }
    if (annualInterestRate.isNegative) {
      throw ArgumentError.value(
        annualInterestRate,
        'annualInterestRate',
        'Annual interest rate must not be negative.',
      );
    }
    if (scheduledEmi.isNegative) {
      throw ArgumentError.value(
        scheduledEmi,
        'scheduledEmi',
        'Scheduled EMI must not be negative.',
      );
    }

    return VariableRatePeriod._(
      effectiveInstallment: effectiveInstallment,
      annualInterestRate: annualInterestRate,
      scheduledEmi: scheduledEmi,
    );
  }

  const VariableRatePeriod._({
    required this.effectiveInstallment,
    required this.annualInterestRate,
    required this.scheduledEmi,
  });

  final int effectiveInstallment;
  final Percentage annualInterestRate;
  final Money scheduledEmi;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VariableRatePeriod &&
            effectiveInstallment == other.effectiveInstallment &&
            annualInterestRate == other.annualInterestRate &&
            scheduledEmi == other.scheduledEmi;
  }

  @override
  int get hashCode =>
      Object.hash(effectiveInstallment, annualInterestRate, scheduledEmi);

  @override
  String toString() {
    return 'VariableRatePeriod('
        'effectiveInstallment: $effectiveInstallment, '
        'annualInterestRate: $annualInterestRate, '
        'scheduledEmi: $scheduledEmi'
        ')';
  }
}
