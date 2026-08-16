import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';
import 'common_horizon_decision_analysis_result.dart';
import 'common_horizon_strategy_result.dart';

/// One common-horizon scenario after tax and purchasing-power adjustments.
@immutable
final class AdjustedDecisionScenario {
  factory AdjustedDecisionScenario({
    required CommonHorizonScenario nominalScenario,
    required Money taxableInvestmentGain,
    required Money estimatedTax,
    required Money afterTaxFutureValue,
    required Money realAfterTaxFutureValue,
  }) {
    final currency = nominalScenario.totalFutureValue.currency;
    for (final value in <Money>[
      taxableInvestmentGain,
      estimatedTax,
      afterTaxFutureValue,
      realAfterTaxFutureValue,
    ]) {
      if (value.currency != currency || value.isNegative) {
        throw ArgumentError(
          'Adjusted scenario values must be non-negative and use ${currency.code}.',
        );
      }
    }
    if (afterTaxFutureValue !=
        nominalScenario.totalFutureValue - estimatedTax) {
      throw ArgumentError(
        'After-tax future value must reconcile to estimated tax.',
      );
    }
    if (estimatedTax.compareTo(taxableInvestmentGain) > 0) {
      throw ArgumentError('Estimated tax must not exceed taxable gain.');
    }
    return AdjustedDecisionScenario._(
      nominalScenario: nominalScenario,
      taxableInvestmentGain: taxableInvestmentGain,
      estimatedTax: estimatedTax,
      afterTaxFutureValue: afterTaxFutureValue,
      realAfterTaxFutureValue: realAfterTaxFutureValue,
    );
  }

  const AdjustedDecisionScenario._({
    required this.nominalScenario,
    required this.taxableInvestmentGain,
    required this.estimatedTax,
    required this.afterTaxFutureValue,
    required this.realAfterTaxFutureValue,
  });

  final CommonHorizonScenario nominalScenario;
  final Money taxableInvestmentGain;
  final Money estimatedTax;
  final Money afterTaxFutureValue;
  final Money realAfterTaxFutureValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustedDecisionScenario &&
          nominalScenario == other.nominalScenario &&
          taxableInvestmentGain == other.taxableInvestmentGain &&
          estimatedTax == other.estimatedTax &&
          afterTaxFutureValue == other.afterTaxFutureValue &&
          realAfterTaxFutureValue == other.realAfterTaxFutureValue;

  @override
  int get hashCode => Object.hash(
    nominalScenario,
    taxableInvestmentGain,
    estimatedTax,
    afterTaxFutureValue,
    realAfterTaxFutureValue,
  );

  @override
  String toString() =>
      'AdjustedDecisionScenario(allocation: '
      '${nominalScenario.requestedPrepaymentAllocation}, '
      'estimatedTax: $estimatedTax, afterTaxFutureValue: '
      '$afterTaxFutureValue, realAfterTaxFutureValue: $realAfterTaxFutureValue)';
}

/// Consolidated nominal analysis with an adjusted allocation recommendation.
@immutable
final class AdjustedDecisionAnalysisResult {
  factory AdjustedDecisionAnalysisResult({
    required CommonHorizonDecisionAnalysisResult nominalAnalysis,
    required Iterable<AdjustedDecisionScenario> scenarios,
    required int selectedScenarioIndex,
    required Percentage investmentGainTaxRate,
    required Percentage annualInflationRate,
  }) {
    if (investmentGainTaxRate.isNegative ||
        investmentGainTaxRate.percent > Decimal.fromInt(100)) {
      throw ArgumentError.value(
        investmentGainTaxRate,
        'investmentGainTaxRate',
        'Investment gain tax rate must be between 0% and 100%.',
      );
    }
    if (annualInflationRate.percent <= Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        annualInflationRate,
        'annualInflationRate',
        'Annual inflation rate must be greater than -100%.',
      );
    }
    final snapshot = List<AdjustedDecisionScenario>.of(scenarios);
    if (snapshot.length != nominalAnalysis.optimization.scenarios.length) {
      throw ArgumentError('Adjusted scenarios must cover the nominal grid.');
    }
    for (var index = 0; index < snapshot.length; index++) {
      if (snapshot[index].nominalScenario !=
          nominalAnalysis.optimization.scenarios[index]) {
        throw ArgumentError(
          'Adjusted scenario order must match the nominal grid.',
        );
      }
    }
    if (selectedScenarioIndex < 0 || selectedScenarioIndex >= snapshot.length) {
      throw RangeError.index(
        selectedScenarioIndex,
        snapshot,
        'selectedScenarioIndex',
      );
    }
    return AdjustedDecisionAnalysisResult._(
      nominalAnalysis: nominalAnalysis,
      scenarios: UnmodifiableListView(snapshot),
      selectedScenarioIndex: selectedScenarioIndex,
      investmentGainTaxRate: investmentGainTaxRate,
      annualInflationRate: annualInflationRate,
    );
  }

  const AdjustedDecisionAnalysisResult._({
    required this.nominalAnalysis,
    required this.scenarios,
    required this.selectedScenarioIndex,
    required this.investmentGainTaxRate,
    required this.annualInflationRate,
  });

  final CommonHorizonDecisionAnalysisResult nominalAnalysis;
  final List<AdjustedDecisionScenario> scenarios;
  final int selectedScenarioIndex;
  final Percentage investmentGainTaxRate;
  final Percentage annualInflationRate;

  AdjustedDecisionScenario get selectedScenario =>
      scenarios[selectedScenarioIndex];
  bool get selectionChangedByTax =>
      selectedScenarioIndex != nominalAnalysis.selection.selectedScenarioIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustedDecisionAnalysisResult &&
          nominalAnalysis == other.nominalAnalysis &&
          _listsEqual(scenarios, other.scenarios) &&
          selectedScenarioIndex == other.selectedScenarioIndex &&
          investmentGainTaxRate == other.investmentGainTaxRate &&
          annualInflationRate == other.annualInflationRate;

  @override
  int get hashCode => Object.hash(
    nominalAnalysis,
    Object.hashAll(scenarios),
    selectedScenarioIndex,
    investmentGainTaxRate,
    annualInflationRate,
  );

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'AdjustedDecisionAnalysisResult(selectedScenarioIndex: '
      '$selectedScenarioIndex, selectionChangedByTax: $selectionChangedByTax, '
      'investmentGainTaxRate: $investmentGainTaxRate, '
      'annualInflationRate: $annualInflationRate)';
}
