import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'dated_cash_flow.dart';
import 'xirr_input.dart';
import 'xirr_result.dart';

/// Calculates an actual/365 internal rate of return for dated cash flows.
///
/// Formula `INV-006` solves for a positive daily growth factor `d` where
/// `sum(cashFlow / d^daysFromStart) = 0`, then annualizes with `d^365 - 1`.
/// Integer powers avoid binary floating point and fractional exponentiation.
@immutable
final class XirrCalculator {
  const XirrCalculator({
    this.calculationScale = 32,
    this.maximumIterations = 256,
    this.maximumBracketExpansions = 64,
  });

  static const String formulaId = 'INV-006';
  static const String formulaVersion = '1.0.0';
  static const int daysPerYear = 365;

  final int calculationScale;
  final int maximumIterations;
  final int maximumBracketExpansions;

  CalculationResult<XirrResult> calculate(
    XirrInput input, {
    required DateTime calculatedAt,
  }) {
    _validateConfiguration();
    final aggregated = _aggregate(input.cashFlows);
    final startDate = aggregated.first.date;
    final endDate = aggregated.last.date;
    final currency = aggregated.first.amount.currency;
    final dailyGrowthFactor = _solveDailyGrowthFactor(aggregated, startDate);
    final annualGrowthFactor = _powAtScale(dailyGrowthFactor, daysPerYear);
    final annualizedFraction = annualGrowthFactor - Decimal.one;
    final dailyFraction = dailyGrowthFactor - Decimal.one;
    var contributions = Decimal.zero;
    var distributions = Decimal.zero;
    for (final cashFlow in input.cashFlows) {
      if (cashFlow.amount.isNegative) {
        contributions += cashFlow.amount.amount.abs();
      } else {
        distributions += cashFlow.amount.amount;
      }
    }
    final residual = _npv(aggregated, startDate, dailyGrowthFactor);
    final result = XirrResult(
      annualizedReturn: Percentage.fromFraction(annualizedFraction.toString()),
      dailyEquivalentReturn: Percentage.fromFraction(dailyFraction.toString()),
      totalContributions: Money(amount: contributions, currency: currency),
      totalDistributions: Money(amount: distributions, currency: currency),
      residualNpv: Money(amount: residual, currency: currency),
      startDate: startDate,
      endDate: endDate,
      cashFlowCount: input.cashFlows.length,
    );

    return CalculationResult<XirrResult>(
      value: result,
      warnings: <CalculationWarning>[
        if (aggregated.first.amount.isPositive)
          const CalculationWarning(
            code: 'INV-006-REVERSED-CASH-FLOW-DIRECTION',
            message:
                'The first cash flow is positive and later cash flows are '
                'negative; the result behaves like a financing cost.',
            severity: WarningSeverity.info,
          ),
      ],
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'currency': currency.code,
          'cashFlowCount': input.cashFlows.length,
          'aggregatedCashFlowCount': aggregated.length,
          'startDate': startDate.toIso8601String().substring(0, 10),
          'endDate': endDate.toIso8601String().substring(0, 10),
        },
        assumptions: const <String, Object?>{
          'dayCountConvention': 'actual/365',
          'cashFlowSignConvention':
              'contributionsNegativeDistributionsPositive',
          'requiredSignTransitions': 1,
          'multipleRootPatternsAccepted': false,
          'solver': 'bracketedBisectionOnDailyGrowthFactor',
          'binaryFloatingPointUsed': false,
        },
        details: <String, Object?>{
          'annualizedReturnPercent': result.annualizedReturn.percent.toString(),
          'dailyEquivalentReturnPercent': result.dailyEquivalentReturn.percent
              .toString(),
          'totalContributions': contributions.toString(),
          'totalDistributions': distributions.toString(),
          'netCashFlow': result.netCashFlow.amount.toString(),
          'residualNpv': residual.toString(),
          'daySpan': result.daySpan,
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
          'maximumBracketExpansions': maximumBracketExpansions,
        },
      ),
    );
  }

  void _validateConfiguration() {
    if (calculationScale <= 0) {
      throw ArgumentError.value(
        calculationScale,
        'calculationScale',
        'Must be greater than zero.',
      );
    }
    if (maximumIterations <= 0) {
      throw ArgumentError.value(
        maximumIterations,
        'maximumIterations',
        'Must be greater than zero.',
      );
    }
    if (maximumBracketExpansions <= 0) {
      throw ArgumentError.value(
        maximumBracketExpansions,
        'maximumBracketExpansions',
        'Must be greater than zero.',
      );
    }
  }

  List<DatedCashFlow> _aggregate(List<DatedCashFlow> cashFlows) {
    final amounts = <DateTime, Decimal>{};
    for (final cashFlow in cashFlows) {
      amounts.update(
        cashFlow.date,
        (amount) => amount + cashFlow.amount.amount,
        ifAbsent: () => cashFlow.amount.amount,
      );
    }
    final currency = cashFlows.first.amount.currency;
    final result =
        amounts.entries
            .where((entry) => entry.value != Decimal.zero)
            .map(
              (entry) => DatedCashFlow(
                date: entry.key,
                amount: Money(amount: entry.value, currency: currency),
              ),
            )
            .toList()
          ..sort((first, second) => first.date.compareTo(second.date));
    return result;
  }

  Decimal _solveDailyGrowthFactor(
    List<DatedCashFlow> cashFlows,
    DateTime startDate,
  ) {
    var lower = Decimal.parse('0.5');
    var upper = Decimal.fromInt(2);
    var lowerSign = _npvSign(cashFlows, startDate, lower);
    var upperSign = _npvSign(cashFlows, startDate, upper);

    for (
      var expansion = 0;
      lowerSign == upperSign && expansion < maximumBracketExpansions;
      expansion++
    ) {
      lower = (lower / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      upper *= Decimal.fromInt(2);
      lowerSign = _npvSign(cashFlows, startDate, lower);
      upperSign = _npvSign(cashFlows, startDate, upper);
    }
    if (lowerSign == upperSign) {
      throw StateError(
        'Unable to bracket a unique XIRR within the configured range.',
      );
    }

    final tolerance = Decimal.one.shift(-calculationScale);
    var midpoint = Decimal.one;
    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      midpoint = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final midpointSign = _npvSign(cashFlows, startDate, midpoint);
      if (midpointSign == 0 || upper - lower <= tolerance) {
        return midpoint;
      }
      if (midpointSign == lowerSign) {
        lower = midpoint;
        lowerSign = midpointSign;
      } else {
        upper = midpoint;
        upperSign = midpointSign;
      }
    }
    return midpoint;
  }

  int _npvSign(
    List<DatedCashFlow> cashFlows,
    DateTime startDate,
    Decimal dailyGrowthFactor,
  ) {
    return _npv(cashFlows, startDate, dailyGrowthFactor).sign;
  }

  Decimal _npv(
    List<DatedCashFlow> cashFlows,
    DateTime startDate,
    Decimal dailyGrowthFactor,
  ) {
    var result = Decimal.zero;
    for (final cashFlow in cashFlows) {
      final days = cashFlow.date.difference(startDate).inDays;
      final denominator = _powAtScale(dailyGrowthFactor, days);
      if (denominator == Decimal.zero) {
        return Decimal.fromInt(
          cashFlows.last.amount.amount.sign,
        ).shift(calculationScale);
      }
      final discounted = (cashFlow.amount.amount / denominator).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      result = _roundIntermediate(result + discounted);
    }
    return result;
  }

  Decimal _powAtScale(Decimal base, int exponent) {
    var result = Decimal.one;
    var factor = base;
    var remainingExponent = exponent;

    while (remainingExponent > 0) {
      if (remainingExponent.isOdd) {
        result = _roundIntermediate(result * factor);
      }
      remainingExponent ~/= 2;
      if (remainingExponent > 0) {
        factor = _roundIntermediate(factor * factor);
      }
    }
    return result;
  }

  Decimal _roundIntermediate(Decimal value) {
    return RoundingPolicy.halfEven.round(
      value,
      decimalPlaces: calculationScale,
    );
  }
}
