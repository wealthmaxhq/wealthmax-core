import 'dart:collection';

import 'package:meta/meta.dart';

import '../money/money.dart';
import 'amortization_schedule.dart';
import 'moratorium_entry.dart';
import 'moratorium_plan.dart';

/// Immutable comparison of a loan with and without a moratorium.
@immutable
final class MoratoriumResult {
  factory MoratoriumResult({
    required MoratoriumPlan plan,
    required List<MoratoriumEntry> moratoriumEntries,
    required AmortizationSchedule baselineSchedule,
    required AmortizationSchedule repaymentSchedule,
  }) {
    final entries = List<MoratoriumEntry>.of(moratoriumEntries);
    if (entries.length != plan.months) {
      throw ArgumentError(
        'Moratorium entry count must equal configured moratorium months.',
      );
    }
    var expectedOpening = baselineSchedule.financedPrincipal;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry.installmentNumber != index + 1) {
        throw ArgumentError(
          'Moratorium installment numbers must be consecutive.',
        );
      }
      if (entry.openingBalance != expectedOpening) {
        throw ArgumentError(
          'Each moratorium opening balance must match the previous closing '
          'balance.',
        );
      }
      expectedOpening = entry.closingBalance;
    }
    if (repaymentSchedule.financedPrincipal != expectedOpening) {
      throw ArgumentError(
        'Repayment principal must equal the post-moratorium balance.',
      );
    }

    return MoratoriumResult._(
      plan: plan,
      moratoriumEntries: UnmodifiableListView<MoratoriumEntry>(entries),
      baselineSchedule: baselineSchedule,
      repaymentSchedule: repaymentSchedule,
    );
  }

  const MoratoriumResult._({
    required this.plan,
    required this.moratoriumEntries,
    required this.baselineSchedule,
    required this.repaymentSchedule,
  });

  final MoratoriumPlan plan;
  final List<MoratoriumEntry> moratoriumEntries;
  final AmortizationSchedule baselineSchedule;
  final AmortizationSchedule repaymentSchedule;

  Money get balanceAfterMoratorium => repaymentSchedule.financedPrincipal;

  Money get totalMoratoriumInterest =>
      _sumMoratorium((entry) => entry.interestAccrued);

  Money get totalMoratoriumPayments => _sumMoratorium((entry) => entry.payment);

  Money get totalCapitalizedInterest =>
      _sumMoratorium((entry) => entry.interestCapitalized);

  Money get postMoratoriumEmi => repaymentSchedule.scheduledEmi;

  Money get totalInterest =>
      totalMoratoriumInterest + repaymentSchedule.totalInterest;

  Money get totalPayment =>
      totalMoratoriumPayments + repaymentSchedule.totalPayment;

  Money get additionalInterest =>
      totalInterest - baselineSchedule.totalInterest;

  int get totalElapsedMonths => plan.months + repaymentSchedule.paymentCount;

  int get tenureChangeMonths =>
      totalElapsedMonths - baselineSchedule.paymentCount;

  Money _sumMoratorium(Money Function(MoratoriumEntry entry) select) {
    var total = Money.zero(baselineSchedule.financedPrincipal.currency);
    for (final entry in moratoriumEntries) {
      total += select(entry);
    }
    return total;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MoratoriumResult &&
            plan == other.plan &&
            _listsEqual(moratoriumEntries, other.moratoriumEntries) &&
            baselineSchedule == other.baselineSchedule &&
            repaymentSchedule == other.repaymentSchedule;
  }

  @override
  int get hashCode => Object.hash(
    plan,
    Object.hashAll(moratoriumEntries),
    baselineSchedule,
    repaymentSchedule,
  );

  static bool _listsEqual(
    List<MoratoriumEntry> first,
    List<MoratoriumEntry> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'MoratoriumResult('
        'plan: $plan, '
        'moratoriumEntryCount: ${moratoriumEntries.length}, '
        'balanceAfterMoratorium: $balanceAfterMoratorium, '
        'postMoratoriumEmi: $postMoratoriumEmi, '
        'totalMoratoriumInterest: $totalMoratoriumInterest, '
        'totalCapitalizedInterest: $totalCapitalizedInterest, '
        'totalInterest: $totalInterest, '
        'additionalInterest: $additionalInterest, '
        'totalElapsedMonths: $totalElapsedMonths'
        ')';
  }
}
