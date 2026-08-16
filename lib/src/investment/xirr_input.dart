import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'dated_cash_flow.dart';

/// Immutable dated cash flows for a uniquely solvable XIRR calculation.
@immutable
final class XirrInput {
  factory XirrInput({required List<DatedCashFlow> cashFlows}) {
    if (cashFlows.length < 2) {
      throw ArgumentError.value(
        cashFlows,
        'cashFlows',
        'At least two cash flows are required.',
      );
    }

    final sorted = List<DatedCashFlow>.of(cashFlows)
      ..sort((first, second) => first.date.compareTo(second.date));
    final currency = sorted.first.amount.currency;
    for (final cashFlow in sorted) {
      if (cashFlow.amount.currency != currency) {
        throw ArgumentError.value(
          cashFlow,
          'cashFlows',
          'All cash flows must use currency ${currency.code}.',
        );
      }
    }

    final aggregated = <DateTime, Decimal>{};
    for (final cashFlow in sorted) {
      aggregated.update(
        cashFlow.date,
        (amount) => amount + cashFlow.amount.amount,
        ifAbsent: () => cashFlow.amount.amount,
      );
    }
    final nonZeroAmounts =
        aggregated.entries
            .where((entry) => entry.value != Decimal.zero)
            .toList()
          ..sort((first, second) => first.key.compareTo(second.key));
    if (nonZeroAmounts.length < 2 ||
        nonZeroAmounts.first.key == nonZeroAmounts.last.key) {
      throw ArgumentError.value(
        cashFlows,
        'cashFlows',
        'Cash flows must span at least two distinct dates after aggregation.',
      );
    }
    final hasPositive = nonZeroAmounts.any(
      (entry) => entry.value > Decimal.zero,
    );
    final hasNegative = nonZeroAmounts.any(
      (entry) => entry.value < Decimal.zero,
    );
    if (!hasPositive || !hasNegative) {
      throw ArgumentError.value(
        cashFlows,
        'cashFlows',
        'Cash flows must include both contributions and distributions.',
      );
    }

    var signTransitions = 0;
    var previousSign = nonZeroAmounts.first.value.sign;
    for (final entry in nonZeroAmounts.skip(1)) {
      if (entry.value.sign != previousSign) {
        signTransitions++;
        previousSign = entry.value.sign;
      }
    }
    if (signTransitions != 1) {
      throw ArgumentError.value(
        cashFlows,
        'cashFlows',
        'XIRR v1 requires exactly one cash-flow sign transition to ensure '
            'a unique result.',
      );
    }

    return XirrInput._(cashFlows: List<DatedCashFlow>.unmodifiable(sorted));
  }

  const XirrInput._({required this._cashFlows});

  final List<DatedCashFlow> _cashFlows;

  UnmodifiableListView<DatedCashFlow> get cashFlows =>
      UnmodifiableListView<DatedCashFlow>(_cashFlows);

  XirrInput copyWith({List<DatedCashFlow>? cashFlows}) {
    return XirrInput(cashFlows: cashFlows ?? _cashFlows);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! XirrInput || _cashFlows.length != other._cashFlows.length) {
      return false;
    }
    for (var index = 0; index < _cashFlows.length; index++) {
      if (_cashFlows[index] != other._cashFlows[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_cashFlows);

  @override
  String toString() => 'XirrInput(cashFlows: $_cashFlows)';
}
