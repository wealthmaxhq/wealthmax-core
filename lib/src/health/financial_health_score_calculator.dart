import 'package:decimal/decimal.dart';

import '../rounding/rounding_policy.dart';
import 'financial_health_score_input.dart';
import 'financial_health_score_result.dart';

/// Calculates a transparent, deterministic 0–100 household health score.
///
/// The score weights emergency reserves at 40%, debt burden at 30%, and the
/// monthly savings rate at 30%. Full component scores correspond to six months
/// of essential expenses, debt payments at or below 20% of net income, and a
/// savings rate of at least 20%.
final class FinancialHealthScoreCalculator {
  const FinancialHealthScoreCalculator();

  static final Decimal _hundred = Decimal.fromInt(100);

  FinancialHealthScoreResult calculate(FinancialHealthScoreInput input) {
    final emergencyMonths =
        (input.liquidSavings.amount / input.monthlyEssentialExpenses.amount)
            .toDecimal(scaleOnInfinitePrecision: 12);
    final debtPercent =
        (input.monthlyDebtPayments.amount / input.monthlyNetIncome.amount)
            .toDecimal(scaleOnInfinitePrecision: 12) *
        _hundred;
    final savingsPercent =
        (input.monthlySavings.amount / input.monthlyNetIncome.amount).toDecimal(
          scaleOnInfinitePrecision: 12,
        ) *
        _hundred;

    final emergencyScore = _roundedScore(
      _clamp(
        (emergencyMonths / Decimal.fromInt(6)).toDecimal(
              scaleOnInfinitePrecision: 12,
            ) *
            _hundred,
      ),
    );
    final debtScore = _roundedScore(_debtScore(debtPercent));
    final savingsScore = _roundedScore(
      _clamp(
        (savingsPercent / Decimal.fromInt(20)).toDecimal(
              scaleOnInfinitePrecision: 12,
            ) *
            _hundred,
      ),
    );
    final overall = _roundedScore(
      Decimal.fromInt(emergencyScore) * Decimal.parse('0.4') +
          Decimal.fromInt(debtScore) * Decimal.parse('0.3') +
          Decimal.fromInt(savingsScore) * Decimal.parse('0.3'),
    );

    final findings = <FinancialHealthFinding>[
      if (emergencyMonths < Decimal.fromInt(3))
        FinancialHealthFinding.buildEmergencyFund,
      if (debtPercent > Decimal.fromInt(35))
        FinancialHealthFinding.reduceDebtBurden,
      if (savingsPercent < Decimal.fromInt(10))
        FinancialHealthFinding.increaseSavingsRate,
    ];

    return FinancialHealthScoreResult(
      score: overall,
      emergencyFundScore: emergencyScore,
      debtBurdenScore: debtScore,
      savingsRateScore: savingsScore,
      emergencyFundMonths: emergencyMonths,
      debtToIncomePercent: debtPercent,
      savingsRatePercent: savingsPercent,
      findings: findings,
    );
  }

  static Decimal _debtScore(Decimal debtPercent) {
    if (debtPercent <= Decimal.fromInt(20)) return _hundred;
    if (debtPercent >= Decimal.fromInt(50)) return Decimal.zero;
    return ((Decimal.fromInt(50) - debtPercent) / Decimal.fromInt(30))
            .toDecimal(scaleOnInfinitePrecision: 12) *
        _hundred;
  }

  static Decimal _clamp(Decimal value) {
    if (value < Decimal.zero) return Decimal.zero;
    if (value > _hundred) return _hundred;
    return value;
  }

  static int _roundedScore(Decimal value) {
    return RoundingPolicy.halfEven
        .round(_clamp(value), decimalPlaces: 0)
        .toBigInt()
        .toInt();
  }
}
