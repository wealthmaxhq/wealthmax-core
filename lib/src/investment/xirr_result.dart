import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable result of an actual/365 XIRR calculation.
@immutable
final class XirrResult {
  factory XirrResult({
    required Percentage annualizedReturn,
    required Percentage dailyEquivalentReturn,
    required Money totalContributions,
    required Money totalDistributions,
    required Money residualNpv,
    required DateTime startDate,
    required DateTime endDate,
    required int cashFlowCount,
  }) {
    if (annualizedReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        annualizedReturn,
        'annualizedReturn',
        'Annualized return must not be less than -100%.',
      );
    }
    if (dailyEquivalentReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        dailyEquivalentReturn,
        'dailyEquivalentReturn',
        'Daily equivalent return must not be less than -100%.',
      );
    }
    if (!totalContributions.isPositive) {
      throw ArgumentError.value(
        totalContributions,
        'totalContributions',
        'Total contributions must be greater than zero.',
      );
    }
    if (!totalDistributions.isPositive) {
      throw ArgumentError.value(
        totalDistributions,
        'totalDistributions',
        'Total distributions must be greater than zero.',
      );
    }
    final currency = totalContributions.currency;
    if (totalDistributions.currency != currency ||
        residualNpv.currency != currency) {
      throw ArgumentError(
        'Contributions, distributions, and residual NPV must use '
        'currency ${currency.code}.',
      );
    }
    final normalizedStart = DateTime.utc(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime.utc(
      endDate.year,
      endDate.month,
      endDate.day,
    );
    if (!normalizedEnd.isAfter(normalizedStart)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'End date must be after start date.',
      );
    }
    if (cashFlowCount < 2) {
      throw ArgumentError.value(
        cashFlowCount,
        'cashFlowCount',
        'At least two cash flows are required.',
      );
    }

    return XirrResult._(
      annualizedReturn: annualizedReturn,
      dailyEquivalentReturn: dailyEquivalentReturn,
      totalContributions: totalContributions,
      totalDistributions: totalDistributions,
      residualNpv: residualNpv,
      startDate: normalizedStart,
      endDate: normalizedEnd,
      cashFlowCount: cashFlowCount,
    );
  }

  const XirrResult._({
    required this.annualizedReturn,
    required this.dailyEquivalentReturn,
    required this.totalContributions,
    required this.totalDistributions,
    required this.residualNpv,
    required this.startDate,
    required this.endDate,
    required this.cashFlowCount,
  });

  final Percentage annualizedReturn;
  final Percentage dailyEquivalentReturn;
  final Money totalContributions;
  final Money totalDistributions;
  final Money residualNpv;
  final DateTime startDate;
  final DateTime endDate;
  final int cashFlowCount;

  Money get netCashFlow => totalDistributions - totalContributions;
  int get daySpan => endDate.difference(startDate).inDays;

  XirrResult copyWith({
    Percentage? annualizedReturn,
    Percentage? dailyEquivalentReturn,
    Money? totalContributions,
    Money? totalDistributions,
    Money? residualNpv,
    DateTime? startDate,
    DateTime? endDate,
    int? cashFlowCount,
  }) {
    return XirrResult(
      annualizedReturn: annualizedReturn ?? this.annualizedReturn,
      dailyEquivalentReturn:
          dailyEquivalentReturn ?? this.dailyEquivalentReturn,
      totalContributions: totalContributions ?? this.totalContributions,
      totalDistributions: totalDistributions ?? this.totalDistributions,
      residualNpv: residualNpv ?? this.residualNpv,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cashFlowCount: cashFlowCount ?? this.cashFlowCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is XirrResult &&
            annualizedReturn == other.annualizedReturn &&
            dailyEquivalentReturn == other.dailyEquivalentReturn &&
            totalContributions == other.totalContributions &&
            totalDistributions == other.totalDistributions &&
            residualNpv == other.residualNpv &&
            startDate == other.startDate &&
            endDate == other.endDate &&
            cashFlowCount == other.cashFlowCount;
  }

  @override
  int get hashCode => Object.hash(
    annualizedReturn,
    dailyEquivalentReturn,
    totalContributions,
    totalDistributions,
    residualNpv,
    startDate,
    endDate,
    cashFlowCount,
  );

  @override
  String toString() {
    return 'XirrResult('
        'annualizedReturn: $annualizedReturn, '
        'dailyEquivalentReturn: $dailyEquivalentReturn, '
        'totalContributions: $totalContributions, '
        'totalDistributions: $totalDistributions, '
        'netCashFlow: $netCashFlow, '
        'residualNpv: $residualNpv, '
        'startDate: ${startDate.toIso8601String().substring(0, 10)}, '
        'endDate: ${endDate.toIso8601String().substring(0, 10)}, '
        'cashFlowCount: $cashFlowCount'
        ')';
  }
}
