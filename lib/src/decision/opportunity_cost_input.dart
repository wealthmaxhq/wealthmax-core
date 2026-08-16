import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../loan/loan_input.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable assumptions for a one-time prepay-versus-invest decision.
@immutable
final class OpportunityCostInput {
  factory OpportunityCostInput({
    required LoanInput loan,
    required Money extraCash,
    required int decisionInstallment,
    required Percentage grossAnnualInvestmentReturn,
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
    if (grossAnnualInvestmentReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        grossAnnualInvestmentReturn,
        'grossAnnualInvestmentReturn',
        'Gross annual investment return must not be less than -100%.',
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

    return OpportunityCostInput._(
      loan: loan,
      extraCash: extraCash,
      decisionInstallment: decisionInstallment,
      grossAnnualInvestmentReturn: grossAnnualInvestmentReturn,
      annualExpenseRatio: annualExpenseRatio,
    );
  }

  const OpportunityCostInput._({
    required this.loan,
    required this.extraCash,
    required this.decisionInstallment,
    required this.grossAnnualInvestmentReturn,
    required this.annualExpenseRatio,
  });

  final LoanInput loan;
  final Money extraCash;
  final int decisionInstallment;
  final Percentage grossAnnualInvestmentReturn;
  final Percentage annualExpenseRatio;

  OpportunityCostInput copyWith({
    LoanInput? loan,
    Money? extraCash,
    int? decisionInstallment,
    Percentage? grossAnnualInvestmentReturn,
    Percentage? annualExpenseRatio,
  }) {
    return OpportunityCostInput(
      loan: loan ?? this.loan,
      extraCash: extraCash ?? this.extraCash,
      decisionInstallment: decisionInstallment ?? this.decisionInstallment,
      grossAnnualInvestmentReturn:
          grossAnnualInvestmentReturn ?? this.grossAnnualInvestmentReturn,
      annualExpenseRatio: annualExpenseRatio ?? this.annualExpenseRatio,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OpportunityCostInput &&
            loan == other.loan &&
            extraCash == other.extraCash &&
            decisionInstallment == other.decisionInstallment &&
            grossAnnualInvestmentReturn == other.grossAnnualInvestmentReturn &&
            annualExpenseRatio == other.annualExpenseRatio;
  }

  @override
  int get hashCode => Object.hash(
    loan,
    extraCash,
    decisionInstallment,
    grossAnnualInvestmentReturn,
    annualExpenseRatio,
  );

  @override
  String toString() {
    return 'OpportunityCostInput('
        'loan: $loan, '
        'extraCash: $extraCash, '
        'decisionInstallment: $decisionInstallment, '
        'grossAnnualInvestmentReturn: $grossAnnualInvestmentReturn, '
        'annualExpenseRatio: $annualExpenseRatio'
        ')';
  }
}
