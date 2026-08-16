import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final currency = Currencies.fromCode('INR');
  Money money(String amount) => Money.parse(amount, currency: currency);

  FinancialHealthScoreInput input({
    String liquidSavings = '600000',
    String monthlyNetIncome = '100000',
    String monthlyEssentialExpenses = '100000',
    String monthlyDebtPayments = '20000',
    String monthlySavings = '20000',
  }) {
    return FinancialHealthScoreInput(
      liquidSavings: money(liquidSavings),
      monthlyNetIncome: money(monthlyNetIncome),
      monthlyEssentialExpenses: money(monthlyEssentialExpenses),
      monthlyDebtPayments: money(monthlyDebtPayments),
      monthlySavings: money(monthlySavings),
    );
  }

  group('FinancialHealthScoreInput', () {
    test('rejects negative, zero denominator, and mixed-currency inputs', () {
      expect(() => input(monthlySavings: '-1'), throwsArgumentError);
      expect(() => input(monthlyNetIncome: '0'), throwsArgumentError);
      expect(
        () => FinancialHealthScoreInput(
          liquidSavings: money('1'),
          monthlyNetIncome: money('1'),
          monthlyEssentialExpenses: money('1'),
          monthlyDebtPayments: money('0'),
          monthlySavings: Money.parse(
            '0',
            currency: Currencies.fromCode('USD'),
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('FinancialHealthScoreCalculator', () {
    const calculator = FinancialHealthScoreCalculator();

    test('awards a perfect score at all healthy thresholds', () {
      final result = calculator.calculate(input());

      expect(result.score, 100);
      expect(result.rating, FinancialHealthRating.excellent);
      expect(result.emergencyFundMonths, Decimal.fromInt(6));
      expect(result.debtToIncomePercent, Decimal.fromInt(20));
      expect(result.savingsRatePercent, Decimal.fromInt(20));
      expect(result.findings, isEmpty);
    });

    test('calculates transparent weighted component scores', () {
      final result = calculator.calculate(
        input(
          liquidSavings: '150000',
          monthlyEssentialExpenses: '100000',
          monthlyDebtPayments: '35000',
          monthlySavings: '10000',
        ),
      );

      expect(result.emergencyFundScore, 25);
      expect(result.debtBurdenScore, 50);
      expect(result.savingsRateScore, 50);
      expect(result.score, 40);
      expect(result.rating, FinancialHealthRating.needsAttention);
    });

    test('caps exceptionally strong components at one hundred', () {
      final result = calculator.calculate(
        input(
          liquidSavings: '1200000',
          monthlyDebtPayments: '0',
          monthlySavings: '50000',
        ),
      );

      expect(result.emergencyFundScore, 100);
      expect(result.debtBurdenScore, 100);
      expect(result.savingsRateScore, 100);
      expect(result.score, 100);
    });

    test('emits ordered actionable findings at risk thresholds', () {
      final result = calculator.calculate(
        input(
          liquidSavings: '100000',
          monthlyDebtPayments: '40000',
          monthlySavings: '5000',
        ),
      );

      expect(result.findings, [
        FinancialHealthFinding.buildEmergencyFund,
        FinancialHealthFinding.reduceDebtBurden,
        FinancialHealthFinding.increaseSavingsRate,
      ]);
      expect(
        () => result.findings.add(FinancialHealthFinding.buildEmergencyFund),
        throwsUnsupportedError,
      );
    });

    test('maps rating boundaries deterministically', () {
      FinancialHealthScoreResult result(int score) =>
          FinancialHealthScoreResult(
            score: score,
            emergencyFundScore: score,
            debtBurdenScore: score,
            savingsRateScore: score,
            emergencyFundMonths: Decimal.zero,
            debtToIncomePercent: Decimal.zero,
            savingsRatePercent: Decimal.zero,
            findings: const [],
          );

      expect(result(49).rating, FinancialHealthRating.needsAttention);
      expect(result(50).rating, FinancialHealthRating.fair);
      expect(result(65).rating, FinancialHealthRating.good);
      expect(result(80).rating, FinancialHealthRating.excellent);
    });

    test('is deterministic and supports result value equality', () {
      final first = calculator.calculate(input());
      final second = calculator.calculate(input());

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
