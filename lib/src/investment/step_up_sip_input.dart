import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'sip_input.dart';

/// Immutable inputs for a monthly SIP whose contribution changes annually.
@immutable
final class StepUpSipInput {
  factory StepUpSipInput({
    required Money initialMonthlyContribution,
    required Percentage expectedAnnualReturn,
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
    if (expectedAnnualReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        expectedAnnualReturn,
        'expectedAnnualReturn',
        'Expected annual return must not be less than -100%.',
      );
    }
    if (annualStepUp.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        annualStepUp,
        'annualStepUp',
        'Annual step-up must not be less than -100%.',
      );
    }
    if (tenureMonths <= 0) {
      throw ArgumentError.value(
        tenureMonths,
        'tenureMonths',
        'Tenure must be greater than zero months.',
      );
    }

    return StepUpSipInput._(
      initialMonthlyContribution: initialMonthlyContribution,
      expectedAnnualReturn: expectedAnnualReturn,
      annualStepUp: annualStepUp,
      tenureMonths: tenureMonths,
      contributionTiming: contributionTiming,
    );
  }

  const StepUpSipInput._({
    required this.initialMonthlyContribution,
    required this.expectedAnnualReturn,
    required this.annualStepUp,
    required this.tenureMonths,
    required this.contributionTiming,
  });

  final Money initialMonthlyContribution;

  /// User-supplied effective annual return assumption.
  final Percentage expectedAnnualReturn;

  /// Annual percentage change applied after each completed 12-month block.
  final Percentage annualStepUp;

  final int tenureMonths;
  final ContributionTiming contributionTiming;

  StepUpSipInput copyWith({
    Money? initialMonthlyContribution,
    Percentage? expectedAnnualReturn,
    Percentage? annualStepUp,
    int? tenureMonths,
    ContributionTiming? contributionTiming,
  }) {
    return StepUpSipInput(
      initialMonthlyContribution:
          initialMonthlyContribution ?? this.initialMonthlyContribution,
      expectedAnnualReturn: expectedAnnualReturn ?? this.expectedAnnualReturn,
      annualStepUp: annualStepUp ?? this.annualStepUp,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      contributionTiming: contributionTiming ?? this.contributionTiming,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StepUpSipInput &&
            initialMonthlyContribution == other.initialMonthlyContribution &&
            expectedAnnualReturn == other.expectedAnnualReturn &&
            annualStepUp == other.annualStepUp &&
            tenureMonths == other.tenureMonths &&
            contributionTiming == other.contributionTiming;
  }

  @override
  int get hashCode => Object.hash(
    initialMonthlyContribution,
    expectedAnnualReturn,
    annualStepUp,
    tenureMonths,
    contributionTiming,
  );

  @override
  String toString() {
    return 'StepUpSipInput('
        'initialMonthlyContribution: $initialMonthlyContribution, '
        'expectedAnnualReturn: $expectedAnnualReturn, '
        'annualStepUp: $annualStepUp, '
        'tenureMonths: $tenureMonths, '
        'contributionTiming: ${contributionTiming.name}'
        ')';
  }
}
