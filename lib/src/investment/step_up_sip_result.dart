import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'sip_input.dart';

/// Immutable result of a monthly step-up SIP projection.
@immutable
final class StepUpSipResult {
  factory StepUpSipResult({
    required Money initialMonthlyContribution,
    required Money finalMonthlyContribution,
    required Money totalInvested,
    required Money futureValue,
    required Percentage monthlyEquivalentReturn,
    required Percentage cumulativeReturn,
    required Percentage annualStepUp,
    required int tenureMonths,
    required ContributionTiming contributionTiming,
  }) {
    if (!initialMonthlyContribution.isPositive) {
      throw ArgumentError.value(
        initialMonthlyContribution,
        'initialMonthlyContribution',
        'Initial monthly contribution must be greater than zero.',
      );
    }
    if (tenureMonths <= 0) {
      throw ArgumentError.value(
        tenureMonths,
        'tenureMonths',
        'Tenure must be greater than zero months.',
      );
    }
    if (annualStepUp.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        annualStepUp,
        'annualStepUp',
        'Annual step-up must not be less than -100%.',
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

    final amounts = <String, Money>{
      'finalMonthlyContribution': finalMonthlyContribution,
      'totalInvested': totalInvested,
      'futureValue': futureValue,
    };
    for (final entry in amounts.entries) {
      if (entry.value.currency != initialMonthlyContribution.currency) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Currency must match initial monthly contribution currency '
          '${initialMonthlyContribution.currency.code}.',
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
    if (!totalInvested.isPositive) {
      throw ArgumentError.value(
        totalInvested,
        'totalInvested',
        'Total invested must be greater than zero.',
      );
    }

    return StepUpSipResult._(
      initialMonthlyContribution: initialMonthlyContribution,
      finalMonthlyContribution: finalMonthlyContribution,
      totalInvested: totalInvested,
      futureValue: futureValue,
      monthlyEquivalentReturn: monthlyEquivalentReturn,
      cumulativeReturn: cumulativeReturn,
      annualStepUp: annualStepUp,
      tenureMonths: tenureMonths,
      contributionTiming: contributionTiming,
    );
  }

  const StepUpSipResult._({
    required this.initialMonthlyContribution,
    required this.finalMonthlyContribution,
    required this.totalInvested,
    required this.futureValue,
    required this.monthlyEquivalentReturn,
    required this.cumulativeReturn,
    required this.annualStepUp,
    required this.tenureMonths,
    required this.contributionTiming,
  });

  final Money initialMonthlyContribution;
  final Money finalMonthlyContribution;
  final Money totalInvested;
  final Money futureValue;
  final Percentage monthlyEquivalentReturn;
  final Percentage cumulativeReturn;
  final Percentage annualStepUp;
  final int tenureMonths;
  final ContributionTiming contributionTiming;

  Money get totalGain => futureValue - totalInvested;
  bool get isGain => totalGain.isPositive;
  bool get isLoss => totalGain.isNegative;

  StepUpSipResult copyWith({
    Money? initialMonthlyContribution,
    Money? finalMonthlyContribution,
    Money? totalInvested,
    Money? futureValue,
    Percentage? monthlyEquivalentReturn,
    Percentage? cumulativeReturn,
    Percentage? annualStepUp,
    int? tenureMonths,
    ContributionTiming? contributionTiming,
  }) {
    return StepUpSipResult(
      initialMonthlyContribution:
          initialMonthlyContribution ?? this.initialMonthlyContribution,
      finalMonthlyContribution:
          finalMonthlyContribution ?? this.finalMonthlyContribution,
      totalInvested: totalInvested ?? this.totalInvested,
      futureValue: futureValue ?? this.futureValue,
      monthlyEquivalentReturn:
          monthlyEquivalentReturn ?? this.monthlyEquivalentReturn,
      cumulativeReturn: cumulativeReturn ?? this.cumulativeReturn,
      annualStepUp: annualStepUp ?? this.annualStepUp,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      contributionTiming: contributionTiming ?? this.contributionTiming,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StepUpSipResult &&
            initialMonthlyContribution == other.initialMonthlyContribution &&
            finalMonthlyContribution == other.finalMonthlyContribution &&
            totalInvested == other.totalInvested &&
            futureValue == other.futureValue &&
            monthlyEquivalentReturn == other.monthlyEquivalentReturn &&
            cumulativeReturn == other.cumulativeReturn &&
            annualStepUp == other.annualStepUp &&
            tenureMonths == other.tenureMonths &&
            contributionTiming == other.contributionTiming;
  }

  @override
  int get hashCode => Object.hash(
    initialMonthlyContribution,
    finalMonthlyContribution,
    totalInvested,
    futureValue,
    monthlyEquivalentReturn,
    cumulativeReturn,
    annualStepUp,
    tenureMonths,
    contributionTiming,
  );

  @override
  String toString() {
    return 'StepUpSipResult('
        'initialMonthlyContribution: $initialMonthlyContribution, '
        'finalMonthlyContribution: $finalMonthlyContribution, '
        'totalInvested: $totalInvested, '
        'futureValue: $futureValue, '
        'totalGain: $totalGain, '
        'monthlyEquivalentReturn: $monthlyEquivalentReturn, '
        'cumulativeReturn: $cumulativeReturn, '
        'annualStepUp: $annualStepUp, '
        'tenureMonths: $tenureMonths, '
        'contributionTiming: ${contributionTiming.name}'
        ')';
  }
}
