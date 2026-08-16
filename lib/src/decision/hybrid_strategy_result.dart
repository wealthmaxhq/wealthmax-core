import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../loan/loan_prepayment_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';

/// One evaluated split of available cash between prepayment and investment.
@immutable
final class HybridStrategyScenario {
  factory HybridStrategyScenario({
    required Percentage requestedPrepaymentAllocation,
    required Money availableCash,
    required Money requestedPrepayment,
    required LoanPrepaymentResult loanPrepayment,
    required Money investedAmount,
    required Money investmentFutureValue,
    required int investmentHorizonMonths,
  }) {
    if (requestedPrepaymentAllocation.isNegative ||
        requestedPrepaymentAllocation.percent.compareTo(_oneHundred) > 0) {
      throw ArgumentError.value(
        requestedPrepaymentAllocation,
        'requestedPrepaymentAllocation',
        'Prepayment allocation must be between 0% and 100%.',
      );
    }
    final currency = availableCash.currency;
    for (final money in <Money>[
      requestedPrepayment,
      loanPrepayment.appliedPrepayment,
      investedAmount,
      investmentFutureValue,
    ]) {
      if (money.currency != currency) {
        throw ArgumentError(
          'All hybrid strategy currencies must match ${currency.code}.',
        );
      }
      if (money.isNegative) {
        throw ArgumentError('Hybrid strategy amounts must not be negative.');
      }
    }
    if (!availableCash.isPositive) {
      throw ArgumentError.value(
        availableCash,
        'availableCash',
        'Available cash must be greater than zero.',
      );
    }
    if (requestedPrepayment != loanPrepayment.requestedPrepayment) {
      throw ArgumentError(
        'Requested prepayment must match the loan prepayment result.',
      );
    }
    if (loanPrepayment.appliedPrepayment + investedAmount != availableCash) {
      throw ArgumentError(
        'Applied prepayment plus investment must equal available cash.',
      );
    }
    if (investmentHorizonMonths < 0) {
      throw ArgumentError.value(
        investmentHorizonMonths,
        'investmentHorizonMonths',
        'Investment horizon must not be negative.',
      );
    }

    return HybridStrategyScenario._(
      requestedPrepaymentAllocation: requestedPrepaymentAllocation,
      availableCash: availableCash,
      requestedPrepayment: requestedPrepayment,
      loanPrepayment: loanPrepayment,
      investedAmount: investedAmount,
      investmentFutureValue: investmentFutureValue,
      investmentHorizonMonths: investmentHorizonMonths,
    );
  }

  const HybridStrategyScenario._({
    required this.requestedPrepaymentAllocation,
    required this.availableCash,
    required this.requestedPrepayment,
    required this.loanPrepayment,
    required this.investedAmount,
    required this.investmentFutureValue,
    required this.investmentHorizonMonths,
  });

  final Percentage requestedPrepaymentAllocation;
  final Money availableCash;
  final Money requestedPrepayment;
  final LoanPrepaymentResult loanPrepayment;
  final Money investedAmount;
  final Money investmentFutureValue;
  final int investmentHorizonMonths;

  Money get appliedPrepayment => loanPrepayment.appliedPrepayment;
  Money get redirectedToInvestment => loanPrepayment.unappliedPrepayment;
  Money get interestSaved => loanPrepayment.interestSaved;
  Money get investmentGain => investmentFutureValue - investedAmount;
  Money get totalNominalBenefit => interestSaved + investmentGain;
  int get installmentsReduced => loanPrepayment.installmentsReduced;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HybridStrategyScenario &&
            requestedPrepaymentAllocation ==
                other.requestedPrepaymentAllocation &&
            availableCash == other.availableCash &&
            requestedPrepayment == other.requestedPrepayment &&
            loanPrepayment == other.loanPrepayment &&
            investedAmount == other.investedAmount &&
            investmentFutureValue == other.investmentFutureValue &&
            investmentHorizonMonths == other.investmentHorizonMonths;
  }

  @override
  int get hashCode => Object.hash(
    requestedPrepaymentAllocation,
    availableCash,
    requestedPrepayment,
    loanPrepayment,
    investedAmount,
    investmentFutureValue,
    investmentHorizonMonths,
  );

  @override
  String toString() {
    return 'HybridStrategyScenario('
        'requestedPrepaymentAllocation: $requestedPrepaymentAllocation, '
        'appliedPrepayment: $appliedPrepayment, '
        'investedAmount: $investedAmount, '
        'interestSaved: $interestSaved, '
        'investmentGain: $investmentGain, '
        'totalNominalBenefit: $totalNominalBenefit, '
        'installmentsReduced: $installmentsReduced'
        ')';
  }
}

