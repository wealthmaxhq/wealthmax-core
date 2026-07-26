import 'package:meta/meta.dart';

import '../money/money.dart';

/// One immutable installment in a reducing-balance amortization schedule.
@immutable
final class AmortizationEntry {
  factory AmortizationEntry({
    required int installmentNumber,
    required Money openingBalance,
    required Money payment,
    required Money interest,
    required Money principal,
    required Money closingBalance,
  }) {
    if (installmentNumber <= 0) {
      throw ArgumentError.value(
        installmentNumber,
        'installmentNumber',
        'Installment number must be greater than zero.',
      );
    }

    final values = <String, Money>{
      'openingBalance': openingBalance,
      'payment': payment,
      'interest': interest,
      'principal': principal,
      'closingBalance': closingBalance,
    };
    for (final entry in values.entries) {
      if (entry.value.isNegative) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Amount must not be negative.',
        );
      }
      if (entry.value.currency != openingBalance.currency) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Currency must match opening balance currency '
          '${openingBalance.currency.code}.',
        );
      }
    }

    if (payment != interest + principal) {
      throw ArgumentError('Payment must equal interest plus principal.');
    }
    if (openingBalance != principal + closingBalance) {
      throw ArgumentError(
        'Opening balance must equal principal plus closing balance.',
      );
    }

    return AmortizationEntry._(
      installmentNumber: installmentNumber,
      openingBalance: openingBalance,
      payment: payment,
      interest: interest,
      principal: principal,
      closingBalance: closingBalance,
    );
  }

  const AmortizationEntry._({
    required this.installmentNumber,
    required this.openingBalance,
    required this.payment,
    required this.interest,
    required this.principal,
    required this.closingBalance,
  });

  final int installmentNumber;
  final Money openingBalance;
  final Money payment;
  final Money interest;
  final Money principal;
  final Money closingBalance;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AmortizationEntry &&
            installmentNumber == other.installmentNumber &&
            openingBalance == other.openingBalance &&
            payment == other.payment &&
            interest == other.interest &&
            principal == other.principal &&
            closingBalance == other.closingBalance;
  }

  @override
  int get hashCode => Object.hash(
    installmentNumber,
    openingBalance,
    payment,
    interest,
    principal,
    closingBalance,
  );

  @override
  String toString() {
    return 'AmortizationEntry('
        'installmentNumber: $installmentNumber, '
        'openingBalance: $openingBalance, '
        'payment: $payment, '
        'interest: $interest, '
        'principal: $principal, '
        'closingBalance: $closingBalance'
        ')';
  }
}
