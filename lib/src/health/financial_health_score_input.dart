import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';

/// Household cash-flow and liquidity inputs for a financial health score.
@immutable
final class FinancialHealthScoreInput {
  factory FinancialHealthScoreInput({
    required Money liquidSavings,
    required Money monthlyNetIncome,
    required Money monthlyEssentialExpenses,
    required Money monthlyDebtPayments,
    required Money monthlySavings,
  }) {
    final values = {
      'liquidSavings': liquidSavings,
      'monthlyNetIncome': monthlyNetIncome,
      'monthlyEssentialExpenses': monthlyEssentialExpenses,
      'monthlyDebtPayments': monthlyDebtPayments,
      'monthlySavings': monthlySavings,
    };
    for (final entry in values.entries) {
      if (entry.value.amount < Decimal.zero) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Must not be negative.',
        );
      }
      if (entry.value.currency != monthlyNetIncome.currency) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'All amounts must use ${monthlyNetIncome.currency.code}.',
        );
      }
    }
    if (!monthlyNetIncome.isPositive) {
      throw ArgumentError.value(
        monthlyNetIncome,
        'monthlyNetIncome',
        'Must be greater than zero.',
      );
    }
    if (!monthlyEssentialExpenses.isPositive) {
      throw ArgumentError.value(
        monthlyEssentialExpenses,
        'monthlyEssentialExpenses',
        'Must be greater than zero.',
      );
    }

    return FinancialHealthScoreInput._(
      liquidSavings: liquidSavings,
      monthlyNetIncome: monthlyNetIncome,
      monthlyEssentialExpenses: monthlyEssentialExpenses,
      monthlyDebtPayments: monthlyDebtPayments,
      monthlySavings: monthlySavings,
    );
  }

  const FinancialHealthScoreInput._({
    required this.liquidSavings,
    required this.monthlyNetIncome,
    required this.monthlyEssentialExpenses,
    required this.monthlyDebtPayments,
    required this.monthlySavings,
  });

  final Money liquidSavings;
  final Money monthlyNetIncome;
  final Money monthlyEssentialExpenses;
  final Money monthlyDebtPayments;
  final Money monthlySavings;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FinancialHealthScoreInput &&
            liquidSavings == other.liquidSavings &&
            monthlyNetIncome == other.monthlyNetIncome &&
            monthlyEssentialExpenses == other.monthlyEssentialExpenses &&
            monthlyDebtPayments == other.monthlyDebtPayments &&
            monthlySavings == other.monthlySavings;
  }

  @override
  int get hashCode => Object.hash(
    liquidSavings,
    monthlyNetIncome,
    monthlyEssentialExpenses,
    monthlyDebtPayments,
    monthlySavings,
  );
}
