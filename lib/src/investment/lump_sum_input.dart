import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable inputs for a lump-sum investment projection.
@immutable
final class LumpSumInput {
  factory LumpSumInput({
    required Money initialInvestment,
    required Percentage expectedAnnualReturn,
    required int tenureYears,
  }) {
    if (!initialInvestment.isPositive) {
      throw ArgumentError.value(
        initialInvestment,
        'initialInvestment',
        'Initial investment must be greater than zero.',
      );
    }
    if (expectedAnnualReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        expectedAnnualReturn,
        'expectedAnnualReturn',
        'Expected annual return must not be less than -100%.',
      );
    }
    if (tenureYears < 0) {
      throw ArgumentError.value(
        tenureYears,
        'tenureYears',
        'Tenure years must not be negative.',
      );
    }

    return LumpSumInput._(
      initialInvestment: initialInvestment,
      expectedAnnualReturn: expectedAnnualReturn,
      tenureYears: tenureYears,
    );
  }

  const LumpSumInput._({
    required this.initialInvestment,
    required this.expectedAnnualReturn,
    required this.tenureYears,
  });

  final Money initialInvestment;

  /// User-supplied effective annual return assumption.
  final Percentage expectedAnnualReturn;

  final int tenureYears;

  LumpSumInput copyWith({
    Money? initialInvestment,
    Percentage? expectedAnnualReturn,
    int? tenureYears,
  }) {
    return LumpSumInput(
      initialInvestment: initialInvestment ?? this.initialInvestment,
      expectedAnnualReturn: expectedAnnualReturn ?? this.expectedAnnualReturn,
      tenureYears: tenureYears ?? this.tenureYears,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LumpSumInput &&
            initialInvestment == other.initialInvestment &&
            expectedAnnualReturn == other.expectedAnnualReturn &&
            tenureYears == other.tenureYears;
  }

  @override
  int get hashCode =>
      Object.hash(initialInvestment, expectedAnnualReturn, tenureYears);

  @override
  String toString() {
    return 'LumpSumInput('
        'initialInvestment: $initialInvestment, '
        'expectedAnnualReturn: $expectedAnnualReturn, '
        'tenureYears: $tenureYears'
        ')';
  }
}
