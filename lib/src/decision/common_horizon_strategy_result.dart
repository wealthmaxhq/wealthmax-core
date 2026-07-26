import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'hybrid_strategy_result.dart';

/// One future loan-payment saving reinvested to the common horizon.
@immutable
final class CommonHorizonCashFlow {
  factory CommonHorizonCashFlow({
    required int installmentNumber,
    required int growthMonths,
    required Money paymentSaving,
    required Money futureValue,
  }) {
    if (installmentNumber <= 0) {
      throw ArgumentError.value(
        installmentNumber,
        'installmentNumber',
        'Installment number must be greater than zero.',
      );
    }
    if (growthMonths < 0) {
      throw ArgumentError.value(
        growthMonths,
        'growthMonths',
        'Growth months must not be negative.',
      );
    }
    if (!paymentSaving.isPositive) {
      throw ArgumentError.value(
        paymentSaving,
        'paymentSaving',
        'Payment saving must be greater than zero.',
      );
    }
    if (futureValue.currency != paymentSaving.currency ||
        futureValue.isNegative) {
      throw ArgumentError(
        'Future value must be non-negative and use '
        '${paymentSaving.currency.code}.',
      );
    }
    return CommonHorizonCashFlow._(
      installmentNumber: installmentNumber,
      growthMonths: growthMonths,
      paymentSaving: paymentSaving,
      futureValue: futureValue,
    );
  }

  const CommonHorizonCashFlow._({
    required this.installmentNumber,
    required this.growthMonths,
    required this.paymentSaving,
    required this.futureValue,
  });

  final int installmentNumber;
  final int growthMonths;
  final Money paymentSaving;
  final Money futureValue;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonCashFlow &&
            installmentNumber == other.installmentNumber &&
            growthMonths == other.growthMonths &&
            paymentSaving == other.paymentSaving &&
            futureValue == other.futureValue;
  }

  @override
  int get hashCode =>
      Object.hash(installmentNumber, growthMonths, paymentSaving, futureValue);

  @override
  String toString() {
    return 'CommonHorizonCashFlow('
        'installmentNumber: $installmentNumber, '
        'growthMonths: $growthMonths, '
        'paymentSaving: $paymentSaving, '
        'futureValue: $futureValue'
        ')';
  }
}

/// One allocation valued at the baseline loan payoff horizon.
@immutable
final class CommonHorizonScenario {
  factory CommonHorizonScenario({
    required HybridStrategyScenario allocation,
    required Iterable<CommonHorizonCashFlow> reinvestedPaymentSavings,
    required Money futureValueOfPaymentSavings,
  }) {
    final snapshot = List<CommonHorizonCashFlow>.of(reinvestedPaymentSavings);
    final currency = allocation.availableCash.currency;
    var expectedFutureValue = Money.zero(currency);
    var previousInstallment = 0;
    for (final cashFlow in snapshot) {
      if (cashFlow.paymentSaving.currency != currency ||
          cashFlow.futureValue.currency != currency) {
        throw ArgumentError(
          'All common-horizon cash flows must use ${currency.code}.',
        );
      }
      if (cashFlow.installmentNumber <= previousInstallment) {
        throw ArgumentError(
          'Payment-saving cash flows must be ordered by installment.',
        );
      }
      previousInstallment = cashFlow.installmentNumber;
      expectedFutureValue += cashFlow.futureValue;
    }
    if (futureValueOfPaymentSavings.currency != currency ||
        futureValueOfPaymentSavings != expectedFutureValue) {
      throw ArgumentError(
        'Future value of payment savings must equal the cash-flow sum.',
      );
    }

    return CommonHorizonScenario._(
      allocation: allocation,
      reinvestedPaymentSavings: UnmodifiableListView(snapshot),
      futureValueOfPaymentSavings: futureValueOfPaymentSavings,
    );
  }

  const CommonHorizonScenario._({
    required this.allocation,
    required this.reinvestedPaymentSavings,
    required this.futureValueOfPaymentSavings,
  });

  final HybridStrategyScenario allocation;
  final List<CommonHorizonCashFlow> reinvestedPaymentSavings;
  final Money futureValueOfPaymentSavings;

  Percentage get requestedPrepaymentAllocation =>
      allocation.requestedPrepaymentAllocation;
  Money get initialInvestmentFutureValue => allocation.investmentFutureValue;
  Money get totalFutureValue =>
      initialInvestmentFutureValue + futureValueOfPaymentSavings;
  Money get futureWealthGain => totalFutureValue - allocation.availableCash;

