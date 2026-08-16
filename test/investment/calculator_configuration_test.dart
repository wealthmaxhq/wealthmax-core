import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 4, 12);

  Money inr(String amount) => Money.parse(amount, currency: Currencies.inr);

  Matcher invalidConfiguration(String parameterName) {
    return throwsA(
      isA<ArgumentError>().having((error) => error.name, 'name', parameterName),
    );
  }

  final cagrInput = CagrInput(
    initialValue: inr('100'),
    finalValue: inr('110'),
    holdingPeriodDays: 365,
  );
  final inflationInput = InflationAdjustmentInput(
    nominalFutureValue: inr('106'),
    annualInflationRate: Percentage.fromPercent('6'),
    horizonMonths: 12,
  );
  final lumpSumInput = LumpSumInput(
    initialInvestment: inr('1000'),
    expectedAnnualReturn: Percentage.fromPercent('10'),
    tenureYears: 1,
  );
  final realReturnInput = RealReturnInput(
    nominalReturn: Percentage.fromPercent('10'),
    inflationRate: Percentage.fromPercent('5'),
  );
  final sipInput = SipInput(
    monthlyContribution: inr('1000'),
    expectedAnnualReturn: Percentage.fromPercent('10'),
    tenureMonths: 12,
    contributionTiming: ContributionTiming.endOfPeriod,
  );
  final stepUpSipInput = StepUpSipInput(
    initialMonthlyContribution: inr('1000'),
    expectedAnnualReturn: Percentage.fromPercent('10'),
    annualStepUp: Percentage.fromPercent('5'),
    tenureMonths: 12,
    contributionTiming: ContributionTiming.endOfPeriod,
  );
  final swpInput = SwpInput(
    initialInvestment: inr('20000'),
    monthlyWithdrawal: inr('1000'),
    expectedAnnualReturn: Percentage.fromPercent('10'),
    tenureMonths: 12,
    withdrawalTiming: WithdrawalTiming.endOfPeriod,
  );
  final xirrInput = XirrInput(
    cashFlows: <DatedCashFlow>[
      DatedCashFlow(date: DateTime.utc(2025), amount: inr('-1000')),
      DatedCashFlow(date: DateTime.utc(2026), amount: inr('1100')),
    ],
  );

  group('investment calculator configuration', () {
    test('CAGR rejects a non-positive calculation scale', () {
      expect(
        () => const CagrCalculator(
          calculationScale: 0,
        ).calculate(cagrInput, calculatedAt: calculatedAt),
        invalidConfiguration('calculationScale'),
      );
    });

    test('CAGR rejects a non-positive iteration limit', () {
      expect(
        () => const CagrCalculator(
          maximumIterations: 0,
        ).calculate(cagrInput, calculatedAt: calculatedAt),
        invalidConfiguration('maximumIterations'),
      );
    });

    test('inflation adjustment rejects a non-positive calculation scale', () {
      expect(
        () => const InflationAdjustmentCalculator(
          calculationScale: 0,
        ).calculate(inflationInput, calculatedAt: calculatedAt),
        invalidConfiguration('calculationScale'),
      );
    });

    test('inflation adjustment rejects a non-positive iteration limit', () {
      expect(
        () => const InflationAdjustmentCalculator(
          maximumIterations: 0,
        ).calculate(inflationInput, calculatedAt: calculatedAt),
        invalidConfiguration('maximumIterations'),
      );
    });

    test('lump sum rejects a non-positive calculation scale', () {
      expect(
        () => const LumpSumCalculator(
          calculationScale: 0,
        ).calculate(lumpSumInput, calculatedAt: calculatedAt),
        invalidConfiguration('calculationScale'),
      );
    });

    test('real return rejects a non-positive calculation scale', () {
      expect(
        () => const RealReturnCalculator(
          calculationScale: 0,
        ).calculate(realReturnInput, calculatedAt: calculatedAt),
        invalidConfiguration('calculationScale'),
      );
    });

    test('SIP rejects a non-positive calculation scale', () {
      expect(
        () => const SipCalculator(
          calculationScale: 0,
        ).calculate(sipInput, calculatedAt: calculatedAt),
        invalidConfiguration('calculationScale'),
      );
    });

    test('SIP rejects a non-positive iteration limit', () {
      expect(
        () => const SipCalculator(
          maximumIterations: 0,
        ).calculate(sipInput, calculatedAt: calculatedAt),
        invalidConfiguration('maximumIterations'),
      );
    });

    test('step-up SIP rejects a non-positive calculation scale', () {
      expect(
        () => const StepUpSipCalculator(
          calculationScale: 0,
        ).calculate(stepUpSipInput, calculatedAt: calculatedAt),
        invalidConfiguration('calculationScale'),
      );
    });

    test('step-up SIP rejects a non-positive iteration limit', () {
      expect(
        () => const StepUpSipCalculator(
          maximumIterations: 0,
        ).calculate(stepUpSipInput, calculatedAt: calculatedAt),
        invalidConfiguration('maximumIterations'),
      );
    });

    test('SWP rejects a non-positive calculation scale', () {
      expect(
        () => const SwpCalculator(
          calculationScale: 0,
        ).calculate(swpInput, calculatedAt: calculatedAt),
        invalidConfiguration('calculationScale'),
      );
    });

    test('SWP rejects a non-positive iteration limit', () {
      expect(
        () => const SwpCalculator(
          maximumIterations: 0,
        ).calculate(swpInput, calculatedAt: calculatedAt),
        invalidConfiguration('maximumIterations'),
      );
    });

    test('XIRR rejects a non-positive calculation scale', () {
      expect(
        () => const XirrCalculator(
          calculationScale: 0,
        ).calculate(xirrInput, calculatedAt: calculatedAt),
        invalidConfiguration('calculationScale'),
      );
    });

    test('XIRR rejects a non-positive iteration limit', () {
      expect(
        () => const XirrCalculator(
          maximumIterations: 0,
        ).calculate(xirrInput, calculatedAt: calculatedAt),
        invalidConfiguration('maximumIterations'),
      );
    });

    test('XIRR rejects a non-positive bracket expansion limit', () {
      expect(
        () => const XirrCalculator(
          maximumBracketExpansions: 0,
        ).calculate(xirrInput, calculatedAt: calculatedAt),
        invalidConfiguration('maximumBracketExpansions'),
      );
    });
  });
}
