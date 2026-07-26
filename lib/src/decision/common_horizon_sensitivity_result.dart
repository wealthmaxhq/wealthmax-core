import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'common_horizon_break_even_result.dart';
import 'common_horizon_strategy_result.dart';

/// The preferred endpoint at a common future valuation date.
enum CommonHorizonPreference { prepay, invest, equivalent }

/// One deterministic return assumption evaluated at the common horizon.
@immutable
final class CommonHorizonSensitivityPoint {
  factory CommonHorizonSensitivityPoint({
    required Percentage grossAnnualReturn,
    required CommonHorizonStrategyResult comparison,
  }) {
    if (grossAnnualReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        grossAnnualReturn,
        'grossAnnualReturn',
        'Gross annual return must not be less than -100%.',
      );
    }
    if (comparison.scenarios.length != 2) {
      throw ArgumentError(
        'A sensitivity point must contain only all-invest and all-prepay.',
      );
    }
    return CommonHorizonSensitivityPoint._(
      grossAnnualReturn: grossAnnualReturn,
      comparison: comparison,
    );
  }

  const CommonHorizonSensitivityPoint._({
    required this.grossAnnualReturn,
    required this.comparison,
  });

  final Percentage grossAnnualReturn;
  final CommonHorizonStrategyResult comparison;

  Money get futureValueDifference =>
      comparison.allInvestScenario.totalFutureValue -
      comparison.allPrepayScenario.totalFutureValue;

  Money get absoluteAdvantage => futureValueDifference.abs();

  CommonHorizonPreference get preferredOption {
    final sign = futureValueDifference.amount.sign;
    if (sign > 0) return CommonHorizonPreference.invest;
    if (sign < 0) return CommonHorizonPreference.prepay;
    return CommonHorizonPreference.equivalent;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonSensitivityPoint &&
            grossAnnualReturn == other.grossAnnualReturn &&
            comparison == other.comparison;
  }

  @override
  int get hashCode => Object.hash(grossAnnualReturn, comparison);

  @override
  String toString() {
    return 'CommonHorizonSensitivityPoint('
        'grossAnnualReturn: $grossAnnualReturn, '
        'preferredOption: ${preferredOption.name}, '
        'futureValueDifference: $futureValueDifference'
        ')';
  }
}

/// Immutable ordered sensitivity grid using normalized cash-flow timing.
@immutable
final class CommonHorizonSensitivityResult {
  factory CommonHorizonSensitivityResult({
    required CommonHorizonBreakEvenResult breakEven,
    required Percentage annualExpenseRatio,
    required Iterable<CommonHorizonSensitivityPoint> points,
  }) {
    if (annualExpenseRatio.isNegative ||
        annualExpenseRatio.percent >= Decimal.fromInt(100)) {
      throw ArgumentError.value(
        annualExpenseRatio,
        'annualExpenseRatio',
        'Annual expense ratio must be at least 0% and less than 100%.',
      );
    }
    if (breakEven.annualExpenseRatio != annualExpenseRatio) {
      throw ArgumentError(
        'Break-even and sensitivity expense ratios must match.',
      );
    }

    final snapshot = List<CommonHorizonSensitivityPoint>.of(points);
    if (snapshot.isEmpty) {
      throw ArgumentError.value(
        snapshot,
        'points',
        'At least one sensitivity point is required.',
      );
    }

    final currency = breakEven.allInvest.totalFutureValue.currency;
    final commonHorizon = breakEven.comparison.commonHorizonInstallment;
    final feeRetention = Decimal.one - annualExpenseRatio.fraction;
    for (var index = 0; index < snapshot.length; index++) {
      final point = snapshot[index];
      if (index > 0 &&
          snapshot[index - 1].grossAnnualReturn.compareTo(
                point.grossAnnualReturn,
              ) >=
              0) {
        throw ArgumentError(
          'Sensitivity points must have unique ascending return assumptions.',
        );
      }
      if (point.futureValueDifference.currency != currency) {
        throw ArgumentError(
          'All sensitivity points must use ${currency.code}.',
        );
      }
      if (point.comparison.commonHorizonInstallment != commonHorizon) {
        throw ArgumentError(
          'All sensitivity points must use installment $commonHorizon.',
        );
      }
      final expectedNetFraction =
          (Decimal.one + point.grossAnnualReturn.fraction) * feeRetention -
          Decimal.one;
      if (point.comparison.netAnnualInvestmentReturn.fraction !=
          expectedNetFraction) {
        throw ArgumentError(
          'A sensitivity point has an inconsistent net annual return.',
        );
      }
    }

    return CommonHorizonSensitivityResult._(
      breakEven: breakEven,
      annualExpenseRatio: annualExpenseRatio,
      points: UnmodifiableListView(snapshot),
    );
  }

  const CommonHorizonSensitivityResult._({
    required this.breakEven,
    required this.annualExpenseRatio,
    required this.points,
  });

  final CommonHorizonBreakEvenResult breakEven;
  final Percentage annualExpenseRatio;
  final List<CommonHorizonSensitivityPoint> points;

  int get prepayScenarioCount => points
      .where((point) => point.preferredOption == CommonHorizonPreference.prepay)
      .length;

  int get investScenarioCount => points
      .where((point) => point.preferredOption == CommonHorizonPreference.invest)
      .length;

  int get equivalentScenarioCount => points
      .where(
        (point) => point.preferredOption == CommonHorizonPreference.equivalent,
      )
      .length;

  CommonHorizonSensitivityPoint? get firstInvestScenario {
    for (final point in points) {
      if (point.preferredOption == CommonHorizonPreference.invest) {
        return point;
      }
    }
    return null;
  }

  CommonHorizonSensitivityPoint get closestScenarioToBreakEven {
    var closest = points.first;
    var closestDistance =
        (closest.grossAnnualReturn.percent -
                breakEven.breakEvenGrossAnnualReturn.percent)
            .abs();
    for (final point in points.skip(1)) {
      final distance =
          (point.grossAnnualReturn.percent -
                  breakEven.breakEvenGrossAnnualReturn.percent)
              .abs();
      if (distance < closestDistance) {
        closest = point;
        closestDistance = distance;
      }
    }
    return closest;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonSensitivityResult &&
            breakEven == other.breakEven &&
            annualExpenseRatio == other.annualExpenseRatio &&
            _listsEqual(points, other.points);
  }

  @override
  int get hashCode =>
      Object.hash(breakEven, annualExpenseRatio, Object.hashAll(points));

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'CommonHorizonSensitivityResult('
        'breakEvenGrossAnnualReturn: '
        '${breakEven.breakEvenGrossAnnualReturn}, '
        'annualExpenseRatio: $annualExpenseRatio, '
        'points: $points, '
        'prepayScenarioCount: $prepayScenarioCount, '
        'investScenarioCount: $investScenarioCount, '
        'equivalentScenarioCount: $equivalentScenarioCount'
        ')';
  }
}
