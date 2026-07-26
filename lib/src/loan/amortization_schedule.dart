import 'dart:collection';

import 'package:meta/meta.dart';

import '../money/money.dart';
import 'amortization_entry.dart';

/// Immutable, fully reconciled sequence of loan installments.
@immutable
final class AmortizationSchedule {
  factory AmortizationSchedule({
    required Money scheduledEmi,
    required Money financedPrincipal,
    required List<AmortizationEntry> entries,
  }) {
    if (scheduledEmi.isNegative) {
      throw ArgumentError.value(
        scheduledEmi,
        'scheduledEmi',
        'Scheduled EMI must not be negative.',
      );
    }
    if (financedPrincipal.isNegative) {
      throw ArgumentError.value(
        financedPrincipal,
        'financedPrincipal',
        'Financed principal must not be negative.',
      );
    }
    if (scheduledEmi.currency != financedPrincipal.currency) {
      throw ArgumentError(
        'Scheduled EMI and financed principal currencies must match.',
      );
    }

    final snapshot = List<AmortizationEntry>.of(entries);
    _validateEntries(snapshot, financedPrincipal: financedPrincipal);

    return AmortizationSchedule._(
      scheduledEmi: scheduledEmi,
      financedPrincipal: financedPrincipal,
      entries: UnmodifiableListView<AmortizationEntry>(snapshot),
    );
  }

  const AmortizationSchedule._({
    required this.scheduledEmi,
    required this.financedPrincipal,
    required this.entries,
  });

  final Money scheduledEmi;
  final Money financedPrincipal;
  final List<AmortizationEntry> entries;

  int get paymentCount => entries.length;

  Money get totalInterest => _sum((entry) => entry.interest);

  Money get totalPrincipal => _sum((entry) => entry.principal);

  Money get totalPayment => _sum((entry) => entry.payment);

  Money get closingBalance =>
      entries.isEmpty ? financedPrincipal : entries.last.closingBalance;

  Money? get finalPayment => entries.isEmpty ? null : entries.last.payment;

  Money _sum(Money Function(AmortizationEntry entry) select) {
    var result = Money.zero(financedPrincipal.currency);
    for (final entry in entries) {
      result += select(entry);
    }
    return result;
  }

  static void _validateEntries(
    List<AmortizationEntry> entries, {
    required Money financedPrincipal,
  }) {
    if (financedPrincipal.isZero && entries.isNotEmpty) {
      throw ArgumentError(
        'A zero financed principal must have an empty schedule.',
      );
    }
    if (financedPrincipal.isPositive && entries.isEmpty) {
      throw ArgumentError(
        'A positive financed principal must have schedule entries.',
      );
    }

    var expectedOpening = financedPrincipal;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry.installmentNumber != index + 1) {
        throw ArgumentError(
          'Installment numbers must be consecutive and start at one.',
        );
      }
      if (entry.openingBalance.currency != financedPrincipal.currency) {
        throw ArgumentError(
          'Every entry must use financed principal currency '
          '${financedPrincipal.currency.code}.',
        );
      }
      if (entry.openingBalance != expectedOpening) {
        throw ArgumentError(
          'Each opening balance must equal the previous closing balance.',
        );
      }
      expectedOpening = entry.closingBalance;
    }

    if (entries.isNotEmpty && !entries.last.closingBalance.isZero) {
      throw ArgumentError('The final closing balance must be zero.');
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AmortizationSchedule &&
            scheduledEmi == other.scheduledEmi &&
            financedPrincipal == other.financedPrincipal &&
            _listsEqual(entries, other.entries);
  }

  @override
  int get hashCode =>
      Object.hash(scheduledEmi, financedPrincipal, Object.hashAll(entries));

  static bool _listsEqual(
    List<AmortizationEntry> first,
    List<AmortizationEntry> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'AmortizationSchedule('
        'scheduledEmi: $scheduledEmi, '
        'financedPrincipal: $financedPrincipal, '
        'paymentCount: $paymentCount, '
        'totalInterest: $totalInterest, '
        'totalPayment: $totalPayment, '
        'closingBalance: $closingBalance'
        ')';
  }
}
