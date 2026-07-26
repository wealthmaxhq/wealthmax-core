import 'dart:collection';

import 'package:meta/meta.dart';

import '../currency/currency.dart';
import '../money/money.dart';

/// A replacement EMI that becomes effective at a numbered installment.
@immutable
final class ScheduledEmiChange {
  factory ScheduledEmiChange({
    required int effectiveInstallment,
    required Money newEmi,
  }) {
    if (effectiveInstallment <= 1) {
      throw ArgumentError.value(
        effectiveInstallment,
        'effectiveInstallment',
        'An EMI change must become effective after installment one.',
      );
    }
    if (!newEmi.isPositive) {
      throw ArgumentError.value(
        newEmi,
        'newEmi',
        'New EMI must be greater than zero.',
      );
    }

    return ScheduledEmiChange._(
      effectiveInstallment: effectiveInstallment,
      newEmi: newEmi,
    );
  }

  const ScheduledEmiChange._({
    required this.effectiveInstallment,
    required this.newEmi,
  });

  final int effectiveInstallment;
  final Money newEmi;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ScheduledEmiChange &&
            effectiveInstallment == other.effectiveInstallment &&
            newEmi == other.newEmi;
  }

  @override
  int get hashCode => Object.hash(effectiveInstallment, newEmi);

  @override
  String toString() {
    return 'ScheduledEmiChange('
        'effectiveInstallment: $effectiveInstallment, newEmi: $newEmi'
        ')';
  }
}

/// Immutable, chronological EMI replacement plan.
@immutable
final class EmiChangePlan {
  factory EmiChangePlan(Iterable<ScheduledEmiChange> changes) {
    final snapshot = List<ScheduledEmiChange>.of(changes)
      ..sort(
        (first, second) =>
            first.effectiveInstallment.compareTo(second.effectiveInstallment),
      );
    for (var index = 1; index < snapshot.length; index++) {
      if (snapshot[index - 1].effectiveInstallment ==
          snapshot[index].effectiveInstallment) {
        throw ArgumentError('Only one EMI change is allowed per installment.');
      }
    }
    return EmiChangePlan._(UnmodifiableListView<ScheduledEmiChange>(snapshot));
  }

  const EmiChangePlan._(this.changes);

  factory EmiChangePlan.empty() => EmiChangePlan(const <ScheduledEmiChange>[]);

  final List<ScheduledEmiChange> changes;

  bool get isEmpty => changes.isEmpty;

  ScheduledEmiChange? changeAt(int installmentNumber) {
    for (final change in changes) {
      if (change.effectiveInstallment == installmentNumber) return change;
    }
    return null;
  }

  void validateFor({required Currency currency, required int maxInstallments}) {
    for (final change in changes) {
      if (change.newEmi.currency != currency) {
        throw ArgumentError(
          'Changed EMI currency must match loan currency ${currency.code}.',
        );
      }
      if (change.effectiveInstallment > maxInstallments) {
        throw ArgumentError.value(
          change.effectiveInstallment,
          'effectiveInstallment',
          'EMI change must not occur after the calculation limit.',
        );
      }
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EmiChangePlan && _listsEqual(changes, other.changes);
  }

  @override
  int get hashCode => Object.hashAll(changes);

  static bool _listsEqual(
    List<ScheduledEmiChange> first,
    List<ScheduledEmiChange> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() => 'EmiChangePlan($changes)';
}
