import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable result of an actual/365 CAGR calculation.
@immutable
final class CagrResult {
  factory CagrResult({
    required Money initialValue,
    required Money finalValue,
    required Percentage totalReturn,
    required Percentage annualizedReturn,
    required int holdingPeriodDays,
  }) {
    if (!initialValue.isPositive) {
      throw ArgumentError.value(
        initialValue,
        'initialValue',
        'Initial value must be greater than zero.',
      );
    }
    if (finalValue.isNegative) {
      throw ArgumentError.value(
        finalValue,
        'finalValue',
        'Final value must not be negative.',
      );
    }
    if (finalValue.currency != initialValue.currency) {
      throw ArgumentError.value(
        finalValue,
        'finalValue',
        'Currency must match initial value currency '
            '${initialValue.currency.code}.',
      );
    }
    if (totalReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        totalReturn,
        'totalReturn',
        'Total return must not be less than -100%.',
      );
    }
    if (annualizedReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        annualizedReturn,
        'annualizedReturn',
        'Annualized return must not be less than -100%.',
      );
    }
    if (holdingPeriodDays <= 0) {
      throw ArgumentError.value(
        holdingPeriodDays,
        'holdingPeriodDays',
        'Holding period must be greater than zero days.',
      );
    }

    return CagrResult._(
      initialValue: initialValue,
      finalValue: finalValue,
      totalReturn: totalReturn,
      annualizedReturn: annualizedReturn,
      holdingPeriodDays: holdingPeriodDays,
    );
  }

  const CagrResult._({
    required this.initialValue,
    required this.finalValue,
    required this.totalReturn,
    required this.annualizedReturn,
    required this.holdingPeriodDays,
  });

  final Money initialValue;
  final Money finalValue;
  final Percentage totalReturn;
  final Percentage annualizedReturn;
  final int holdingPeriodDays;

  Money get absoluteGain => finalValue - initialValue;
  bool get isGain => absoluteGain.isPositive;
  bool get isLoss => absoluteGain.isNegative;

  CagrResult copyWith({
    Money? initialValue,
    Money? finalValue,
    Percentage? totalReturn,
    Percentage? annualizedReturn,
    int? holdingPeriodDays,
  }) {
    return CagrResult(
      initialValue: initialValue ?? this.initialValue,
      finalValue: finalValue ?? this.finalValue,
      totalReturn: totalReturn ?? this.totalReturn,
      annualizedReturn: annualizedReturn ?? this.annualizedReturn,
      holdingPeriodDays: holdingPeriodDays ?? this.holdingPeriodDays,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CagrResult &&
            initialValue == other.initialValue &&
            finalValue == other.finalValue &&
            totalReturn == other.totalReturn &&
            annualizedReturn == other.annualizedReturn &&
            holdingPeriodDays == other.holdingPeriodDays;
  }

  @override
  int get hashCode => Object.hash(
    initialValue,
    finalValue,
    totalReturn,
    annualizedReturn,
    holdingPeriodDays,
  );

  @override
  String toString() {
    return 'CagrResult('
        'initialValue: $initialValue, '
        'finalValue: $finalValue, '
        'absoluteGain: $absoluteGain, '
        'totalReturn: $totalReturn, '
        'annualizedReturn: $annualizedReturn, '
        'holdingPeriodDays: $holdingPeriodDays'
        ')';
  }
}
