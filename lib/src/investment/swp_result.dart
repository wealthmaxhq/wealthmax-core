import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'swp_input.dart';

/// Immutable summary of a systematic withdrawal plan projection.
@immutable
final class SwpResult {
  factory SwpResult({
    required Money initialInvestment,
    required Money monthlyWithdrawal,
    required Money totalWithdrawn,
    required Money endingBalance,
    required Percentage monthlyEquivalentReturn,
    required int tenureMonths,
    required int monthsProcessed,
    required int withdrawalsMade,
    required int fullWithdrawalsMade,
    required int? depletionMonth,
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
    final amounts = <String, Money>{
      'monthlyWithdrawal': monthlyWithdrawal,
      'totalWithdrawn': totalWithdrawn,
      'endingBalance': endingBalance,
    };
    for (final entry in amounts.entries) {
      if (entry.value.currency != initialInvestment.currency) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Currency must match initial investment currency '
          '${initialInvestment.currency.code}.',
        );
      }
      if (entry.value.isNegative) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Amount must not be negative.',
        );
      }
    }
    if (monthlyEquivalentReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        monthlyEquivalentReturn,
        'monthlyEquivalentReturn',
        'Monthly equivalent return must not be less than -100%.',
      );
    }
    if (tenureMonths <= 0) {
      throw ArgumentError.value(
        tenureMonths,
        'tenureMonths',
        'Tenure must be greater than zero months.',
      );
    }
    if (monthsProcessed <= 0 || monthsProcessed > tenureMonths) {
      throw ArgumentError.value(
        monthsProcessed,
        'monthsProcessed',
        'Months processed must be within the projection tenure.',
      );
    }
    if (withdrawalsMade < 0 || withdrawalsMade > monthsProcessed) {
      throw ArgumentError.value(
        withdrawalsMade,
        'withdrawalsMade',
        'Withdrawals made must be within the processed month count.',
      );
    }
    if (fullWithdrawalsMade < 0 || fullWithdrawalsMade > withdrawalsMade) {
      throw ArgumentError.value(
        fullWithdrawalsMade,
        'fullWithdrawalsMade',
        'Full withdrawals must not exceed withdrawals made.',
      );
    }
    if (depletionMonth != null) {
      if (depletionMonth <= 0 || depletionMonth > tenureMonths) {
        throw ArgumentError.value(
          depletionMonth,
          'depletionMonth',
          'Depletion month must be within the projection tenure.',
        );
      }
      if (monthsProcessed != depletionMonth) {
        throw ArgumentError.value(
          monthsProcessed,
          'monthsProcessed',
          'Months processed must equal the depletion month.',
        );
      }
      if (!endingBalance.isZero) {
        throw ArgumentError.value(
          endingBalance,
          'endingBalance',
          'Ending balance must be zero when the corpus is depleted.',
        );
      }
    } else if (monthsProcessed != tenureMonths) {
      throw ArgumentError.value(
        monthsProcessed,
        'monthsProcessed',
        'A non-depleted projection must process the full tenure.',
      );
    }

    final requestedTotal = monthlyWithdrawal.multiply(
      Decimal.fromInt(tenureMonths),
    );
    if (totalWithdrawn.compareTo(requestedTotal) > 0) {
      throw ArgumentError.value(
        totalWithdrawn,
        'totalWithdrawn',
        'Total withdrawn must not exceed total scheduled withdrawals.',
      );
    }

    return SwpResult._(
      initialInvestment: initialInvestment,
      monthlyWithdrawal: monthlyWithdrawal,
      totalWithdrawn: totalWithdrawn,
      endingBalance: endingBalance,
      monthlyEquivalentReturn: monthlyEquivalentReturn,
      tenureMonths: tenureMonths,
      monthsProcessed: monthsProcessed,
      withdrawalsMade: withdrawalsMade,
      fullWithdrawalsMade: fullWithdrawalsMade,
      depletionMonth: depletionMonth,
      withdrawalTiming: withdrawalTiming,
    );
  }

  const SwpResult._({
    required this.initialInvestment,
    required this.monthlyWithdrawal,
    required this.totalWithdrawn,
    required this.endingBalance,
    required this.monthlyEquivalentReturn,
    required this.tenureMonths,
    required this.monthsProcessed,
    required this.withdrawalsMade,
    required this.fullWithdrawalsMade,
    required this.depletionMonth,
    required this.withdrawalTiming,
  });

  final Money initialInvestment;
  final Money monthlyWithdrawal;
  final Money totalWithdrawn;
  final Money endingBalance;
  final Percentage monthlyEquivalentReturn;
  final int tenureMonths;
  final int monthsProcessed;
  final int withdrawalsMade;
  final int fullWithdrawalsMade;
  final int? depletionMonth;
  final WithdrawalTiming withdrawalTiming;

  Money get requestedTotalWithdrawal =>
      monthlyWithdrawal.multiply(Decimal.fromInt(tenureMonths));

  Money get withdrawalShortfall => requestedTotalWithdrawal - totalWithdrawn;

  Money get totalValueReceived => totalWithdrawn + endingBalance;

  Money get netGain => totalValueReceived - initialInvestment;

  bool get isFullyFunded => withdrawalShortfall.isZero;
  bool get isDepleted => depletionMonth != null;
  bool get isDepletedEarly =>
      depletionMonth != null && depletionMonth! < tenureMonths;

  SwpResult copyWith({
    Money? initialInvestment,
    Money? monthlyWithdrawal,
    Money? totalWithdrawn,
    Money? endingBalance,
    Percentage? monthlyEquivalentReturn,
    int? tenureMonths,
    int? monthsProcessed,
    int? withdrawalsMade,
    int? fullWithdrawalsMade,
    int? depletionMonth,
    bool clearDepletionMonth = false,
    WithdrawalTiming? withdrawalTiming,
  }) {
    return SwpResult(
      initialInvestment: initialInvestment ?? this.initialInvestment,
      monthlyWithdrawal: monthlyWithdrawal ?? this.monthlyWithdrawal,
      totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
      endingBalance: endingBalance ?? this.endingBalance,
      monthlyEquivalentReturn:
          monthlyEquivalentReturn ?? this.monthlyEquivalentReturn,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      monthsProcessed: monthsProcessed ?? this.monthsProcessed,
      withdrawalsMade: withdrawalsMade ?? this.withdrawalsMade,
      fullWithdrawalsMade: fullWithdrawalsMade ?? this.fullWithdrawalsMade,
      depletionMonth: clearDepletionMonth
          ? null
          : depletionMonth ?? this.depletionMonth,
      withdrawalTiming: withdrawalTiming ?? this.withdrawalTiming,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SwpResult &&
            initialInvestment == other.initialInvestment &&
            monthlyWithdrawal == other.monthlyWithdrawal &&
            totalWithdrawn == other.totalWithdrawn &&
            endingBalance == other.endingBalance &&
            monthlyEquivalentReturn == other.monthlyEquivalentReturn &&
            tenureMonths == other.tenureMonths &&
            monthsProcessed == other.monthsProcessed &&
            withdrawalsMade == other.withdrawalsMade &&
            fullWithdrawalsMade == other.fullWithdrawalsMade &&
            depletionMonth == other.depletionMonth &&
            withdrawalTiming == other.withdrawalTiming;
  }

  @override
  int get hashCode => Object.hash(
    initialInvestment,
    monthlyWithdrawal,
    totalWithdrawn,
    endingBalance,
    monthlyEquivalentReturn,
    tenureMonths,
    monthsProcessed,
    withdrawalsMade,
    fullWithdrawalsMade,
    depletionMonth,
    withdrawalTiming,
  );

  @override
  String toString() {
    return 'SwpResult('
        'initialInvestment: $initialInvestment, '
        'monthlyWithdrawal: $monthlyWithdrawal, '
        'totalWithdrawn: $totalWithdrawn, '
        'endingBalance: $endingBalance, '
        'withdrawalShortfall: $withdrawalShortfall, '
        'netGain: $netGain, '
        'monthlyEquivalentReturn: $monthlyEquivalentReturn, '
        'tenureMonths: $tenureMonths, '
        'monthsProcessed: $monthsProcessed, '
        'withdrawalsMade: $withdrawalsMade, '
        'fullWithdrawalsMade: $fullWithdrawalsMade, '
        'depletionMonth: $depletionMonth, '
        'withdrawalTiming: ${withdrawalTiming.name}'
        ')';
  }
}
