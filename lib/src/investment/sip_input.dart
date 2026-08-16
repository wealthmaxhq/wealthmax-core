import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// When each recurring investment is applied within a monthly period.
enum ContributionTiming {
  /// Contribution is invested before that month's growth is applied.
  beginningOfPeriod,

  /// Contribution is invested after that month's growth is applied.
  endOfPeriod,
}

/// Immutable inputs for a monthly systematic investment projection.
@immutable
final class SipInput {
  factory SipInput({
    required Money monthlyContribution,
    required Percentage expectedAnnualReturn,
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

    return SipInput._(
      monthlyContribution: monthlyContribution,
      expectedAnnualReturn: expectedAnnualReturn,
      tenureMonths: tenureMonths,
      contributionTiming: contributionTiming,
    );
  }

  const SipInput._({
    required this.monthlyContribution,
    required this.expectedAnnualReturn,
    required this.tenureMonths,
    required this.contributionTiming,
  });

  final Money monthlyContribution;

  /// User-supplied effective annual return assumption.
  final Percentage expectedAnnualReturn;

  final int tenureMonths;
  final ContributionTiming contributionTiming;

  SipInput copyWith({
    Money? monthlyContribution,
    Percentage? expectedAnnualReturn,
    int? tenureMonths,
    ContributionTiming? contributionTiming,
  }) {
    return SipInput(
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      expectedAnnualReturn: expectedAnnualReturn ?? this.expectedAnnualReturn,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      contributionTiming: contributionTiming ?? this.contributionTiming,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SipInput &&
            monthlyContribution == other.monthlyContribution &&
            expectedAnnualReturn == other.expectedAnnualReturn &&
            tenureMonths == other.tenureMonths &&
            contributionTiming == other.contributionTiming;
  }

  @override
  int get hashCode => Object.hash(
    monthlyContribution,
    expectedAnnualReturn,
    tenureMonths,
    contributionTiming,
  );

  @override
  String toString() {
    return 'SipInput('
        'monthlyContribution: $monthlyContribution, '
        'expectedAnnualReturn: $expectedAnnualReturn, '
        'tenureMonths: $tenureMonths, '
        'contributionTiming: ${contributionTiming.name}'
        ')';
  }
}
