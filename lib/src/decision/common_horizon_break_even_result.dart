import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'common_horizon_strategy_result.dart';

/// Immutable normalized return threshold between all-invest and all-prepay.
@immutable
final class CommonHorizonBreakEvenResult {
  factory CommonHorizonBreakEvenResult({
    required CommonHorizonStrategyResult comparison,
    required Percentage annualExpenseRatio,
    required Percentage breakEvenNetAnnualReturn,
    required Percentage breakEvenGrossAnnualReturn,
  }) {
    if (comparison.scenarios.length != 2) {
      throw ArgumentError(
        'Break-even comparison must contain only 0% and 100% allocations.',
      );
    }
    if (annualExpenseRatio.isNegative ||
        annualExpenseRatio.percent >= Decimal.fromInt(100)) {
      throw ArgumentError.value(
        annualExpenseRatio,
        'annualExpenseRatio',
        'Annual expense ratio must be at least 0% and less than 100%.',
      );
    }
    if (breakEvenGrossAnnualReturn.percent < Decimal.fromInt(-100) ||
        breakEvenNetAnnualReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError('Break-even returns must not be less than -100%.');
    }
    if (comparison.netAnnualInvestmentReturn != breakEvenNetAnnualReturn) {
      throw ArgumentError(
        'The comparison net annual return must equal the break-even net '
        'annual return.',
      );
    }

    final expectedNetFraction =
        (Decimal.one + breakEvenGrossAnnualReturn.fraction) *
            (Decimal.one - annualExpenseRatio.fraction) -
        Decimal.one;
    if (breakEvenNetAnnualReturn.fraction != expectedNetFraction) {
      throw ArgumentError(
        'The break-even net annual return is inconsistent with the gross '
        'annual return and expense ratio.',
      );
    }

    final difference =
        comparison.allInvestScenario.totalFutureValue -
        comparison.allPrepayScenario.totalFutureValue;
    final moneyTolerance = Decimal.one.shift(
      -difference.currency.decimalPlaces,
    );
    if (difference.amount.abs() > moneyTolerance) {
      throw ArgumentError(
        'Break-even endpoint future values must reconcile within one '
        'currency minor unit.',
      );
    }

    return CommonHorizonBreakEvenResult._(
      comparison: comparison,
      annualExpenseRatio: annualExpenseRatio,
      breakEvenNetAnnualReturn: breakEvenNetAnnualReturn,
      breakEvenGrossAnnualReturn: breakEvenGrossAnnualReturn,
    );
  }

  const CommonHorizonBreakEvenResult._({
    required this.comparison,
    required this.annualExpenseRatio,
    required this.breakEvenNetAnnualReturn,
    required this.breakEvenGrossAnnualReturn,
  });

  final CommonHorizonStrategyResult comparison;
  final Percentage annualExpenseRatio;
  final Percentage breakEvenNetAnnualReturn;
  final Percentage breakEvenGrossAnnualReturn;

  CommonHorizonScenario get allInvest => comparison.allInvestScenario;
  CommonHorizonScenario get allPrepay => comparison.allPrepayScenario;

  /// Positive means all-invest is ahead at the returned threshold.
  Money get futureValueDifference =>
      allInvest.totalFutureValue - allPrepay.totalFutureValue;

  Money get absoluteFutureValueDifference => futureValueDifference.abs();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonBreakEvenResult &&
            comparison == other.comparison &&
            annualExpenseRatio == other.annualExpenseRatio &&
            breakEvenNetAnnualReturn == other.breakEvenNetAnnualReturn &&
            breakEvenGrossAnnualReturn == other.breakEvenGrossAnnualReturn;
  }

  @override
  int get hashCode => Object.hash(
    comparison,
    annualExpenseRatio,
    breakEvenNetAnnualReturn,
    breakEvenGrossAnnualReturn,
  );

  @override
  String toString() {
    return 'CommonHorizonBreakEvenResult('
        'annualExpenseRatio: $annualExpenseRatio, '
        'breakEvenNetAnnualReturn: $breakEvenNetAnnualReturn, '
        'breakEvenGrossAnnualReturn: $breakEvenGrossAnnualReturn, '
        'allInvestFutureValue: ${allInvest.totalFutureValue}, '
        'allPrepayFutureValue: ${allPrepay.totalFutureValue}, '
        'futureValueDifference: $futureValueDifference, '
        'commonHorizonInstallment: ${comparison.commonHorizonInstallment}'
        ')';
  }
}
