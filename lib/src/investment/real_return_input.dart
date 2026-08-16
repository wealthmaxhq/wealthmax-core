import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../percentage/percentage.dart';

/// Immutable nominal-return and inflation assumptions for the Fisher equation.
@immutable
final class RealReturnInput {
  factory RealReturnInput({
    required Percentage nominalReturn,
    required Percentage inflationRate,
  }) {
    if (nominalReturn.percent < Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        nominalReturn,
        'nominalReturn',
        'Nominal return must not be less than -100%.',
      );
    }
    if (inflationRate.percent <= Decimal.fromInt(-100)) {
      throw ArgumentError.value(
        inflationRate,
        'inflationRate',
        'Inflation rate must be greater than -100%.',
      );
    }

    return RealReturnInput._(
      nominalReturn: nominalReturn,
      inflationRate: inflationRate,
    );
  }

  const RealReturnInput._({
    required this.nominalReturn,
    required this.inflationRate,
  });

  final Percentage nominalReturn;
  final Percentage inflationRate;

  RealReturnInput copyWith({
    Percentage? nominalReturn,
    Percentage? inflationRate,
  }) {
    return RealReturnInput(
      nominalReturn: nominalReturn ?? this.nominalReturn,
      inflationRate: inflationRate ?? this.inflationRate,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RealReturnInput &&
            nominalReturn == other.nominalReturn &&
            inflationRate == other.inflationRate;
  }

  @override
  int get hashCode => Object.hash(nominalReturn, inflationRate);

  @override
  String toString() {
    return 'RealReturnInput('
        'nominalReturn: $nominalReturn, '
        'inflationRate: $inflationRate'
        ')';
  }
}
