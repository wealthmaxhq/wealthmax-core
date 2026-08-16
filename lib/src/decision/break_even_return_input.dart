import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../loan/loan_input.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable assumptions for finding a prepay-versus-invest break-even rate.
@immutable
final class BreakEvenReturnInput {
  factory BreakEvenReturnInput({
    required LoanInput loan,
    required Money extraCash,
    required int decisionInstallment,
    required Percentage annualExpenseRatio,
  }) {
    if (!extraCash.isPositive) {
      throw ArgumentError.value(
        extraCash,
        'extraCash',
        'Extra cash must be greater than zero.',
      );
    }
    if (extraCash.currency != loan.principal.currency) {
      throw ArgumentError.value(
        extraCash,
        'extraCash',
        'Currency must match loan currency ${loan.principal.currency.code}.',
      );
    }
    if (decisionInstallment <= 0 || decisionInstallment > loan.tenureMonths) {
      throw ArgumentError.value(
        decisionInstallment,
        'decisionInstallment',
        'Decision installment must be within the contractual loan tenure.',
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

    return BreakEvenReturnInput._(
      loan: loan,
      extraCash: extraCash,
      decisionInstallment: decisionInstallment,
      annualExpenseRatio: annualExpenseRatio,
    );
  }

  const BreakEvenReturnInput._({
    required this.loan,
    required this.extraCash,
    required this.decisionInstallment,
    required this.annualExpenseRatio,
  });

  final LoanInput loan;
  final Money extraCash;
  final int decisionInstallment;
  final Percentage annualExpenseRatio;

  BreakEvenReturnInput copyWith({
    LoanInput? loan,
    Money? extraCash,
    int? decisionInstallment,
    Percentage? annualExpenseRatio,
  }) {
    return BreakEvenReturnInput(
      loan: loan ?? this.loan,
      extraCash: extraCash ?? this.extraCash,
      decisionInstallment: decisionInstallment ?? this.decisionInstallment,
      annualExpenseRatio: annualExpenseRatio ?? this.annualExpenseRatio,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BreakEvenReturnInput &&
            loan == other.loan &&
            extraCash == other.extraCash &&
            decisionInstallment == other.decisionInstallment &&
            annualExpenseRatio == other.annualExpenseRatio;
  }

  @override
  int get hashCode =>
      Object.hash(loan, extraCash, decisionInstallment, annualExpenseRatio);

  @override
  String toString() {
    return 'BreakEvenReturnInput('
        'loan: $loan, '
        'extraCash: $extraCash, '
        'decisionInstallment: $decisionInstallment, '
        'annualExpenseRatio: $annualExpenseRatio'
        ')';
  }
}
