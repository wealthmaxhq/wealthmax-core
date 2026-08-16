import 'package:meta/meta.dart';

import '../money/money.dart';

/// One reconciled monthly period during a loan moratorium.
@immutable
final class MoratoriumEntry {
  factory MoratoriumEntry({
    required int installmentNumber,
    required Money openingBalance,
    required Money interestAccrued,
    required Money payment,
    required Money interestCapitalized,
    required Money closingBalance,
  }) {
    if (installmentNumber <= 0) {
      throw ArgumentError.value(
        installmentNumber,
        'installmentNumber',
        'Installment number must be greater than zero.',
      );
    }
    final amounts = <String, Money>{
      'openingBalance': openingBalance,
      'interestAccrued': interestAccrued,
      'payment': payment,
      'interestCapitalized': interestCapitalized,
      'closingBalance': closingBalance,
    };
    for (final amount in amounts.entries) {
      if (amount.value.isNegative) {
        throw ArgumentError.value(
          amount.value,
          amount.key,
          'Amount must not be negative.',
        );
      }
      if (amount.value.currency != openingBalance.currency) {
        throw ArgumentError.value(
          amount.value,
          amount.key,
          'Currency must match opening balance currency '
          '${openingBalance.currency.code}.',
        );
      }
    }
    if (interestAccrued != payment + interestCapitalized) {
      throw ArgumentError(
        'Accrued interest must equal payment plus capitalized interest.',
      );
    }
    if (closingBalance != openingBalance + interestCapitalized) {
      throw ArgumentError(
        'Closing balance must equal opening balance plus capitalized interest.',
      );
    }

    return MoratoriumEntry._(
      installmentNumber: installmentNumber,
      openingBalance: openingBalance,
      interestAccrued: interestAccrued,
      payment: payment,
      interestCapitalized: interestCapitalized,
      closingBalance: closingBalance,
    );
  }

  const MoratoriumEntry._({
    required this.installmentNumber,
    required this.openingBalance,
    required this.interestAccrued,
    required this.payment,
    required this.interestCapitalized,
    required this.closingBalance,
  });

  final int installmentNumber;
  final Money openingBalance;
  final Money interestAccrued;
  final Money payment;
  final Money interestCapitalized;
  final Money closingBalance;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MoratoriumEntry &&
            installmentNumber == other.installmentNumber &&
            openingBalance == other.openingBalance &&
            interestAccrued == other.interestAccrued &&
            payment == other.payment &&
            interestCapitalized == other.interestCapitalized &&
            closingBalance == other.closingBalance;
  }

  @override
  int get hashCode => Object.hash(
    installmentNumber,
    openingBalance,
    interestAccrued,
    payment,
    interestCapitalized,
    closingBalance,
  );

  @override
  String toString() {
    return 'MoratoriumEntry('
        'installmentNumber: $installmentNumber, '
        'openingBalance: $openingBalance, '
        'interestAccrued: $interestAccrued, '
        'payment: $payment, '
        'interestCapitalized: $interestCapitalized, '
        'closingBalance: $closingBalance'
        ')';
  }
}
