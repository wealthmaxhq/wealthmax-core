import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable effective borrowing-cost summary for a loan.
///
/// [netProceeds] represents the amount made available to the borrower after
/// up-front processing fees. Rates are derived from the actual rounded
/// installment cash flows rather than copied from the advertised nominal rate.
@immutable
final class EffectiveRateResult {
  factory EffectiveRateResult({
    required Money netProceeds,
    required Money totalRepayment,
    required Percentage monthlyEffectiveRate,
    required Percentage nominalAnnualPercentageRate,
    required Percentage effectiveAnnualRate,
    required int paymentCount,
  }) {
    if (!netProceeds.isPositive) {
      throw ArgumentError.value(
        netProceeds,
        'netProceeds',
        'Net proceeds must be greater than zero.',
      );
    }
    if (totalRepayment.currency != netProceeds.currency) {
      throw ArgumentError.value(
        totalRepayment,
        'totalRepayment',
        'Currency must match net proceeds currency '
            '${netProceeds.currency.code}.',
      );
    }
    if (totalRepayment.compareTo(netProceeds) < 0) {
      throw ArgumentError.value(
        totalRepayment,
        'totalRepayment',
        'Total repayment must not be less than net proceeds.',
      );
    }
    if (monthlyEffectiveRate.isNegative) {
      throw ArgumentError.value(
        monthlyEffectiveRate,
        'monthlyEffectiveRate',
        'Monthly effective rate must not be negative.',
      );
    }
    if (nominalAnnualPercentageRate.isNegative) {
      throw ArgumentError.value(
        nominalAnnualPercentageRate,
        'nominalAnnualPercentageRate',
        'Nominal annual percentage rate must not be negative.',
      );
    }
    if (effectiveAnnualRate.isNegative) {
      throw ArgumentError.value(
        effectiveAnnualRate,
        'effectiveAnnualRate',
        'Effective annual rate must not be negative.',
      );
    }
    if (paymentCount <= 0) {
      throw ArgumentError.value(
        paymentCount,
        'paymentCount',
        'Payment count must be greater than zero.',
      );
    }

    return EffectiveRateResult._(
      netProceeds: netProceeds,
      totalRepayment: totalRepayment,
      monthlyEffectiveRate: monthlyEffectiveRate,
      nominalAnnualPercentageRate: nominalAnnualPercentageRate,
      effectiveAnnualRate: effectiveAnnualRate,
      paymentCount: paymentCount,
    );
  }

  const EffectiveRateResult._({
    required this.netProceeds,
    required this.totalRepayment,
    required this.monthlyEffectiveRate,
    required this.nominalAnnualPercentageRate,
    required this.effectiveAnnualRate,
    required this.paymentCount,
  });

  /// Amount available to the borrower after up-front fees.
  final Money netProceeds;

  /// Sum of the actual rounded repayment cash flows.
  final Money totalRepayment;

  /// Periodic internal rate of return for monthly repayment cash flows.
  final Percentage monthlyEffectiveRate;

  /// Monthly effective rate multiplied by twelve.
  final Percentage nominalAnnualPercentageRate;

  /// Compounded annual rate: `(1 + monthlyRate)^12 - 1`.
  final Percentage effectiveAnnualRate;

  /// Number of repayment cash flows used by the rate solver.
  final int paymentCount;

  /// Total financing cost measured against the amount actually received.
  Money get financeCharge => totalRepayment - netProceeds;

  EffectiveRateResult copyWith({
    Money? netProceeds,
    Money? totalRepayment,
    Percentage? monthlyEffectiveRate,
    Percentage? nominalAnnualPercentageRate,
    Percentage? effectiveAnnualRate,
    int? paymentCount,
  }) {
    return EffectiveRateResult(
      netProceeds: netProceeds ?? this.netProceeds,
      totalRepayment: totalRepayment ?? this.totalRepayment,
      monthlyEffectiveRate: monthlyEffectiveRate ?? this.monthlyEffectiveRate,
      nominalAnnualPercentageRate:
          nominalAnnualPercentageRate ?? this.nominalAnnualPercentageRate,
      effectiveAnnualRate: effectiveAnnualRate ?? this.effectiveAnnualRate,
      paymentCount: paymentCount ?? this.paymentCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EffectiveRateResult &&
            netProceeds == other.netProceeds &&
            totalRepayment == other.totalRepayment &&
            monthlyEffectiveRate == other.monthlyEffectiveRate &&
            nominalAnnualPercentageRate == other.nominalAnnualPercentageRate &&
            effectiveAnnualRate == other.effectiveAnnualRate &&
            paymentCount == other.paymentCount;
  }

  @override
  int get hashCode => Object.hash(
    netProceeds,
    totalRepayment,
    monthlyEffectiveRate,
    nominalAnnualPercentageRate,
    effectiveAnnualRate,
    paymentCount,
  );

  @override
  String toString() {
    return 'EffectiveRateResult('
        'netProceeds: $netProceeds, '
        'totalRepayment: $totalRepayment, '
        'financeCharge: $financeCharge, '
        'monthlyEffectiveRate: $monthlyEffectiveRate, '
        'nominalAnnualPercentageRate: $nominalAnnualPercentageRate, '
        'effectiveAnnualRate: $effectiveAnnualRate, '
        'paymentCount: $paymentCount'
        ')';
  }
}
