import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'swp_input.dart';
import 'swp_result.dart';

/// Projects fixed monthly withdrawals from an invested corpus.
///
/// Formula `INV-004` converts the effective annual return to an equivalent
/// monthly rate, applies investment growth and withdrawals in the explicitly
/// selected order, and stops when the corpus is depleted.
@immutable
final class SwpCalculator {
  const SwpCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maximumIterations = 256,
  });

  static const String formulaId = 'INV-004';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;
  final int maximumIterations;

  CalculationResult<SwpResult> calculate(
    SwpInput input, {
    required DateTime calculatedAt,
  }) {
    _validateConfiguration();
    final currency = input.initialInvestment.currency;
    final monthlyRate = _monthlyRateFromEffectiveAnnual(
      input.expectedAnnualReturn.fraction,
    );
    var balance = input.initialInvestment.amount;
    var totalWithdrawn = Decimal.zero;
    var withdrawalsMade = 0;
    var fullWithdrawalsMade = 0;
    var monthsProcessed = 0;
    int? depletionMonth;

    for (var month = 1; month <= input.tenureMonths; month++) {
      monthsProcessed = month;
      Decimal actualWithdrawal;

      if (input.withdrawalTiming == WithdrawalTiming.beginningOfPeriod) {
        actualWithdrawal = _minimum(input.monthlyWithdrawal.amount, balance);
        balance -= actualWithdrawal;
        if (balance > Decimal.zero) {
          balance = _applyMonthlyGrowth(
            balance,
            monthlyRate,
            currency.decimalPlaces,
          );
        }
      } else {
        balance = _applyMonthlyGrowth(
          balance,
          monthlyRate,
          currency.decimalPlaces,
        );
        actualWithdrawal = _minimum(input.monthlyWithdrawal.amount, balance);
        balance -= actualWithdrawal;
      }

      if (actualWithdrawal > Decimal.zero) {
        withdrawalsMade++;
        totalWithdrawn += actualWithdrawal;
        if (actualWithdrawal == input.monthlyWithdrawal.amount) {
          fullWithdrawalsMade++;
        }
      }

      if (balance <= Decimal.zero) {
        balance = Decimal.zero;
        depletionMonth = month;
        break;
      }
    }

    final result = SwpResult(
      initialInvestment: input.initialInvestment,
      monthlyWithdrawal: input.monthlyWithdrawal,
      totalWithdrawn: Money(amount: totalWithdrawn, currency: currency),
      endingBalance: Money(amount: balance, currency: currency),
      monthlyEquivalentReturn: Percentage.fromFraction(monthlyRate.toString()),
      tenureMonths: input.tenureMonths,
      monthsProcessed: monthsProcessed,
      withdrawalsMade: withdrawalsMade,
      fullWithdrawalsMade: fullWithdrawalsMade,
      depletionMonth: depletionMonth,
      withdrawalTiming: input.withdrawalTiming,
    );

    final warnings = <CalculationWarning>[
      const CalculationWarning(
        code: 'INV-004-PROJECTION-NOT-GUARANTEED',
        message:
            'Withdrawal sustainability is projected from the supplied return '
            'assumption and is not guaranteed.',
        severity: WarningSeverity.info,
      ),
      if (!result.isFullyFunded)
        CalculationWarning(
          code: 'INV-004-WITHDRAWAL-SHORTFALL',
          message:
              'The projected corpus cannot fund all scheduled withdrawals; '
              'the shortfall is ${result.withdrawalShortfall}.',
          severity: WarningSeverity.caution,
        ),
    ];

    return CalculationResult<SwpResult>(
      value: result,
      warnings: warnings,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'initialInvestment': input.initialInvestment.amount.toString(),
          'monthlyWithdrawal': input.monthlyWithdrawal.amount.toString(),
          'currency': currency.code,
          'expectedAnnualReturnPercent': input.expectedAnnualReturn.percent
              .toString(),
          'tenureMonths': input.tenureMonths,
          'withdrawalTiming': input.withdrawalTiming.name,
        },
        assumptions: <String, Object?>{
          'returnConvention': 'effectiveAnnualReturn',
          'monthlyRateConversion': 'twelfthRootOfAnnualGrowthFactor',
          'withdrawalFrequency': 'monthly',
          'withdrawalAmount': 'fixed',
          'partialFinalWithdrawal': true,
          'stopAtCorpusDepletion': true,
          'monthlyGrowthRounding': 'currencyDecimalPlaces',
          'roundingPolicy': roundingPolicy.name,
          'feesIncluded': false,
          'taxesIncluded': false,
          'inflationIncluded': false,
        },
        details: <String, Object?>{
          'monthlyEquivalentReturnPercent': result
              .monthlyEquivalentReturn
              .percent
              .toString(),
          'requestedTotalWithdrawal': result.requestedTotalWithdrawal.amount
              .toString(),
          'totalWithdrawn': result.totalWithdrawn.amount.toString(),
          'withdrawalShortfall': result.withdrawalShortfall.amount.toString(),
          'endingBalance': result.endingBalance.amount.toString(),
          'netGain': result.netGain.amount.toString(),
          'monthsProcessed': result.monthsProcessed,
          'withdrawalsMade': result.withdrawalsMade,
          'fullWithdrawalsMade': result.fullWithdrawalsMade,
          'depletionMonth': result.depletionMonth,
          'calculationScale': calculationScale,
          'maximumIterations': maximumIterations,
          'currencyDecimalPlaces': currency.decimalPlaces,
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
  }

  Decimal _applyMonthlyGrowth(
    Decimal balance,
    Decimal monthlyRate,
    int decimalPlaces,
  ) {
    final growth = roundingPolicy.round(
      balance * monthlyRate,
      decimalPlaces: decimalPlaces,
    );
    final grownBalance = balance + growth;
    return grownBalance < Decimal.zero ? Decimal.zero : grownBalance;
  }

  Decimal _monthlyRateFromEffectiveAnnual(Decimal annualRate) {
    final annualGrowthFactor = Decimal.one + annualRate;
    if (annualGrowthFactor == Decimal.zero) return -Decimal.one;
    if (annualGrowthFactor == Decimal.one) return Decimal.zero;

    var lower = annualGrowthFactor < Decimal.one ? Decimal.zero : Decimal.one;
    var upper = annualGrowthFactor < Decimal.one
        ? Decimal.one
        : annualGrowthFactor;
    final tolerance = Decimal.one.shift(-calculationScale);

    for (var iteration = 0; iteration < maximumIterations; iteration++) {
      final midpoint = ((lower + upper) / Decimal.fromInt(2)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final powered = _powAtScale(midpoint, 12);
      final difference = powered - annualGrowthFactor;
      if (difference.abs() <= tolerance || upper - lower <= tolerance) {
        return midpoint - Decimal.one;
      }
      if (difference < Decimal.zero) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
    }

    return ((lower + upper) / Decimal.fromInt(2)).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        ) -
        Decimal.one;
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

  Decimal _minimum(Decimal first, Decimal second) {
    return first <= second ? first : second;
  }
}