/// Immutable ranked set of prepayment/investment allocation scenarios.
@immutable
final class HybridStrategyResult {
  factory HybridStrategyResult({
    required Iterable<HybridStrategyScenario> scenarios,
    required Percentage netAnnualInvestmentReturn,
  }) {
    final snapshot = List<HybridStrategyScenario>.of(scenarios);
    if (snapshot.length < 2) {
      throw ArgumentError('At least the 0% and 100% endpoints are required.');
    }
    final currency = snapshot.first.availableCash.currency;
    for (var index = 0; index < snapshot.length; index++) {
      final scenario = snapshot[index];
      if (scenario.availableCash.currency != currency) {
        throw ArgumentError(
          'All hybrid strategy scenarios must use ${currency.code}.',
        );
      }
      if (index > 0 &&
          snapshot[index - 1].requestedPrepaymentAllocation.compareTo(
                scenario.requestedPrepaymentAllocation,
              ) >=
              0) {
        throw ArgumentError(
          'Hybrid scenarios must have unique ascending allocations.',
        );
      }
    }
    if (!snapshot.first.requestedPrepaymentAllocation.isZero ||
        snapshot.last.requestedPrepaymentAllocation.percent != _oneHundred) {
      throw ArgumentError('Hybrid scenarios must include 0% and 100%.');
    }

    var bestIndex = 0;
    for (var index = 1; index < snapshot.length; index++) {
      final benefitComparison = snapshot[index].totalNominalBenefit.compareTo(
        snapshot[bestIndex].totalNominalBenefit,
      );
      if (benefitComparison > 0 ||
          (benefitComparison == 0 &&
              snapshot[index].investedAmount.compareTo(
                    snapshot[bestIndex].investedAmount,
                  ) >
                  0)) {
        bestIndex = index;
      }
    }

    return HybridStrategyResult._(
      scenarios: UnmodifiableListView(snapshot),
      bestScenarioIndex: bestIndex,
      netAnnualInvestmentReturn: netAnnualInvestmentReturn,
    );
  }

  const HybridStrategyResult._({
    required this.scenarios,
    required this.bestScenarioIndex,
    required this.netAnnualInvestmentReturn,
  });

  final List<HybridStrategyScenario> scenarios;
  final int bestScenarioIndex;
  final Percentage netAnnualInvestmentReturn;

  HybridStrategyScenario get bestScenario => scenarios[bestScenarioIndex];
  HybridStrategyScenario get allInvestScenario => scenarios.first;
  HybridStrategyScenario get allPrepayScenario => scenarios.last;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HybridStrategyResult &&
            _listsEqual(scenarios, other.scenarios) &&
            bestScenarioIndex == other.bestScenarioIndex &&
            netAnnualInvestmentReturn == other.netAnnualInvestmentReturn;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(scenarios),
    bestScenarioIndex,
    netAnnualInvestmentReturn,
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
    return 'HybridStrategyResult('
        'bestScenarioIndex: $bestScenarioIndex, '
        'bestScenario: $bestScenario, '
        'netAnnualInvestmentReturn: $netAnnualInvestmentReturn, '
        'scenarios: $scenarios'
        ')';
  }
}

final Decimal _oneHundred = Decimal.fromInt(100);
