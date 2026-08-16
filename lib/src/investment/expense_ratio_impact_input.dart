import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable inputs for projecting the long-term impact of an expense ratio.
@immutable
final class ExpenseRatioImpactInput {
  factory ExpenseRatioImpactInput({
    required Money initialInvestment,
    required Percentage grossAnnualReturn,
    required Percentage annualExpenseRatio,
    required int tenureYears,
  }) {
    if (!initialInvestment.isPositive) {
      throw ArgumentError.value(
        initialInvestment,
        'initialInvestment',
        'Initial investment must be greater than zero.',
      );
    }
    if (grossAnnualReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        grossAnnualReturn,
        'grossAnnualReturn',
        'Gross annual return must not be less than -100%.',
      );
    }
    if (annualExpenseRatio.isNegative ||
        annualExpenseRatio.percent >= Decimal.fromInt(100)) {
      throw ArgumentError.value(
        annualExpenseRatio,
        'annualExpenseRatio',
        'Annual expense ratio must be at least 0% and less than 100%.',
      );
    }
    if (tenureYears < 0) {
      throw ArgumentError.value(
        tenureYears,
        'tenureYears',
        'Tenure years must not be negative.',
      );
    }

    return ExpenseRatioImpactInput._(
      initialInvestment: initialInvestment,
      grossAnnualReturn: grossAnnualReturn,
      annualExpenseRatio: annualExpenseRatio,
      tenureYears: tenureYears,
    );
  }

  const ExpenseRatioImpactInput._({
    required this.initialInvestment,
    required this.grossAnnualReturn,
    required this.annualExpenseRatio,
    required this.tenureYears,
  });

  final Money initialInvestment;
  final Percentage grossAnnualReturn;
  final Percentage annualExpenseRatio;
  final int tenureYears;

  ExpenseRatioImpactInput copyWith({
    Money? initialInvestment,
    Percentage? grossAnnualReturn,
    Percentage? annualExpenseRatio,
    int? tenureYears,
  }) {
    return ExpenseRatioImpactInput(
      initialInvestment: initialInvestment ?? this.initialInvestment,
      grossAnnualReturn: grossAnnualReturn ?? this.grossAnnualReturn,
      annualExpenseRatio: annualExpenseRatio ?? this.annualExpenseRatio,
      tenureYears: tenureYears ?? this.tenureYears,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExpenseRatioImpactInput &&
            initialInvestment == other.initialInvestment &&
            grossAnnualReturn == other.grossAnnualReturn &&
            annualExpenseRatio == other.annualExpenseRatio &&
            tenureYears == other.tenureYears;
  }

  @override
  int get hashCode => Object.hash(
    initialInvestment,
    grossAnnualReturn,
    annualExpenseRatio,
    tenureYears,
  );

  @override
  String toString() {
    return 'ExpenseRatioImpactInput('
        'initialInvestment: $initialInvestment, '
        'grossAnnualReturn: $grossAnnualReturn, '
        'annualExpenseRatio: $annualExpenseRatio, '
        'tenureYears: $tenureYears'
        ')';
  }
}
