import 'package:meta/meta.dart';

import '../money/money.dart';

/// An applied EMI period in a scheduled-payment strategy.
@immutable
final class EmiPaymentPeriod {
  factory EmiPaymentPeriod({
    required int effectiveInstallment,
    required Money scheduledEmi,
  }) {
    if (effectiveInstallment <= 0) {
      throw ArgumentError.value(
        effectiveInstallment,
        'effectiveInstallment',
        'Effective installment must be greater than zero.',
      );
    }
    if (scheduledEmi.isNegative) {
      throw ArgumentError.value(
        scheduledEmi,
        'scheduledEmi',
        'Scheduled EMI must not be negative.',
      );
    }
    return EmiPaymentPeriod._(
      effectiveInstallment: effectiveInstallment,
      scheduledEmi: scheduledEmi,
    );
  }

  const EmiPaymentPeriod._({
    required this.effectiveInstallment,
    required this.scheduledEmi,
  });

  final int effectiveInstallment;
  final Money scheduledEmi;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EmiPaymentPeriod &&
            effectiveInstallment == other.effectiveInstallment &&
            scheduledEmi == other.scheduledEmi;
  }

  @override
  int get hashCode => Object.hash(effectiveInstallment, scheduledEmi);

  @override
  String toString() {
    return 'EmiPaymentPeriod('
        'effectiveInstallment: $effectiveInstallment, '
        'scheduledEmi: $scheduledEmi'
        ')';
  }
}
