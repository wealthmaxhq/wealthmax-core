import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

enum FinancialHealthRating { needsAttention, fair, good, excellent }

enum FinancialHealthFinding {
  buildEmergencyFund,
  reduceDebtBurden,
  increaseSavingsRate,
}

/// Transparent component scores and findings behind a 0–100 health score.
@immutable
final class FinancialHealthScoreResult {
  FinancialHealthScoreResult({
    required this.score,
    required this.emergencyFundScore,
    required this.debtBurdenScore,
    required this.savingsRateScore,
    required this.emergencyFundMonths,
    required this.debtToIncomePercent,
    required this.savingsRatePercent,
    required List<FinancialHealthFinding> findings,
  }) : findings = List.unmodifiable(findings) {
    for (final value in [
      score,
      emergencyFundScore,
      debtBurdenScore,
      savingsRateScore,
    ]) {
      if (value < 0 || value > 100) {
        throw ArgumentError.value(value, 'score', 'Must be between 0 and 100.');
      }
    }
  }

  final int score;
  final int emergencyFundScore;
  final int debtBurdenScore;
  final int savingsRateScore;
  final Decimal emergencyFundMonths;
  final Decimal debtToIncomePercent;
  final Decimal savingsRatePercent;
  final List<FinancialHealthFinding> findings;

  FinancialHealthRating get rating => switch (score) {
    >= 80 => FinancialHealthRating.excellent,
    >= 65 => FinancialHealthRating.good,
    >= 50 => FinancialHealthRating.fair,
    _ => FinancialHealthRating.needsAttention,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FinancialHealthScoreResult &&
            score == other.score &&
            emergencyFundScore == other.emergencyFundScore &&
            debtBurdenScore == other.debtBurdenScore &&
            savingsRateScore == other.savingsRateScore &&
            emergencyFundMonths == other.emergencyFundMonths &&
            debtToIncomePercent == other.debtToIncomePercent &&
            savingsRatePercent == other.savingsRatePercent &&
            _sameFindings(findings, other.findings);
  }

  @override
  int get hashCode => Object.hash(
    score,
    emergencyFundScore,
    debtBurdenScore,
    savingsRateScore,
    emergencyFundMonths,
    debtToIncomePercent,
    savingsRatePercent,
    Object.hashAll(findings),
  );

  static bool _sameFindings(
    List<FinancialHealthFinding> first,
    List<FinancialHealthFinding> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
