import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../currency/currency.dart';

@immutable
final class Money implements Comparable<Money> {
  const Money._({required this.amount, required this.currency});

  factory Money({required Decimal amount, required Currency currency}) {
    return Money._(amount: amount, currency: currency);
  }

  factory Money.parse(String amount, {required Currency currency}) {
    return Money(amount: Decimal.parse(amount), currency: currency);
  }

  factory Money.zero(Currency currency) {
    return Money(amount: Decimal.zero, currency: currency);
  }

  final Decimal amount;
  final Currency currency;

  bool get isZero => amount == Decimal.zero;

  bool get isPositive => amount > Decimal.zero;

  bool get isNegative => amount < Decimal.zero;

  Money operator +(Money other) {
    _ensureSameCurrency(other, operation: 'add');

    return Money(amount: amount + other.amount, currency: currency);
  }

  Money operator -(Money other) {
    _ensureSameCurrency(other, operation: 'subtract');

    return Money(amount: amount - other.amount, currency: currency);
  }

  Money operator *(Decimal factor) =>
      Money(amount: amount * factor, currency: currency);

  Money multiply(Decimal factor) => this * factor;

  Money negate() => Money(amount: -amount, currency: currency);

  Money abs() => isNegative ? negate() : this;

  @override
  int compareTo(Money other) {
    _ensureSameCurrency(other, operation: 'compare');
    return amount.compareTo(other.amount);
  }

  void _ensureSameCurrency(Money other, {required String operation}) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Cannot $operation money in ${currency.code} and '
        '${other.currency.code}; currencies must match.',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Money && amount == other.amount && currency == other.currency;
  }

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => '${currency.code} $amount';
}
