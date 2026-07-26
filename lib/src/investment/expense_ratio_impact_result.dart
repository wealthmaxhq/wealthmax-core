import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable projection comparing gross value with value after annual fees.
@immutable
final class ExpenseRatioImpactResult {
  factory ExpenseRatioImpactResult({
    required Money initialInvestment,
    required Money grossFutureValue,
    required Money netFutureValue,
    required Percentage grossAnnualReturn,
    required Percentage annualExpenseRatio,
    required Percentage netAnnualReturn,
    required int tenureYears,
  }) {
    if (!initialInvestment.isPositive) {
      throw ArgumentError.value(
        initialInvestment,
        'initialInvestment',
        'Initial investment must be greater than zero.',
      );
    }
    for (final value in <Money>[grossFutureValue, netFutureValue]) {
      if (value.currency != initialInvestment.currency) {
        throw ArgumentError.value(
          value,
          'futureValue',
          'Currency must match ${initialInvestment.currency.code}.',
        );
      }
      if (value.isNegative) {
        throw ArgumentError.value(
          value,
          'futureValue',
          'Future values must not be negative.',
        );
      }
    }
    if (netFutureValue.amount > grossFutureValue.amount) {
      throw ArgumentError.value(
        netFutureValue,
        'netFutureValue',
        'Net future value must not exceed gross future value.',
      );
    }
    if (grossAnnualReturn.percent < Decimal.fromInt(-100) ||
        netAnnualReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError('Annual returns must not be less than -100%.');
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

    return ExpenseRatioImpactResult._(
      initialInvestment: initialInvestment,
      grossFutureValue: grossFutureValue,
      netFutureValue: netFutureValue,
      grossAnnualReturn: grossAnnualReturn,
      annualExpenseRatio: annualExpenseRatio,
      netAnnualReturn: netAnnualReturn,
      tenureYears: tenureYears,
    );
  }

  const ExpenseRatioImpactResult._({
    required this.initialInvestment,
    required this.grossFutureValue,
    required this.netFutureValue,
    required this.grossAnnualReturn,
    required this.annualExpenseRatio,
    required this.netAnnualReturn,
    required this.tenureYears,
  });

  final Money initialInvestment;
  final Money grossFutureValue;
  final Money netFutureValue;
  final Percentage grossAnnualReturn;
  final Percentage annualExpenseRatio;
  final Percentage netAnnualReturn;
  final int tenureYears;

  Money get wealthLostToFees => grossFutureValue - netFutureValue;
  Money get grossGain => grossFutureValue - initialInvestment;
  Money get netGain => netFutureValue - initialInvestment;
  bool get hasFeeImpact => wealthLostToFees.isPositive;

  ExpenseRatioImpactResult copyWith({
    Money? initialInvestment,
    Money? grossFutureValue,
    Money? netFutureValue,
    Percentage? grossAnnualReturn,
    Percentage? annualExpenseRatio,
    Percentage? netAnnualReturn,
    int? tenureYears,
  }) {
    return ExpenseRatioImpactResult(
      initialInvestment: initialInvestment ?? this.initialInvestment,
      grossFutureValue: grossFutureValue ?? this.grossFutureValue,
      netFutureValue: netFutureValue ?? this.netFutureValue,
      grossAnnualReturn: grossAnnualReturn ?? this.grossAnnualReturn,
      annualExpenseRatio: annualExpenseRatio ?? this.annualExpenseRatio,
      netAnnualReturn: netAnnualReturn ?? this.netAnnualReturn,
      tenureYears: tenureYears ?? this.tenureYears,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExpenseRatioImpactResult &&
            initialInvestment == other.initialInvestment &&
            grossFutureValue == other.grossFutureValue &&
            netFutureValue == other.netFutureValue &&
            grossAnnualReturn == other.grossAnnualReturn &&
            annualExpenseRatio == other.annualExpenseRatio &&
            netAnnualReturn == other.netAnnualReturn &&
            tenureYears == other.tenureYears;
  }

  @override
  int get hashCode => Object.hash(
    initialInvestment,
    grossFutureValue,
    netFutureValue,
    grossAnnualReturn,
    annualExpenseRatio,
    netAnnualReturn,
    tenureYears,
  );

  @override
  String toString() {
    return 'ExpenseRatioImpactResult('
        'initialInvestment: $initialInvestment, '
        'grossFutureValue: $grossFutureValue, '
        'netFutureValue: $netFutureValue, '
        'wealthLostToFees: $wealthLostToFees, '
        'grossAnnualReturn: $grossAnnualReturn, '
        'annualExpenseRatio: $annualExpenseRatio, '
        'netAnnualReturn: $netAnnualReturn, '
        'tenureYears: $tenureYears'
        ')';
  }
}
