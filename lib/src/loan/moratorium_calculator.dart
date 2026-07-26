import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_calculator.dart';
import 'loan_input.dart';
import 'moratorium_entry.dart';
import 'moratorium_plan.dart';
import 'moratorium_result.dart';

/// Calculates a loan moratorium and the resulting repayment schedule.
@immutable
final class MoratoriumCalculator {
  const MoratoriumCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
  }) : assert(calculationScale > 0);

  static const String formulaId = 'LN-008';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;

  CalculationResult<MoratoriumResult> calculate(
    LoanInput input, {
    required MoratoriumPlan plan,
    required DateTime calculatedAt,
  }) {
    if (!input.financedPrincipal.isPositive) {
      throw ArgumentError.value(
        input.prepayment,
        'prepayment',
        'Moratorium requires a positive financed principal.',
      );
    }
    final repaymentTenure = plan.repaymentTenureMonths(input.tenureMonths);
    final calculator = AmortizationCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
    );
    final baselineSchedule = calculator
        .calculate(input, calculatedAt: calculatedAt)
        .value;
    final moratoriumEntries = _buildMoratoriumEntries(input, plan);
    final postMoratoriumBalance = moratoriumEntries.isEmpty
        ? input.financedPrincipal
        : moratoriumEntries.last.closingBalance;
    final repaymentSchedule = calculator
        .calculate(
          LoanInput(
            principal: postMoratoriumBalance,
            annualInterestRate: input.annualInterestRate,
            tenureMonths: repaymentTenure,
          ),
          calculatedAt: calculatedAt,
        )
        .value;
    final result = MoratoriumResult(
      plan: plan,
      moratoriumEntries: moratoriumEntries,
      baselineSchedule: baselineSchedule,
      repaymentSchedule: repaymentSchedule,
    );
    final warnings = <CalculationWarning>[
      if (result.totalCapitalizedInterest.isPositive)
        const CalculationWarning(
          code: 'LN-008-INTEREST-CAPITALIZED',
          message:
              'Moratorium interest is added to principal and itself earns '
              'interest during repayment.',
          severity: WarningSeverity.caution,
        ),
      if (plan.tenureTreatment ==
              MoratoriumTenureTreatment.withinOriginalTenure &&
          plan.months > 0)
        const CalculationWarning(
          code: 'LN-008-REPAYMENT-WINDOW-REDUCED',
          message:
              'Moratorium months reduce the remaining repayment window under '
              'the selected tenure treatment.',
          severity: WarningSeverity.caution,
        ),
    ];

    return CalculationResult<MoratoriumResult>(
      value: result,
      warnings: warnings,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'principal': input.principal.amount.toString(),
          'currency': input.principal.currency.code,
          'annualInterestRatePercent': input.annualInterestRate.percent
              .toString(),
          'originalTenureMonths': input.tenureMonths,
          'moratoriumMonths': plan.months,
          'moratoriumType': plan.type.name,
          'tenureTreatment': plan.tenureTreatment.name,
          'processingFee': input.processingFee?.amount.toString(),
          'prepayment': input.prepayment?.amount.toString(),
        },
        assumptions: <String, Object?>{
          'interestFrequency': 'monthly',
          'rateConvention': 'nominalAnnualRateDividedBy12',
          'interestRounding': 'eachMoratoriumMonth',
          'moratoriumTiming': 'beforeFirstRepaymentInstallment',
          'fullPaymentTreatment': 'interestCapitalizedMonthly',
          'interestOnlyTreatment': 'accruedInterestPaidMonthly',
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'amortizationFormulaId': AmortizationCalculator.formulaId,
          'repaymentTenureMonths': repaymentTenure,
          'balanceAfterMoratorium': result.balanceAfterMoratorium.amount
              .toString(),
          'postMoratoriumEmi': result.postMoratoriumEmi.amount.toString(),
          'totalMoratoriumInterest': result.totalMoratoriumInterest.amount
              .toString(),
          'totalMoratoriumPayments': result.totalMoratoriumPayments.amount
              .toString(),
          'totalCapitalizedInterest': result.totalCapitalizedInterest.amount
              .toString(),
          'totalInterest': result.totalInterest.amount.toString(),
          'additionalInterest': result.additionalInterest.amount.toString(),
          'totalElapsedMonths': result.totalElapsedMonths,
          'tenureChangeMonths': result.tenureChangeMonths,
          'calculationScale': calculationScale,
        },
      ),
    );
  }

  List<MoratoriumEntry> _buildMoratoriumEntries(
    LoanInput input,
    MoratoriumPlan plan,
  ) {
    final currency = input.financedPrincipal.currency;
    final monthlyRate =
        (input.annualInterestRate.fraction / Decimal.fromInt(12)).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        );
    final entries = <MoratoriumEntry>[];
    var openingBalance = input.financedPrincipal;

    for (var installment = 1; installment <= plan.months; installment++) {
      final interest = Money(
        amount: roundingPolicy.round(
          openingBalance.amount * monthlyRate,
          decimalPlaces: currency.decimalPlaces,
        ),
        currency: currency,
      );
      final isInterestOnly = plan.type == MoratoriumType.interestOnly;
      final payment = isInterestOnly ? interest : Money.zero(currency);
      final capitalizedInterest = isInterestOnly
          ? Money.zero(currency)
          : interest;
      final closingBalance = openingBalance + capitalizedInterest;
      entries.add(
        MoratoriumEntry(
          installmentNumber: installment,
          openingBalance: openingBalance,
          interestAccrued: interest,
          payment: payment,
          interestCapitalized: capitalizedInterest,
          closingBalance: closingBalance,
        ),
      );
      openingBalance = closingBalance;
    }
    return entries;
  }
}
