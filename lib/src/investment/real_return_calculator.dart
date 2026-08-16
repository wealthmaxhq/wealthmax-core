import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../percentage/percentage.dart';
import 'real_return_input.dart';
import 'real_return_result.dart';

/// Calculates inflation-adjusted return using the exact Fisher equation.
///
/// Formula `INV-007`: `real = (1 + nominal) / (1 + inflation) - 1`.
@immutable
final class RealReturnCalculator {
  const RealReturnCalculator({this.calculationScale = 32});

  static const String formulaId = 'INV-007';
  static const String formulaVersion = '1.0.0';

  final int calculationScale;

  CalculationResult<RealReturnResult> calculate(
    RealReturnInput input, {
    required DateTime calculatedAt,
  }) {
    if (calculationScale <= 0) {
      throw ArgumentError.value(
        calculationScale,
        'calculationScale',
        'Must be greater than zero.',
      );
    }

    final nominalGrowthFactor = Decimal.one + input.nominalReturn.fraction;
    final inflationGrowthFactor = Decimal.one + input.inflationRate.fraction;
    final realGrowthFactor = (nominalGrowthFactor / inflationGrowthFactor)
        .toDecimal(scaleOnInfinitePrecision: calculationScale);
    final realReturn = Percentage.fromFraction(
      (realGrowthFactor - Decimal.one).toString(),
    );
    final result = RealReturnResult(
      nominalReturn: input.nominalReturn,
      inflationRate: input.inflationRate,
      realReturn: realReturn,
    );

    return CalculationResult<RealReturnResult>(
      value: result,
      warnings: const <CalculationWarning>[
        CalculationWarning(
          code: 'INV-007-ASSUMPTION-SENSITIVE',
          message:
              'Real return depends on the supplied nominal-return and '
              'inflation assumptions.',
          severity: WarningSeverity.info,
        ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'nominalReturnPercent': input.nominalReturn.percent.toString(),
          'inflationRatePercent': input.inflationRate.percent.toString(),
        },
        assumptions: const <String, Object?>{
          'formula': 'exactFisherEquation',
          'ratesAreEffectiveForSamePeriod': true,
          'taxesIncluded': false,
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'nominalGrowthFactor': nominalGrowthFactor.toString(),
          'inflationGrowthFactor': inflationGrowthFactor.toString(),
          'realGrowthFactor': realGrowthFactor.toString(),
          'realReturnPercent': result.realReturn.percent.toString(),
          'calculationScale': calculationScale,
        },
      ),
    );
  }
}
