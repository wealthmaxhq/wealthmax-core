import 'dart:collection';

import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'break_even_return_result.dart';
import 'opportunity_cost_result.dart';

/// One evaluated return assumption in a sensitivity grid.
@immutable
final class ReturnSensitivityPoint {
  const ReturnSensitivityPoint({
    required this.grossAnnualReturn,
    required this.comparison,
  });

  final Percentage grossAnnualReturn;
  final OpportunityCostResult comparison;

  OpportunityCostPreference get preferredOption => comparison.preferredOption;
  Money get nominalAdvantage => comparison.nominalAdvantage;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReturnSensitivityPoint &&
            grossAnnualReturn == other.grossAnnualReturn &&
            comparison == other.comparison;
  }

  @override
  int get hashCode => Object.hash(grossAnnualReturn, comparison);

  @override
  String toString() {
    return 'ReturnSensitivityPoint('
        'grossAnnualReturn: $grossAnnualReturn, '
        'preferredOption: ${preferredOption.name}, '
        'nominalAdvantage: $nominalAdvantage'
        ')';
  }
}

/// Immutable multi-scenario decision sensitivity result.
@immutable
final class ReturnSensitivityResult {
  factory ReturnSensitivityResult({
    required BreakEvenReturnResult breakEven,
    required Iterable<ReturnSensitivityPoint> points,
  }) {
    final snapshot = List<ReturnSensitivityPoint>.of(points);
    if (snapshot.isEmpty) {
      throw ArgumentError.value(
        snapshot,
        'points',
        'At least one sensitivity point is required.',
      );
    }
    for (var index = 1; index < snapshot.length; index++) {
      if (snapshot[index - 1].grossAnnualReturn.compareTo(
            snapshot[index].grossAnnualReturn,
          ) >=
          0) {
        throw ArgumentError(
          'Sensitivity points must have unique ascending return assumptions.',
        );
      }
    }
    final currency = breakEven.investedAmount.currency;
    for (final point in snapshot) {
      if (point.comparison.investedAmount.currency != currency) {
        throw ArgumentError(
          'All sensitivity point currencies must match ${currency.code}.',
        );
      }
    }

    return ReturnSensitivityResult._(
      breakEven: breakEven,
      points: UnmodifiableListView(snapshot),
    );
  }

  const ReturnSensitivityResult._({
    required this.breakEven,
    required this.points,
  });

  final BreakEvenReturnResult breakEven;
  final List<ReturnSensitivityPoint> points;

  int get prepayScenarioCount => points
      .where(
        (point) => point.preferredOption == OpportunityCostPreference.prepay,
      )
      .length;

  int get investScenarioCount => points
      .where(
        (point) => point.preferredOption == OpportunityCostPreference.invest,
      )
      .length;

  int get equivalentScenarioCount => points
      .where(
        (point) =>
            point.preferredOption == OpportunityCostPreference.equivalent,
      )
      .length;

  ReturnSensitivityPoint? get firstInvestScenario {
    for (final point in points) {
      if (point.preferredOption == OpportunityCostPreference.invest) {
        return point;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReturnSensitivityResult &&
            breakEven == other.breakEven &&
            _listsEqual(points, other.points);
  }

  @override
  int get hashCode => Object.hash(breakEven, Object.hashAll(points));

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'ReturnSensitivityResult('
        'breakEvenGrossAnnualReturn: '
        '${breakEven.breakEvenGrossAnnualReturn}, '
        'points: $points, '
        'prepayScenarioCount: $prepayScenarioCount, '
        'investScenarioCount: $investScenarioCount, '
        'equivalentScenarioCount: $equivalentScenarioCount'
        ')';
  }
}
