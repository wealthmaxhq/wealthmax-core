import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 28, 16);
  const annualReturnForOnePercentMonthly = '12.6825030131969720661201';

  SipInput input({
    String contribution = '1000',
    String annualReturn = annualReturnForOnePercentMonthly,
    int months = 12,
    ContributionTiming timing = ContributionTiming.endOfPeriod,
    Currency currency = Currencies.inr,
  }) {
    return SipInput(
      monthlyContribution: Money.parse(contribution, currency: currency),
      expectedAnnualReturn: Percentage.fromPercent(annualReturn),
      tenureMonths: months,
      contributionTiming: timing,
    );
  }

  bool closeTo(Decimal actual, Decimal expected, String tolerance) {
    return (actual - expected).abs() <= Decimal.parse(tolerance);
  }

  group('SipCalculator', () {
    test('projects end-of-period contributions at one percent monthly', () {
      final result = const SipCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('12682.50', currency: Currencies.inr),
      );
      expect(
        result.value.totalInvested,
        Money.parse('12000', currency: Currencies.inr),
      );
      expect(
        closeTo(
          result.value.monthlyEquivalentReturn.percent,
          Decimal.parse('1'),
          '0.0000000001',
        ),
        isTrue,
      );
    });

    test('projects beginning-of-period contributions as an annuity due', () {
      final result = const SipCalculator().calculate(
        input(timing: ContributionTiming.beginningOfPeriod),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('12809.33', currency: Currencies.inr),
      );
    });

    test(
      'beginning contributions exceed end contributions for positive return',
      () {
        const calculator = SipCalculator();
        final beginning = calculator.calculate(
          input(timing: ContributionTiming.beginningOfPeriod),
          calculatedAt: calculatedAt,
        );
        final end = calculator.calculate(
          input(timing: ContributionTiming.endOfPeriod),
          calculatedAt: calculatedAt,
        );

        expect(
          beginning.value.futureValue.compareTo(end.value.futureValue),
          greaterThan(0),
        );
      },
    );

    test('zero return equals total contributions for either timing', () {
      const calculator = SipCalculator();
      final beginning = calculator.calculate(
        input(annualReturn: '0', timing: ContributionTiming.beginningOfPeriod),
        calculatedAt: calculatedAt,
      );
      final end = calculator.calculate(
        input(annualReturn: '0'),
        calculatedAt: calculatedAt,
      );

      expect(
        beginning.value.futureValue,
        Money.parse('12000', currency: Currencies.inr),
      );
      expect(end.value.futureValue, beginning.value.futureValue);
      expect(end.value.totalGain.isZero, isTrue);
    });

    test('supports a negative effective annual return', () {
      final result = const SipCalculator().calculate(
        input(annualReturn: '-10'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue.compareTo(result.value.totalInvested),
        lessThan(0),
      );
      expect(result.value.monthlyEquivalentReturn.isNegative, isTrue);
      expect(result.value.isLoss, isTrue);
    });

    test('total-loss return leaves only final end contribution', () {
      final result = const SipCalculator().calculate(
        input(annualReturn: '-100'),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('1000', currency: Currencies.inr),
      );
      expect(
        result.value.monthlyEquivalentReturn,
        Percentage.fromPercent('-100'),
      );
    });

    test('total-loss return erases each beginning contribution', () {
      final result = const SipCalculator().calculate(
        input(
          annualReturn: '-100',
          timing: ContributionTiming.beginningOfPeriod,
        ),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('0', currency: Currencies.inr),
      );
      expect(result.value.cumulativeReturn, Percentage.fromPercent('-100'));
    });

    test('supports a single contribution period', () {
      final result = const SipCalculator().calculate(
        input(months: 1),
        calculatedAt: calculatedAt,
      );

      expect(
        result.value.futureValue,
        Money.parse('1000', currency: Currencies.inr),
      );
      expect(
        result.value.totalInvested,
        Money.parse('1000', currency: Currencies.inr),
      );
    });

    test('preserves another currency', () {
      final result = const SipCalculator().calculate(
        input(currency: Currencies.usd),
        calculatedAt: calculatedAt,
      );

      expect(result.value.monthlyContribution.currency, Currencies.usd);
      expect(result.value.totalInvested.currency, Currencies.usd);
      expect(result.value.futureValue.currency, Currencies.usd);
    });

    test('honors final-value rounding policy', () {
      final value = input(
        contribution: '1',
        annualReturn: '1',
        months: 1,
        timing: ContributionTiming.beginningOfPeriod,
      );
      final halfUp = const SipCalculator().calculate(
        value,
        calculatedAt: calculatedAt,
      );
      final ceiling = const SipCalculator(
        roundingPolicy: RoundingPolicy.ceiling,
      ).calculate(value, calculatedAt: calculatedAt);

      expect(
        halfUp.value.futureValue,
        Money.parse('1.00', currency: Currencies.inr),
      );
      expect(
        ceiling.value.futureValue,
        Money.parse('1.01', currency: Currencies.inr),
      );
    });

    test('returns a non-guaranteed projection warning', () {
      final result = const SipCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.warnings.single.severity, WarningSeverity.info);
      expect(result.warnings.single.code, 'INV-002-PROJECTION-NOT-GUARANTEED');
    });

    test('returns transparent INV-002 metadata', () {
      final result = const SipCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'INV-002');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.inputs['monthlyContribution'], '1000');
      expect(result.metadata.inputs['tenureMonths'], 12);
      expect(result.metadata.inputs['contributionTiming'], 'endOfPeriod');
      expect(
        result.metadata.assumptions['monthlyRateConversion'],
        'twelfthRootOfAnnualGrowthFactor',
      );
      expect(result.metadata.assumptions['feesIncluded'], isFalse);
      expect(result.metadata.assumptions['taxesIncluded'], isFalse);
    });

    test('is deterministic', () {
      final value = input();
      const calculator = SipCalculator();

      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
