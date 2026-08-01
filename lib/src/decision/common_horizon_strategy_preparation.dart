import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../percentage/percentage.dart';
import 'common_horizon_strategy_result.dart';
import 'hybrid_strategy_input.dart';

/// Loan-dependent allocation scenarios prepared once for repeated revaluation.
@immutable
final class CommonHorizonStrategyPreparation {
  factory CommonHorizonStrategyPreparation({
    required HybridStrategyInput sourceInput,
    required CommonHorizonStrategyResult template,
  }) {
    if (template.scenarios.length < 2) {
      throw ArgumentError('Prepared scenarios must include both endpoints.');
    }
    if (template.netAnnualInvestmentReturn != _netAnnualReturn(sourceInput)) {
      throw ArgumentError(
        'Template investment return must match the source input.',
      );
    }
    for (final scenario in template.scenarios) {
      final allocation = scenario.allocation;
      if (allocation.availableCash != sourceInput.extraCash) {
        throw ArgumentError(
          'Prepared available cash must match the source input.',
        );
      }
      if (allocation.loanPrepayment.baseline.financedPrincipal !=
          sourceInput.loan.financedPrincipal) {
        throw ArgumentError(
          'Prepared loan principal must match the source input.',
        );
      }
    }

    return CommonHorizonStrategyPreparation._(
      sourceInput: sourceInput,
      template: template,
    );
  }

  const CommonHorizonStrategyPreparation._({
    required this.sourceInput,
    required this.template,
  });

  final HybridStrategyInput sourceInput;
  final CommonHorizonStrategyResult template;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommonHorizonStrategyPreparation &&
            sourceInput == other.sourceInput &&
            template == other.template;
  }

  @override
  int get hashCode => Object.hash(sourceInput, template);

  @override
  String toString() {
    return 'CommonHorizonStrategyPreparation('
        'sourceInput: $sourceInput, '
        'scenarioCount: ${template.scenarios.length}, '
        'commonHorizonInstallment: ${template.commonHorizonInstallment}'
        ')';
  }
}

Percentage _netAnnualReturn(HybridStrategyInput input) {
  final netFactor =
      (Decimal.one + input.grossAnnualInvestmentReturn.fraction) *
      (Decimal.one - input.annualExpenseRatio.fraction);
  return Percentage.fromFraction((netFactor - Decimal.one).toString());
}
