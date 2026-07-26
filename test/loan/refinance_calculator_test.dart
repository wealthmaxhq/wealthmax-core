import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 27, 10);

  Money inr(String value) => Money.parse(value, currency: Currencies.inr);

  RefinanceInput input({
    String principal = '1000000',
    String currentRate = '10',
    int remainingMonths = 120,
    String newRate = '8',
    int newTenureMonths = 120,
    String fees = '10000',
  }) {
    return RefinanceInput(
      outstandingPrincipal: inr(principal),
      currentAnnualInterestRate: Percentage.fromPercent(currentRate),
      remainingMonths: remainingMonths,
      newAnnualInterestRate: Percentage.fromPercent(newRate),
      newTenureMonths: newTenureMonths,
      refinancingFees: inr(fees),
    );
  }

  group('RefinanceCalculator', () {
    test('lower rate with same tenure lowers EMI and total cost', () {
      final result = const RefinanceCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.value.monthlyCashFlowSavings.isPositive, isTrue);
      expect(result.value.totalCostSavings.isPositive, isTrue);
      expect(result.value.grossInterestSavings.isPositive, isTrue);
      expect(result.value.isNominallyBeneficial, isTrue);
      expect(result.value.tenureDifference, 0);
    });

    test('includes refinancing fees in replacement total cost', () {
      final result = const RefinanceCalculator().calculate(
        input(fees: '25000'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.refinancedTotalCost,
        result.value.refinancedLoanPayments + inr('25000'),
      );
      expect(
        result.value.totalCostSavings,
        result.value.currentRemainingCost - result.value.refinancedTotalCost,
      );
    });

    test('high fees can make a lower rate unattractive', () {
      final result = const RefinanceCalculator().calculate(
        input(fees: '500000'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.totalCostSavings.isNegative, isTrue);
      expect(result.value.isNominallyBeneficial, isFalse);
    });

    test('longer tenure can lower EMI while increasing total cost', () {
      final result = const RefinanceCalculator().calculate(
        input(newTenureMonths: 240, fees: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.monthlyCashFlowSavings.isPositive, isTrue);
      expect(result.value.tenureDifference, 120);
      expect(result.value.totalCostSavings.isNegative, isTrue);
      expect(result.value.isNominallyBeneficial, isFalse);
    });

    test('shorter tenure can raise EMI while reducing total cost', () {
      final result = const RefinanceCalculator().calculate(
        input(newTenureMonths: 60, fees: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.monthlyCashFlowSavings.isNegative, isTrue);
      expect(result.value.tenureDifference, -60);
      expect(result.value.totalCostSavings.isPositive, isTrue);
      expect(result.value.feeRecoveryInstallments, isNull);
    });

    test('identical loans with no fees have no savings', () {
      final result = const RefinanceCalculator().calculate(
        input(newRate: '10', fees: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.currentLoan, result.value.refinancedLoan);
      expect(result.value.monthlyCashFlowSavings, inr('0'));
      expect(result.value.totalCostSavings, inr('0'));
      expect(result.value.isNominallyBeneficial, isFalse);
      expect(result.value.feeRecoveryInstallments, isNull);
    });

    test('zero fee recovers immediately when EMI is lower', () {
      final result = const RefinanceCalculator().calculate(
        input(fees: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.monthlyCashFlowSavings.isPositive, isTrue);
      expect(result.value.feeRecoveryInstallments, 0);
    });

    test('calculates fee recovery using ceiling installments', () {
      final result = const RefinanceCalculator().calculate(
        input(fees: '10000'),
        calculatedAt: calculatedAt,
      );
      final months = result.value.feeRecoveryInstallments;

      expect(months, isNotNull);
      expect(months, greaterThan(0));
      expect(
        result.value.monthlyCashFlowSavings.amount * Decimal.fromInt(months!),
        greaterThanOrEqualTo(result.value.refinancingFees.amount),
      );
    });

    test('returns no recovery when fees exceed overlapping EMI savings', () {
      final result = const RefinanceCalculator().calculate(
        input(fees: '1000000'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.feeRecoveryInstallments, isNull);
    });

    test('supports zero-interest comparisons', () {
      final result = const RefinanceCalculator().calculate(
        input(currentRate: '0', newRate: '0', fees: '0'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.currentLoan.totalInterest, inr('0'));
      expect(result.value.refinancedLoan.totalInterest, inr('0'));
      expect(result.value.totalCostSavings, inr('0'));
    });

    test('preserves another currency', () {
      final value = RefinanceInput(
        outstandingPrincipal: Money.parse('100000', currency: Currencies.usd),
        currentAnnualInterestRate: Percentage.fromPercent('10'),
        remainingMonths: 60,
        newAnnualInterestRate: Percentage.fromPercent('8'),
        newTenureMonths: 60,
        refinancingFees: Money.parse('500', currency: Currencies.usd),
      );
      final result = const RefinanceCalculator().calculate(
        value,
        calculatedAt: calculatedAt,
      );

      expect(result.value.currentEmi.currency, Currencies.usd);
      expect(result.value.newEmi.currency, Currencies.usd);
      expect(result.value.totalCostSavings.currency, Currencies.usd);
    });

    test('returns transparent LN-006 metadata', () {
      final result = const RefinanceCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'LN-006');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.details['amortizationFormulaId'], 'LN-002');
      expect(result.metadata.details['isNominallyBeneficial'], isTrue);
      expect(
        result.metadata.assumptions['timeValueDiscountingIncluded'],
        isFalse,
      );
      expect(result.metadata.assumptions['taxEffectsIncluded'], isFalse);
    });

    test('is deterministic', () {
      final value = input();
      const calculator = RefinanceCalculator();

      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
