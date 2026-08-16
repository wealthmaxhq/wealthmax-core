import 'dart:collection';

import 'package:meta/meta.dart';

import '../currency/currency.dart';
import '../money/money.dart';

/// An extra principal payment applied after a numbered monthly installment.
@immutable
final class ScheduledPrepayment {
  factory ScheduledPrepayment({
    required int installmentNumber,
    required Money amount,
  }) {
    if (installmentNumber <= 0) {
      throw ArgumentError.value(
        installmentNumber,
        'installmentNumber',
        'Installment number must be greater than zero.',
      );
    }
    if (!amount.isPositive) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Scheduled prepayment must be greater than zero.',
      );
    }

    return ScheduledPrepayment._(
      installmentNumber: installmentNumber,
      amount: amount,
    );
  }

  const ScheduledPrepayment._({
    required this.installmentNumber,
    required this.amount,
  });

  final int installmentNumber;
  final Money amount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ScheduledPrepayment &&
            installmentNumber == other.installmentNumber &&
            amount == other.amount;
  }

  @override
  int get hashCode => Object.hash(installmentNumber, amount);

  @override
  String toString() {
    return 'ScheduledPrepayment('
        'installmentNumber: $installmentNumber, amount: $amount'
        ')';
  }
}

/// Immutable collection of extra principal payments.
@immutable
final class PrepaymentPlan {
  factory PrepaymentPlan(Iterable<ScheduledPrepayment> prepayments) {
    final snapshot = List<ScheduledPrepayment>.of(prepayments)
      ..sort(
        (first, second) =>
            first.installmentNumber.compareTo(second.installmentNumber),
      );
    return PrepaymentPlan._(
      UnmodifiableListView<ScheduledPrepayment>(snapshot),
    );
  }

  const PrepaymentPlan._(this.prepayments);

  factory PrepaymentPlan.empty() =>
      PrepaymentPlan(const <ScheduledPrepayment>[]);

  final List<ScheduledPrepayment> prepayments;

  bool get isEmpty => prepayments.isEmpty;

  Money totalForInstallment(int installmentNumber, Currency currency) {
    var total = Money.zero(currency);
    for (final prepayment in prepayments) {
      if (prepayment.installmentNumber == installmentNumber) {
        if (prepayment.amount.currency != currency) {
          throw ArgumentError(
            'Prepayment currency must match loan currency ${currency.code}.',
          );
        }
        total += prepayment.amount;
      }
    }
    return total;
  }

  Money total(Currency currency) {
    var result = Money.zero(currency);
    for (final prepayment in prepayments) {
      if (prepayment.amount.currency != currency) {
        throw ArgumentError(
          'Prepayment currency must match loan currency ${currency.code}.',
        );
      }
      result += prepayment.amount;
    }
    return result;
  }

  void validateFor({required Currency currency, required int tenureMonths}) {
    for (final prepayment in prepayments) {
      if (prepayment.amount.currency != currency) {
        throw ArgumentError(
          'Prepayment currency must match loan currency ${currency.code}.',
        );
      }
      if (prepayment.installmentNumber > tenureMonths) {
        throw ArgumentError.value(
          prepayment.installmentNumber,
          'installmentNumber',
          'Scheduled prepayment must not occur after loan tenure.',
        );
      }
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PrepaymentPlan && _listsEqual(prepayments, other.prepayments);
  }

  @override
  int get hashCode => Object.hashAll(prepayments);

  static bool _listsEqual(
    List<ScheduledPrepayment> first,
    List<ScheduledPrepayment> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() => 'PrepaymentPlan($prepayments)';
}
