import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'sip_input.dart';

/// Immutable result of a monthly SIP projection.
@immutable
final class SipResult {
  factory SipResult({
    required Money monthlyContribution,
    required Money totalInvested,
    required Money futureValue,
    required Percentage monthlyEquivalentReturn,
    required Percentage cumulativeReturn,
    required int tenureMonths,
    required ContributionTiming contributionTiming,
  }) {
    if (!monthlyContribution.isPositive) {
      throw ArgumentError.value(
        monthlyContribution,
        'monthlyContribution',
        'Monthly contribution must be greater than zero.',
      );
    }
    if (tenureMonths <= 0) {
      throw ArgumentError.value(
        tenureMonths,
        'tenureMonths',
        'Tenure must be greater than zero months.',
      );
    }
    final amounts = <String, Money>{
      'totalInvested': totalInvested,
      'futureValue': futureValue,
    };
    for (final amount in amounts.entries) {
      if (amount.value.currency != monthlyContribution.currency) {
        throw ArgumentError.value(
          amount.value,
          amount.key,
          'Currency must match monthly contribution currency '
          '${monthlyContribution.currency.code}.',
        );
      }
      if (amount.value.isNegative) {
        throw ArgumentError.value(
          amount.value,
          amount.key,
          'Amount must not be negative.',
        );
      }
    }
    if (!totalInvested.isPositive) {
      throw ArgumentError.value(
        totalInvested,
        'totalInvested',
        'Total invested must be greater than zero.',
      );
    }
    final expectedTotalInvested = monthlyContribution.multiply(
      Decimal.fromInt(tenureMonths),
    );
    if (totalInvested != expectedTotalInvested) {
      throw ArgumentError.value(
        totalInvested,
        'totalInvested',
        'Total invested must equal monthly contribution multiplied by tenure.',
      );
    }
    if (monthlyEquivalentReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        monthlyEquivalentReturn,
        'monthlyEquivalentReturn',
        'Monthly equivalent return must not be less than -100%.',
      );
    }
    if (cumulativeReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        cumulativeReturn,
        'cumulativeReturn',
        'Cumulative return must not be less than -100%.',
      );
    }
    return SipResult._(
      monthlyContribution: monthlyContribution,
      totalInvested: totalInvested,
      futureValue: futureValue,
      monthlyEquivalentReturn: monthlyEquivalentReturn,
      cumulativeReturn: cumulativeReturn,
      tenureMonths: tenureMonths,
      contributionTiming: contributionTiming,
    );
  }

  const SipResult._({
    required this.monthlyContribution,
    required this.totalInvested,
    required this.futureValue,
    required this.monthlyEquivalentReturn,
    required this.cumulativeReturn,
    required this.tenureMonths,
    required this.contributionTiming,
  });

  final Money monthlyContribution;
  final Money totalInvested;
  final Money futureValue;
  final Percentage monthlyEquivalentReturn;
  final Percentage cumulativeReturn;
  final int tenureMonths;
  final ContributionTiming contributionTiming;

  Money get totalGain => futureValue - totalInvested;
  bool get isGain => totalGain.isPositive;
  bool get isLoss => totalGain.isNegative;

  SipResult copyWith({
    Money? monthlyContribution,
    Money? totalInvested,
    Money? futureValue,
    Percentage? monthlyEquivalentReturn,
    Percentage? cumulativeReturn,
    int? tenureMonths,
    ContributionTiming? contributionTiming,
  }) {
    return SipResult(
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      totalInvested: totalInvested ?? this.totalInvested,
      futureValue: futureValue ?? this.futureValue,
      monthlyEquivalentReturn:
          monthlyEquivalentReturn ?? this.monthlyEquivalentReturn,
      cumulativeReturn: cumulativeReturn ?? this.cumulativeReturn,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      contributionTiming: contributionTiming ?? this.contributionTiming,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SipResult &&
            monthlyContribution == other.monthlyContribution &&
            totalInvested == other.totalInvested &&
            futureValue == other.futureValue &&
            monthlyEquivalentReturn == other.monthlyEquivalentReturn &&
            cumulativeReturn == other.cumulativeReturn &&
            tenureMonths == other.tenureMonths &&
            contributionTiming == other.contributionTiming;
  }

  @override
  int get hashCode => Object.hash(
    monthlyContribution,
    totalInvested,
    futureValue,
    monthlyEquivalentReturn,
    cumulativeReturn,
    tenureMonths,
    contributionTiming,
  );

  @override
  String toString() {
    return 'SipResult('
        'monthlyContribution: $monthlyContribution, '
        'totalInvested: $totalInvested, '
        'futureValue: $futureValue, '
        'totalGain: $totalGain, '
        'monthlyEquivalentReturn: $monthlyEquivalentReturn, '
        'cumulativeReturn: $cumulativeReturn, '
        'tenureMonths: $tenureMonths, '
        'contributionTiming: ${contributionTiming.name}'
        ')';
  }
}
