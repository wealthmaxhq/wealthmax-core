import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// When a scheduled withdrawal is applied within each monthly period.
enum WithdrawalTiming {
  /// Withdrawal occurs before that month's investment growth.
  beginningOfPeriod,

  /// Withdrawal occurs after that month's investment growth.
  endOfPeriod,
}

/// Immutable inputs for a systematic withdrawal plan projection.
@immutable
final class SwpInput {
  factory SwpInput({
    required Money initialInvestment,
    required Money monthlyWithdrawal,
    required Percentage expectedAnnualReturn,
    required int tenureMonths,
    required WithdrawalTiming withdrawalTiming,
  }) {
    if (!initialInvestment.isPositive) {
      throw ArgumentError.value(
        initialInvestment,
        'initialInvestment',
        'Initial investment must be greater than zero.',
      );
    }
    if (!monthlyWithdrawal.isPositive) {
      throw ArgumentError.value(
        monthlyWithdrawal,
        'monthlyWithdrawal',
        'Monthly withdrawal must be greater than zero.',
      );
    }
    if (monthlyWithdrawal.currency != initialInvestment.currency) {
      throw ArgumentError.value(
        monthlyWithdrawal,
        'monthlyWithdrawal',
        'Currency must match initial investment currency '
            '${initialInvestment.currency.code}.',
      );
    }
    if (expectedAnnualReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        expectedAnnualReturn,
        'expectedAnnualReturn',
        'Expected annual return must not be less than -100%.',
      );
    }
    if (tenureMonths <= 0) {
      throw ArgumentError.value(
        tenureMonths,
        'tenureMonths',
        'Tenure must be greater than zero months.',
      );
    }

    return SwpInput._(
      initialInvestment: initialInvestment,
      monthlyWithdrawal: monthlyWithdrawal,
      expectedAnnualReturn: expectedAnnualReturn,
      tenureMonths: tenureMonths,
      withdrawalTiming: withdrawalTiming,
    );
  }

  const SwpInput._({
    required this.initialInvestment,
    required this.monthlyWithdrawal,
    required this.expectedAnnualReturn,
    required this.tenureMonths,
    required this.withdrawalTiming,
  });

  final Money initialInvestment;
  final Money monthlyWithdrawal;

  /// User-supplied effective annual return assumption.
  final Percentage expectedAnnualReturn;

  final int tenureMonths;
  final WithdrawalTiming withdrawalTiming;

  SwpInput copyWith({
    Money? initialInvestment,
    Money? monthlyWithdrawal,
    Percentage? expectedAnnualReturn,
    int? tenureMonths,
    WithdrawalTiming? withdrawalTiming,
  }) {
    return SwpInput(
      initialInvestment: initialInvestment ?? this.initialInvestment,
      monthlyWithdrawal: monthlyWithdrawal ?? this.monthlyWithdrawal,
      expectedAnnualReturn: expectedAnnualReturn ?? this.expectedAnnualReturn,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      withdrawalTiming: withdrawalTiming ?? this.withdrawalTiming,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SwpInput &&
            initialInvestment == other.initialInvestment &&
            monthlyWithdrawal == other.monthlyWithdrawal &&
            expectedAnnualReturn == other.expectedAnnualReturn &&
            tenureMonths == other.tenureMonths &&
            withdrawalTiming == other.withdrawalTiming;
  }

  @override
  int get hashCode => Object.hash(
    initialInvestment,
    monthlyWithdrawal,
    expectedAnnualReturn,
    tenureMonths,
    withdrawalTiming,
  );

  @override
  String toString() {
    return 'SwpInput('
        'initialInvestment: $initialInvestment, '
        'monthlyWithdrawal: $monthlyWithdrawal, '
        'expectedAnnualReturn: $expectedAnnualReturn, '
        'tenureMonths: $tenureMonths, '
        'withdrawalTiming: ${withdrawalTiming.name}'
        ')';
  }
}
