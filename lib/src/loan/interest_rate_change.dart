import 'dart:collection';

import 'package:meta/meta.dart';

import '../percentage/percentage.dart';

/// A nominal annual interest rate that becomes effective at an installment.
@immutable
final class InterestRateChange {
  factory InterestRateChange({
    required int effectiveInstallment,
    required Percentage annualInterestRate,
  }) {
    if (effectiveInstallment <= 1) {
      throw ArgumentError.value(
        effectiveInstallment,
        'effectiveInstallment',
        'A rate change must become effective after installment one.',
      );
    }
    if (annualInterestRate.isNegative) {
      throw ArgumentError.value(
        annualInterestRate,
        'annualInterestRate',
        'Annual interest rate must not be negative.',
      );
    }

    return InterestRateChange._(
      effectiveInstallment: effectiveInstallment,
      annualInterestRate: annualInterestRate,
    );
  }

  const InterestRateChange._({
    required this.effectiveInstallment,
    required this.annualInterestRate,
  });

  final int effectiveInstallment;
  final Percentage annualInterestRate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InterestRateChange &&
            effectiveInstallment == other.effectiveInstallment &&
            annualInterestRate == other.annualInterestRate;
  }

  @override
  int get hashCode => Object.hash(effectiveInstallment, annualInterestRate);

  @override
  String toString() {
    return 'InterestRateChange('
        'effectiveInstallment: $effectiveInstallment, '
        'annualInterestRate: $annualInterestRate'
        ')';
  }
}

/// Immutable, chronologically ordered floating-rate change plan.
@immutable
final class InterestRatePlan {
  factory InterestRatePlan(Iterable<InterestRateChange> changes) {
    final snapshot = List<InterestRateChange>.of(changes)
      ..sort(
        (first, second) =>
            first.effectiveInstallment.compareTo(second.effectiveInstallment),
      );
    for (var index = 1; index < snapshot.length; index++) {
      if (snapshot[index - 1].effectiveInstallment ==
          snapshot[index].effectiveInstallment) {
        throw ArgumentError(
          'Only one interest rate change is allowed per installment.',
        );
      }
    }

    return InterestRatePlan._(
      UnmodifiableListView<InterestRateChange>(snapshot),
    );
  }

  const InterestRatePlan._(this.changes);

  factory InterestRatePlan.empty() =>
      InterestRatePlan(const <InterestRateChange>[]);

  final List<InterestRateChange> changes;

  bool get isEmpty => changes.isEmpty;

  void validateForTenure(int tenureMonths) {
    for (final change in changes) {
      if (change.effectiveInstallment > tenureMonths) {
        throw ArgumentError.value(
          change.effectiveInstallment,
          'effectiveInstallment',
          'Rate change must not occur after contractual tenure.',
        );
      }
    }
  }

  InterestRateChange? changeAt(int installmentNumber) {
    for (final change in changes) {
      if (change.effectiveInstallment == installmentNumber) return change;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InterestRatePlan && _listsEqual(changes, other.changes);
  }

  @override
  int get hashCode => Object.hashAll(changes);

  static bool _listsEqual(
    List<InterestRateChange> first,
    List<InterestRateChange> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() => 'InterestRatePlan($changes)';
}
