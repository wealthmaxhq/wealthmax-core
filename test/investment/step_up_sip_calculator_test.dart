import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 29, 12);
  const annualReturnForOnePercentMonthly = '12.6825030131969720661201';

  StepUpSipInput input({
    String contribution = '1000',
    String annualReturn = annualReturnForOnePercentMonthly,
    String stepUp = '10',
    int months = 24,
    ContributionTiming timing = ContributionTiming.endOfPeriod,
    Currency currency = Currencies.inr,
  }) {
    return StepUpSipInput(
      initialMonthlyContribution: Money.parse(contribution, currency: currency),
      expectedAnnualReturn: Percentage.fromPercent(annualReturn),
      annualStepUp: Percentage.fromPercent(stepUp),
      tenureMonths: months,
      contributionTiming: timing,
    );
  }

  bool closeTo(Decimal actual, Decimal expected, String tolerance) {
    return (actual - expected).abs() <= Decimal.parse(tolerance);
  }

  group('StepUpSipCalculator', () {
    test('applies annual step-up after each completed 12-month block', () {
      final result = const StepUpSipCalculator().calculate(
        input(annualReturn: '0'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.finalMonthlyContribution,
        Money.parse('1100', currency: Currencies.inr),
      );
      expect(
        result.value.totalInvested,
        Money.parse('25200', currency: Currencies.inr),
      );
      expect(result.value.futureValue, result.value.totalInvested);
    });

    test('handles a partial final contribution year', () {
      final result = const StepUpSipCalculator().calculate(
        input(annualReturn: '0', months: 18),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.totalInvested,
        Money.parse('18600', currency: Currencies.inr),
      );
      expect(
        result.value.finalMonthlyContribution,
        Money.parse('1100', currency: Currencies.inr),
      );
    });

    test('does not step up during the first twelve months', () {
      final result = const StepUpSipCalculator().calculate(
        input(annualReturn: '0', months: 12),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.totalInvested,
        Money.parse('12000', currency: Currencies.inr),
      );
      expect(
        result.value.finalMonthlyContribution,
        Money.parse('1000', currency: Currencies.inr),
      );
    });

    test('zero step-up matches the regular SIP engine', () {
      final stepUpInput = input(stepUp: '0');
      final stepUp = const StepUpSipCalculator().calculate(
        stepUpInput,
        calculatedAt: calculatedAt,
      );
      final regular = const SipCalculator().calculate(
        SipInput(
          monthlyContribution: stepUpInput.initialMonthlyContribution,
          expectedAnnualReturn: stepUpInput.expectedAnnualReturn,
          tenureMonths: stepUpInput.tenureMonths,
          contributionTiming: stepUpInput.contributionTiming,
        ),
        calculatedAt: calculatedAt,
      );

      expect(stepUp.value.totalInvested, regular.value.totalInvested);
      expect(stepUp.value.futureValue, regular.value.futureValue);
      expect(
        stepUp.value.monthlyEquivalentReturn,
        regular.value.monthlyEquivalentReturn,
      );
    });

    test('positive step-up produces more wealth than a flat SIP', () {
      final stepUp = const StepUpSipCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );
      final flat = const StepUpSipCalculator().calculate(
        input(stepUp: '0'),
        calculatedAt: calculatedAt,
      );

      expect(
        stepUp.value.futureValue.compareTo(flat.value.futureValue),
        greaterThan(0),
      );
      expect(
        stepUp.value.totalInvested.compareTo(flat.value.totalInvested),
        greaterThan(0),
      );
    });

    test(
      'beginning contributions exceed end contributions at positive return',
      () {
        const calculator = StepUpSipCalculator();
        final beginning = calculator.calculate(
          input(timing: ContributionTiming.beginningOfPeriod),
          calculatedAt: calculatedAt,
        );
        final end = calculator.calculate(input(), calculatedAt: calculatedAt);

        expect(
          beginning.value.futureValue.compareTo(end.value.futureValue),
          greaterThan(0),
        );
        expect(beginning.value.totalInvested, end.value.totalInvested);
      },
    );

    test('supports annual step-downs', () {
      final result = const StepUpSipCalculator().calculate(
        input(annualReturn: '0', stepUp: '-10'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.finalMonthlyContribution,
        Money.parse('900', currency: Currencies.inr),
      );
      expect(
        result.value.totalInvested,
        Money.parse('22800', currency: Currencies.inr),
      );
    });

    test('full annual step-down makes later contributions zero', () {
      final result = const StepUpSipCalculator().calculate(
        input(annualReturn: '0', stepUp: '-100', months: 36),
        calculatedAt: calculatedAt,
      );

      expect(result.value.finalMonthlyContribution, Money.zero(Currencies.inr));
      expect(
        result.value.totalInvested,
        Money.parse('12000', currency: Currencies.inr),
      );
      expect(result.value.futureValue, result.value.totalInvested);
    });

    test('supports a negative expected return', () {
      final result = const StepUpSipCalculator().calculate(
        input(annualReturn: '-10'),
        calculatedAt: calculatedAt,
      );

      expect(result.value.monthlyEquivalentReturn.isNegative, isTrue);
      expect(result.value.isLoss, isTrue);
    });

    test('handles total-loss return for end contributions', () {
      final result = const StepUpSipCalculator().calculate(
        input(annualReturn: '-100'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('1100', currency: Currencies.inr),
      );
    });

    test('handles total-loss return for beginning contributions', () {
      final result = const StepUpSipCalculator().calculate(
        input(
          annualReturn: '-100',
          timing: ContributionTiming.beginningOfPeriod,
        ),
        calculatedAt: calculatedAt,
      );

      expect(result.value.futureValue, Money.zero(Currencies.inr));
      expect(result.value.cumulativeReturn, Percentage.fromPercent('-100'));
    });

    test('derives one percent equivalent monthly return accurately', () {
      final result = const StepUpSipCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(
        closeTo(
          result.value.monthlyEquivalentReturn.percent,
          Decimal.one,
          '0.0000000001',
        ),
        isTrue,
      );
    });

    test('rounds each annual contribution revision to currency precision', () {
      final result = const StepUpSipCalculator().calculate(
        input(
          contribution: '1000',
          annualReturn: '0',
          stepUp: '3.333',
          months: 25,
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.finalMonthlyContribution,
        Money.parse('1067.77', currency: Currencies.inr),
      );
      expect(
        result.value.totalInvested,
        Money.parse('25467.73', currency: Currencies.inr),
      );
    });

    test('honors the configured contribution rounding policy', () {
      final value = input(
        contribution: '1',
        annualReturn: '0',
        stepUp: '0.1',
        months: 13,
      );
      final halfUp = const StepUpSipCalculator().calculate(
        value,
        calculatedAt: calculatedAt,
      );
      final ceiling = const StepUpSipCalculator(
        roundingPolicy: RoundingPolicy.ceiling,
      ).calculate(value, calculatedAt: calculatedAt);

      expect(
        halfUp.value.finalMonthlyContribution,
        Money.parse('1.00', currency: Currencies.inr),
      );
      expect(
        ceiling.value.finalMonthlyContribution,
        Money.parse('1.01', currency: Currencies.inr),
      );
    });

    test('preserves another currency', () {
      final result = const StepUpSipCalculator().calculate(
        input(currency: Currencies.usd),
        calculatedAt: calculatedAt,
      );

      expect(result.value.initialMonthlyContribution.currency, Currencies.usd);
      expect(result.value.finalMonthlyContribution.currency, Currencies.usd);
      expect(result.value.totalInvested.currency, Currencies.usd);
      expect(result.value.futureValue.currency, Currencies.usd);
    });

    test('returns a transparent non-guaranteed warning and metadata', () {
      final result = const StepUpSipCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings.single.severity, WarningSeverity.info);
      expect(result.warnings.single.code, 'INV-003-PROJECTION-NOT-GUARANTEED');
      expect(result.metadata.formulaId, 'INV-003');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.inputs['annualStepUpPercent'], '10');
      expect(
        result.metadata.assumptions['stepUpFrequency'],
        'afterEachCompletedTwelveMonthBlock',
      );
      expect(
        result.metadata.assumptions['stepUpContributionRounding'],
        'atEachAnnualRevision',
      );
      expect(result.metadata.assumptions['taxesIncluded'], isFalse);
    });

    test('is deterministic', () {
      final value = input();
      const calculator = StepUpSipCalculator();

      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
