import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../percentage/percentage.dart';
import 'common_horizon_decision_analysis_input.dart';

/// Tax and inflation assumptions applied to a normalized decision analysis.
@immutable
final class AdjustedDecisionAnalysisInput {
  factory AdjustedDecisionAnalysisInput({
    required CommonHorizonDecisionAnalysisInput analysis,
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
    return AdjustedDecisionAnalysisInput._(
      analysis: analysis,
      investmentGainTaxRate: investmentGainTaxRate,
      annualInflationRate: annualInflationRate,
    );
  }

  const AdjustedDecisionAnalysisInput._({
    required this.analysis,
    required this.investmentGainTaxRate,
    required this.annualInflationRate,
  });

  final CommonHorizonDecisionAnalysisInput analysis;
  final Percentage investmentGainTaxRate;
  final Percentage annualInflationRate;

  AdjustedDecisionAnalysisInput copyWith({
    CommonHorizonDecisionAnalysisInput? analysis,
    Percentage? investmentGainTaxRate,
    Percentage? annualInflationRate,
  }) => AdjustedDecisionAnalysisInput(
    analysis: analysis ?? this.analysis,
    investmentGainTaxRate: investmentGainTaxRate ?? this.investmentGainTaxRate,
    annualInflationRate: annualInflationRate ?? this.annualInflationRate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdjustedDecisionAnalysisInput &&
          analysis == other.analysis &&
          investmentGainTaxRate == other.investmentGainTaxRate &&
          annualInflationRate == other.annualInflationRate;

  @override
  int get hashCode =>
      Object.hash(analysis, investmentGainTaxRate, annualInflationRate);

  @override
  String toString() =>
      'AdjustedDecisionAnalysisInput('
      'investmentGainTaxRate: $investmentGainTaxRate, '
      'annualInflationRate: $annualInflationRate, analysis: $analysis)';
}
