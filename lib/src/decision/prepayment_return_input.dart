import 'package:meta/meta.dart';

import '../loan/loan_input.dart';
import '../money/money.dart';

/// Immutable inputs for calculating the effective return from prepayment.
@immutable
final class PrepaymentReturnInput {
  factory PrepaymentReturnInput({
    required LoanInput loan,
    required Money extraCash,
    required int decisionInstallment,
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

    return PrepaymentReturnInput._(
      loan: loan,
      extraCash: extraCash,
      decisionInstallment: decisionInstallment,
    );
  }

  const PrepaymentReturnInput._({
    required this.loan,
    required this.extraCash,
    required this.decisionInstallment,
  });

  final LoanInput loan;
  final Money extraCash;
  final int decisionInstallment;

  PrepaymentReturnInput copyWith({
    LoanInput? loan,
    Money? extraCash,
    int? decisionInstallment,
  }) {
    return PrepaymentReturnInput(
      loan: loan ?? this.loan,
      extraCash: extraCash ?? this.extraCash,
      decisionInstallment: decisionInstallment ?? this.decisionInstallment,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PrepaymentReturnInput &&
            loan == other.loan &&
            extraCash == other.extraCash &&
            decisionInstallment == other.decisionInstallment;
  }

  @override
  int get hashCode => Object.hash(loan, extraCash, decisionInstallment);

  @override
  String toString() {
    return 'PrepaymentReturnInput('
        'loan: $loan, '
        'extraCash: $extraCash, '
        'decisionInstallment: $decisionInstallment'
        ')';
  }
}
