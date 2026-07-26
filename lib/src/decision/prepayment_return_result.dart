import 'dart:collection';

import 'package:meta/meta.dart';

import '../loan/loan_prepayment_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';

/// One incremental monthly cash flow created by choosing prepayment.
@immutable
final class PrepaymentReturnCashFlow {
  factory PrepaymentReturnCashFlow({
    required int monthsFromDecision,
    required Money amount,
  }) {
    if (monthsFromDecision < 0) {
      throw ArgumentError.value(
        monthsFromDecision,
        'monthsFromDecision',
        'Months from decision must not be negative.',
      );
    }
    if (amount.isZero) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Zero cash flows must be omitted.',
      );
    }
    return PrepaymentReturnCashFlow._(
      monthsFromDecision: monthsFromDecision,
      amount: amount,
    );
  }

  const PrepaymentReturnCashFlow._({
    required this.monthsFromDecision,
    required this.amount,
  });

  final int monthsFromDecision;
  final Money amount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PrepaymentReturnCashFlow &&
            monthsFromDecision == other.monthsFromDecision &&
            amount == other.amount;
  }

  @override
  int get hashCode => Object.hash(monthsFromDecision, amount);

  @override
  String toString() {
    return 'PrepaymentReturnCashFlow('
        'monthsFromDecision: $monthsFromDecision, amount: $amount'
        ')';
  }
}

/// Immutable cash-flow-normalized return earned by prepaying a loan.
@immutable
final class PrepaymentReturnResult {
  factory PrepaymentReturnResult({
    required LoanPrepaymentResult loanPrepayment,
    required Iterable<PrepaymentReturnCashFlow> cashFlows,
    required Percentage monthlyReturn,
    required Percentage effectiveAnnualReturn,
  }) {
    final snapshot = List<PrepaymentReturnCashFlow>.of(cashFlows);
    if (snapshot.length < 2) {
      throw ArgumentError(
        'At least one negative and one positive cash flow are required.',
      );
    }
    final currency = loanPrepayment.baseline.financedPrincipal.currency;
    var hasNegative = false;
    var hasPositive = false;
    var previousMonth = -1;
    for (final cashFlow in snapshot) {
      if (cashFlow.amount.currency != currency) {
        throw ArgumentError(
          'All prepayment return cash flows must use ${currency.code}.',
        );
      }
      if (cashFlow.monthsFromDecision <= previousMonth) {
        throw ArgumentError('Cash flows must be unique and ordered by month.');
      }
      previousMonth = cashFlow.monthsFromDecision;
      hasNegative |= cashFlow.amount.isNegative;
      hasPositive |= cashFlow.amount.isPositive;
    }
    if (!hasNegative || !hasPositive || !snapshot.first.amount.isNegative) {
      throw ArgumentError(
        'Cash flows must start negative and contain a later positive value.',
      );
    }

    return PrepaymentReturnResult._(
      loanPrepayment: loanPrepayment,
      cashFlows: UnmodifiableListView(snapshot),
      monthlyReturn: monthlyReturn,
      effectiveAnnualReturn: effectiveAnnualReturn,
    );
  }

  const PrepaymentReturnResult._({
    required this.loanPrepayment,
    required this.cashFlows,
    required this.monthlyReturn,
    required this.effectiveAnnualReturn,
  });

  final LoanPrepaymentResult loanPrepayment;
  final List<PrepaymentReturnCashFlow> cashFlows;
  final Percentage monthlyReturn;
  final Percentage effectiveAnnualReturn;

  Money get netCashFlowTotal {
    var total = Money.zero(loanPrepayment.baseline.financedPrincipal.currency);
    for (final cashFlow in cashFlows) {
      total += cashFlow.amount;
    }
    return total;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PrepaymentReturnResult &&
            loanPrepayment == other.loanPrepayment &&
            _listsEqual(cashFlows, other.cashFlows) &&
            monthlyReturn == other.monthlyReturn &&
            effectiveAnnualReturn == other.effectiveAnnualReturn;
  }

  @override
  int get hashCode => Object.hash(
    loanPrepayment,
    Object.hashAll(cashFlows),
    monthlyReturn,
    effectiveAnnualReturn,
  );

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'PrepaymentReturnResult('
        'monthlyReturn: $monthlyReturn, '
        'effectiveAnnualReturn: $effectiveAnnualReturn, '
        'netCashFlowTotal: $netCashFlowTotal, '
        'cashFlows: $cashFlows'
        ')';
  }
}
