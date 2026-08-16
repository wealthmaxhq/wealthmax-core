import 'package:meta/meta.dart';

import '../money/money.dart';

/// One signed investment cash flow on a calendar date.
///
/// Contributions are negative and distributions or terminal values are
/// positive. Time-of-day and time-zone components are discarded.
@immutable
final class DatedCashFlow {
  factory DatedCashFlow({required DateTime date, required Money amount}) {
    if (amount.isZero) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Cash-flow amount must not be zero.',
      );
    }
    return DatedCashFlow._(
      date: DateTime.utc(date.year, date.month, date.day),
      amount: amount,
    );
  }

  const DatedCashFlow._({required this.date, required this.amount});

  final DateTime date;
  final Money amount;

  bool get isContribution => amount.isNegative;
  bool get isDistribution => amount.isPositive;

  DatedCashFlow copyWith({DateTime? date, Money? amount}) {
    return DatedCashFlow(
      date: date ?? this.date,
      amount: amount ?? this.amount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DatedCashFlow && date == other.date && amount == other.amount;
  }

  @override
  int get hashCode => Object.hash(date, amount);

  @override
  String toString() {
    final dateText = date.toIso8601String().substring(0, 10);
    return 'DatedCashFlow(date: $dateText, amount: $amount)';
  }
}