  Money get nominalPaymentSavings {
    var total = Money.zero(allocation.availableCash.currency);
    for (final cashFlow in reinvestedPaymentSavings) {
      total += cashFlow.paymentSaving;
    }
    return total;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonScenario &&
            allocation == other.allocation &&
            _listsEqual(
              reinvestedPaymentSavings,
              other.reinvestedPaymentSavings,
            ) &&
            futureValueOfPaymentSavings == other.futureValueOfPaymentSavings;
  }

  @override
  int get hashCode => Object.hash(
    allocation,
    Object.hashAll(reinvestedPaymentSavings),
    futureValueOfPaymentSavings,
  );

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'CommonHorizonScenario('
        'requestedPrepaymentAllocation: $requestedPrepaymentAllocation, '
        'initialInvestmentFutureValue: $initialInvestmentFutureValue, '
        'futureValueOfPaymentSavings: $futureValueOfPaymentSavings, '
        'totalFutureValue: $totalFutureValue, '
        'futureWealthGain: $futureWealthGain'
        ')';
  }
}

/// Immutable allocation grid normalized to one future valuation date.
@immutable
final class CommonHorizonStrategyResult {
  factory CommonHorizonStrategyResult({
    required Iterable<CommonHorizonScenario> scenarios,
    required Percentage netAnnualInvestmentReturn,
    required int commonHorizonInstallment,
  }) {
    final snapshot = List<CommonHorizonScenario>.of(scenarios);
    if (snapshot.length < 2) {
      throw ArgumentError('At least the 0% and 100% endpoints are required.');
    }
    if (commonHorizonInstallment <= 0) {
      throw ArgumentError.value(
        commonHorizonInstallment,
        'commonHorizonInstallment',
        'Common horizon installment must be greater than zero.',
      );
    }
    final currency = snapshot.first.allocation.availableCash.currency;
    for (var index = 0; index < snapshot.length; index++) {
      final scenario = snapshot[index];
      if (scenario.allocation.availableCash.currency != currency) {
        throw ArgumentError(
          'All common-horizon scenarios must use ${currency.code}.',
        );
      }
      if (index > 0 &&
          snapshot[index - 1].requestedPrepaymentAllocation.compareTo(
                scenario.requestedPrepaymentAllocation,
              ) >=
              0) {
        throw ArgumentError(
          'Scenarios must have unique ascending prepayment allocations.',
        );
      }
    }
    if (!snapshot.first.requestedPrepaymentAllocation.isZero ||
        snapshot.last.requestedPrepaymentAllocation.percent != _oneHundred) {
      throw ArgumentError('Scenarios must include 0% and 100% allocations.');
    }

    var bestIndex = 0;
    for (var index = 1; index < snapshot.length; index++) {
      final futureValueComparison = snapshot[index].totalFutureValue.compareTo(
        snapshot[bestIndex].totalFutureValue,
      );
      if (futureValueComparison > 0 ||
          (futureValueComparison == 0 &&
              snapshot[index].allocation.investedAmount.compareTo(
                    snapshot[bestIndex].allocation.investedAmount,
                  ) >
                  0)) {
        bestIndex = index;
      }
    }

    return CommonHorizonStrategyResult._(
      scenarios: UnmodifiableListView(snapshot),
      bestScenarioIndex: bestIndex,
      netAnnualInvestmentReturn: netAnnualInvestmentReturn,
      commonHorizonInstallment: commonHorizonInstallment,
    );
  }

  const CommonHorizonStrategyResult._({
    required this.scenarios,
    required this.bestScenarioIndex,
    required this.netAnnualInvestmentReturn,
    required this.commonHorizonInstallment,
  });

  final List<CommonHorizonScenario> scenarios;
  final int bestScenarioIndex;
  final Percentage netAnnualInvestmentReturn;
  final int commonHorizonInstallment;

  CommonHorizonScenario get bestScenario => scenarios[bestScenarioIndex];
  CommonHorizonScenario get allInvestScenario => scenarios.first;
  CommonHorizonScenario get allPrepayScenario => scenarios.last;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonStrategyResult &&
            _listsEqual(scenarios, other.scenarios) &&
            bestScenarioIndex == other.bestScenarioIndex &&
            netAnnualInvestmentReturn == other.netAnnualInvestmentReturn &&
            commonHorizonInstallment == other.commonHorizonInstallment;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(scenarios),
    bestScenarioIndex,
    netAnnualInvestmentReturn,
    commonHorizonInstallment,
  );

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'CommonHorizonStrategyResult('
        'commonHorizonInstallment: $commonHorizonInstallment, '
        'netAnnualInvestmentReturn: $netAnnualInvestmentReturn, '
        'bestScenarioIndex: $bestScenarioIndex, '
        'bestScenario: $bestScenario, '
        'scenarios: $scenarios'
        ')';
  }
}

final Decimal _oneHundred = Decimal.fromInt(100);
