import 'package:meta/meta.dart';

import '../money/money.dart';

/// Immutable inputs for an actual/365 compound annual growth rate.
@immutable
final class CagrInput {
  factory CagrInput({
    required Money initialValue,
    required Money finalValue,
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
    if (holdingPeriodDays <= 0) {
      throw ArgumentError.value(
        holdingPeriodDays,
        'holdingPeriodDays',
        'Holding period must be greater than zero days.',
      );
    }

    return CagrInput._(
      initialValue: initialValue,
      finalValue: finalValue,
      holdingPeriodDays: holdingPeriodDays,
    );
  }

  const CagrInput._({
    required this.initialValue,
    required this.finalValue,
    required this.holdingPeriodDays,
  });

  final Money initialValue;
  final Money finalValue;
  final int holdingPeriodDays;

  CagrInput copyWith({
    Money? initialValue,
    Money? finalValue,
    int? holdingPeriodDays,
  }) {
    return CagrInput(
      initialValue: initialValue ?? this.initialValue,
      finalValue: finalValue ?? this.finalValue,
      holdingPeriodDays: holdingPeriodDays ?? this.holdingPeriodDays,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CagrInput &&
            initialValue == other.initialValue &&
            finalValue == other.finalValue &&
            holdingPeriodDays == other.holdingPeriodDays;
  }

  @override
  int get hashCode => Object.hash(initialValue, finalValue, holdingPeriodDays);

  @override
  String toString() {
    return 'CagrInput('
        'initialValue: $initialValue, '
        'finalValue: $finalValue, '
        'holdingPeriodDays: $holdingPeriodDays'
        ')';
  }
}
