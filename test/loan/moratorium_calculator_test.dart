import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 28, 12);

  LoanInput loan({
    String principal = '100000',
    String rate = '12',
    int months = 12,
    String? prepayment,
    Currency currency = Currencies.inr,
  }) {
    return LoanInput(
      principal: Money.parse(principal, currency: currency),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: months,
      prepayment: prepayment == null
          ? null
          : Money.parse(prepayment, currency: currency),
    );
  }

  MoratoriumPlan plan({
    int months = 3,
    MoratoriumType type = MoratoriumType.fullPayment,
    MoratoriumTenureTreatment treatment =
        MoratoriumTenureTreatment.extendTenure,
  }) {
    return MoratoriumPlan(
      months: months,
      type: type,
      tenureTreatment: treatment,
    );
  }

  group('MoratoriumCalculator', () {
    test('validates calculation scale at runtime', () {
      const calculator = MoratoriumCalculator(calculationScale: 0);

      expect(
        () => calculator.calculate(
          loan(),
          plan: plan(),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('full moratorium capitalizes interest monthly', () {
      final result = const MoratoriumCalculator().calculate(
        loan(),
        plan: plan(),
        calculatedAt: calculatedAt,
      );

      expect(result.value.moratoriumEntries, hasLength(3));
      expect(
        result.value.moratoriumEntries.first.interestAccrued,
        Money.parse('1000', currency: Currencies.inr),
      );
      expect(
        result.value.moratoriumEntries.first.payment,
        Money.parse('0', currency: Currencies.inr),
      );
      expect(
        result.value.balanceAfterMoratorium,
        Money.parse('103030.1', currency: Currencies.inr),
      );
      expect(
        result.value.totalCapitalizedInterest,
        Money.parse('3030.1', currency: Currencies.inr),
      );
    });

    test('interest-only moratorium keeps principal unchanged', () {
      final result = const MoratoriumCalculator().calculate(
        loan(),
        plan: plan(type: MoratoriumType.interestOnly),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.balanceAfterMoratorium,
        result.value.baselineSchedule.financedPrincipal,
      );
      expect(result.value.totalCapitalizedInterest.isZero, isTrue);
      expect(
        result.value.totalMoratoriumPayments,
        Money.parse('3000', currency: Currencies.inr),
      );
    });

    test('full moratorium raises post-moratorium EMI', () {
      final result = const MoratoriumCalculator().calculate(
        loan(),
        plan: plan(),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.postMoratoriumEmi.compareTo(
          result.value.baselineSchedule.scheduledEmi,
        ),
        greaterThan(0),
      );
    });

    test('interest-only with extended tenure preserves baseline EMI', () {
      final result = const MoratoriumCalculator().calculate(
        loan(),
        plan: plan(type: MoratoriumType.interestOnly),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.postMoratoriumEmi,
        result.value.baselineSchedule.scheduledEmi,
      );
    });

    test('extended treatment adds moratorium months to elapsed tenure', () {
      final result = const MoratoriumCalculator().calculate(
        loan(months: 24),
        plan: plan(months: 6),
        calculatedAt: calculatedAt,
      );

      expect(result.value.totalElapsedMonths, 30);
      expect(result.value.tenureChangeMonths, 6);
    });

    test('within-original treatment preserves contractual elapsed tenure', () {
      final result = const MoratoriumCalculator().calculate(
        loan(months: 24),
        plan: plan(
          months: 6,
          treatment: MoratoriumTenureTreatment.withinOriginalTenure,
        ),
        calculatedAt: calculatedAt,
      );

      expect(result.value.totalElapsedMonths, 24);
      expect(result.value.tenureChangeMonths, 0);
      expect(result.value.repaymentSchedule.paymentCount, 18);
    });

    test('within-original treatment raises EMI relative to extension', () {
      final extended = const MoratoriumCalculator().calculate(
        loan(months: 24),
        plan: plan(months: 6),
        calculatedAt: calculatedAt,
      );
      final contained = const MoratoriumCalculator().calculate(
        loan(months: 24),
        plan: plan(
          months: 6,
          treatment: MoratoriumTenureTreatment.withinOriginalTenure,
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        contained.value.postMoratoriumEmi.compareTo(
          extended.value.postMoratoriumEmi,
        ),
        greaterThan(0),
      );
    });

    test('zero-month plan matches baseline', () {
      final result = const MoratoriumCalculator().calculate(
        loan(),
        plan: plan(months: 0),
        calculatedAt: calculatedAt,
      );

      expect(result.value.moratoriumEntries, isEmpty);
      expect(result.value.repaymentSchedule, result.value.baselineSchedule);
      expect(result.value.additionalInterest.isZero, isTrue);
      expect(result.warnings, isEmpty);
    });

    test('zero-interest full moratorium does not grow balance', () {
      final result = const MoratoriumCalculator().calculate(
        loan(rate: '0'),
        plan: plan(),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.totalMoratoriumInterest,
        Money.parse('0', currency: Currencies.inr),
      );
      expect(
        result.value.totalCapitalizedInterest,
        Money.parse('0', currency: Currencies.inr),
      );
      expect(
        result.value.balanceAfterMoratorium,
        Money.parse('100000', currency: Currencies.inr),
      );
      expect(
        result.value.additionalInterest,
        Money.parse('0', currency: Currencies.inr),
      );
    });

    test('initial prepayment reduces the moratorium opening balance', () {
      final result = const MoratoriumCalculator().calculate(
        loan(prepayment: '10000'),
        plan: plan(months: 1),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.moratoriumEntries.first.openingBalance,
        Money.parse('90000', currency: Currencies.inr),
      );
      expect(
        result.value.moratoriumEntries.first.interestAccrued,
        Money.parse('900', currency: Currencies.inr),
      );
    });

    test('rejects a fully prepaid loan', () {
      expect(
        () => const MoratoriumCalculator().calculate(
          loan(principal: '1000', prepayment: '1000'),
          plan: plan(),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('rejects moratorium consuming original tenure', () {
      expect(
        () => const MoratoriumCalculator().calculate(
          loan(months: 3),
          plan: plan(
            months: 3,
            treatment: MoratoriumTenureTreatment.withinOriginalTenure,
          ),
          calculatedAt: calculatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('full moratorium emits capitalization warning', () {
      final result = const MoratoriumCalculator().calculate(
        loan(),
        plan: plan(),
        calculatedAt: calculatedAt,
      );

      expect(result.hasWarnings, isTrue);
      expect(
        result.warnings.map((warning) => warning.code),
        contains('LN-008-INTEREST-CAPITALIZED'),
      );
    });

    test('within-original treatment emits repayment-window warning', () {
      final result = const MoratoriumCalculator().calculate(
        loan(),
        plan: plan(treatment: MoratoriumTenureTreatment.withinOriginalTenure),
        calculatedAt: calculatedAt,
      );

      expect(
        result.warnings.map((warning) => warning.code),
        contains('LN-008-REPAYMENT-WINDOW-REDUCED'),
      );
    });

    test('preserves another currency', () {
      final result = const MoratoriumCalculator().calculate(
        loan(currency: Currencies.usd),
        plan: plan(),
        calculatedAt: calculatedAt,
      );

      expect(result.value.balanceAfterMoratorium.currency, Currencies.usd);
      expect(result.value.totalInterest.currency, Currencies.usd);
      expect(result.value.postMoratoriumEmi.currency, Currencies.usd);
    });

    test('returns transparent LN-008 metadata', () {
      final result = const MoratoriumCalculator().calculate(
        loan(),
        plan: plan(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'LN-008');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.inputs['moratoriumMonths'], 3);
      expect(result.metadata.inputs['moratoriumType'], 'fullPayment');
      expect(result.metadata.details['amortizationFormulaId'], 'LN-002');
      expect(
        result.metadata.assumptions['fullPaymentTreatment'],
        'interestCapitalizedMonthly',
      );
    });

    test('is deterministic', () {
      final input = loan();
      final selectedPlan = plan();
      const calculator = MoratoriumCalculator();

      final first = calculator.calculate(
        input,
        plan: selectedPlan,
        calculatedAt: calculatedAt,
      );
      final second = calculator.calculate(
        input,
        plan: selectedPlan,
        calculatedAt: calculatedAt,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
