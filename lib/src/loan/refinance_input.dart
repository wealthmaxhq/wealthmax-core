import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable assumptions for comparing an existing loan with refinancing.
@immutable
final class RefinanceInput {
  factory RefinanceInput({
    required Money outstandingPrincipal,
    required Percentage currentAnnualInterestRate,
    required int remainingMonths,
    required Percentage newAnnualInterestRate,
    required int newTenureMonths,
    Money? refinancingFees,
  }) {
    if (!outstandingPrincipal.isPositive) {
      throw ArgumentError.value(
        outstandingPrincipal,
        'outstandingPrincipal',
        'Outstanding principal must be greater than zero.',
      );
    }
    _requireNonNegativeRate(
      currentAnnualInterestRate,
      'currentAnnualInterestRate',
    );
    _requireNonNegativeRate(newAnnualInterestRate, 'newAnnualInterestRate');
    if (remainingMonths <= 0) {
      throw ArgumentError.value(
        remainingMonths,
        'remainingMonths',
        'Remaining tenure must be greater than zero.',
      );
    }
    if (newTenureMonths <= 0) {
      throw ArgumentError.value(
        newTenureMonths,
        'newTenureMonths',
        'New tenure must be greater than zero.',
      );
    }

    final fees = refinancingFees ?? Money.zero(outstandingPrincipal.currency);
    if (fees.currency != outstandingPrincipal.currency) {
      throw ArgumentError.value(
        fees,
        'refinancingFees',
        'Refinancing fee currency must match outstanding principal.',
      );
    }
    if (fees.isNegative) {
      throw ArgumentError.value(
        fees,
        'refinancingFees',
        'Refinancing fees must not be negative.',
      );
    }

    return RefinanceInput._(
      outstandingPrincipal: outstandingPrincipal,
      currentAnnualInterestRate: currentAnnualInterestRate,
      remainingMonths: remainingMonths,
      newAnnualInterestRate: newAnnualInterestRate,
      newTenureMonths: newTenureMonths,
      refinancingFees: fees,
    );
  }

  const RefinanceInput._({
    required this.outstandingPrincipal,
    required this.currentAnnualInterestRate,
    required this.remainingMonths,
    required this.newAnnualInterestRate,
    required this.newTenureMonths,
    required this.refinancingFees,
  });

  final Money outstandingPrincipal;
  final Percentage currentAnnualInterestRate;
  final int remainingMonths;
  final Percentage newAnnualInterestRate;
  final int newTenureMonths;
  final Money refinancingFees;

  static void _requireNonNegativeRate(Percentage rate, String fieldName) {
    if (rate.isNegative) {
      throw ArgumentError.value(
        rate,
        fieldName,
        'Annual interest rate must not be negative.',
      );
    }
  }

  RefinanceInput copyWith({
    Money? outstandingPrincipal,
    Percentage? currentAnnualInterestRate,
    int? remainingMonths,
    Percentage? newAnnualInterestRate,
    int? newTenureMonths,
    Money? refinancingFees,
  }) {
    return RefinanceInput(
      outstandingPrincipal: outstandingPrincipal ?? this.outstandingPrincipal,
      currentAnnualInterestRate:
          currentAnnualInterestRate ?? this.currentAnnualInterestRate,
      remainingMonths: remainingMonths ?? this.remainingMonths,
      newAnnualInterestRate:
          newAnnualInterestRate ?? this.newAnnualInterestRate,
      newTenureMonths: newTenureMonths ?? this.newTenureMonths,
      refinancingFees: refinancingFees ?? this.refinancingFees,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RefinanceInput &&
            outstandingPrincipal == other.outstandingPrincipal &&
            currentAnnualInterestRate == other.currentAnnualInterestRate &&
            remainingMonths == other.remainingMonths &&
            newAnnualInterestRate == other.newAnnualInterestRate &&
            newTenureMonths == other.newTenureMonths &&
            refinancingFees == other.refinancingFees;
  }

  @override
  int get hashCode => Object.hash(
    outstandingPrincipal,
    currentAnnualInterestRate,
    remainingMonths,
    newAnnualInterestRate,
    newTenureMonths,
    refinancingFees,
  );

  @override
  String toString() {
    return 'RefinanceInput('
        'outstandingPrincipal: $outstandingPrincipal, '
        'currentAnnualInterestRate: $currentAnnualInterestRate, '
        'remainingMonths: $remainingMonths, '
        'newAnnualInterestRate: $newAnnualInterestRate, '
        'newTenureMonths: $newTenureMonths, '
        'refinancingFees: $refinancingFees'
        ')';
  }
}
