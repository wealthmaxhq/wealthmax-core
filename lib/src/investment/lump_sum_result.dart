import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable result of a lump-sum investment projection.
@immutable
final class LumpSumResult {
  factory LumpSumResult({
    required Money initialInvestment,
    required Money futureValue,
    required Percentage cumulativeReturn,
    required int tenureYears,
  }) {
    if (!initialInvestment.isPositive) {
      throw ArgumentError.value(
        initialInvestment,
        'initialInvestment',
        'Initial investment must be greater than zero.',
      );
    }
    if (futureValue.currency != initialInvestment.currency) {
      throw ArgumentError.value(
        futureValue,
        'futureValue',
        'Currency must match initial investment currency '
            '${initialInvestment.currency.code}.',
      );
    }
    if (futureValue.isNegative) {
      throw ArgumentError.value(
        futureValue,
        'futureValue',
        'Future value must not be negative.',
      );
    }
    if (cumulativeReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        cumulativeReturn,
        'cumulativeReturn',
        'Cumulative return must not be less than -100%.',
      );
    }
    if (tenureYears < 0) {
      throw ArgumentError.value(
        tenureYears,
        'tenureYears',
        'Tenure years must not be negative.',
      );
    }

    return LumpSumResult._(
      initialInvestment: initialInvestment,
      futureValue: futureValue,
      cumulativeReturn: cumulativeReturn,
      tenureYears: tenureYears,
    );
  }

  const LumpSumResult._({
    required this.initialInvestment,
    required this.futureValue,
    required this.cumulativeReturn,
    required this.tenureYears,
  });

  final Money initialInvestment;
  final Money futureValue;
  final Percentage cumulativeReturn;
  final int tenureYears;

  Money get totalGain => futureValue - initialInvestment;

  bool get isGain => totalGain.isPositive;
  bool get isLoss => totalGain.isNegative;

  LumpSumResult copyWith({
    Money? initialInvestment,
    Money? futureValue,
    Percentage? cumulativeReturn,
    int? tenureYears,
  }) {
    return LumpSumResult(
      initialInvestment: initialInvestment ?? this.initialInvestment,
      futureValue: futureValue ?? this.futureValue,
      cumulativeReturn: cumulativeReturn ?? this.cumulativeReturn,
      tenureYears: tenureYears ?? this.tenureYears,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LumpSumResult &&
            initialInvestment == other.initialInvestment &&
            futureValue == other.futureValue &&
            cumulativeReturn == other.cumulativeReturn &&
            tenureYears == other.tenureYears;
  }

  @override
  int get hashCode => Object.hash(
    initialInvestment,
    futureValue,
    cumulativeReturn,
    tenureYears,
  );

  @override
  String toString() {
    return 'LumpSumResult('
        'initialInvestment: $initialInvestment, '
        'futureValue: $futureValue, '
        'totalGain: $totalGain, '
        'cumulativeReturn: $cumulativeReturn, '
        'tenureYears: $tenureYears'
        ')';
  }
}
