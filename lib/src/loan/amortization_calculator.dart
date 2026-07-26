import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_entry.dart';
import 'amortization_schedule.dart';
import 'emi_calculator.dart';
import 'loan_input.dart';

/// Builds a month-by-month reducing-balance amortization schedule.
@immutable
final class AmortizationCalculator {
  const AmortizationCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
  }) : assert(calculationScale > 0);

  static const String formulaId = 'LN-002';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;

  CalculationResult<AmortizationSchedule> calculate(
    LoanInput input, {
    required DateTime calculatedAt,
  }) {
    final emiResult = EmiCalculator(
      roundingPolicy: roundingPolicy,
      calculationScale: calculationScale,
    ).calculate(input, calculatedAt: calculatedAt);
    final financedPrincipal = input.financedPrincipal;

    final entries = financedPrincipal.isZero
        ? const <AmortizationEntry>[]
        : _buildEntries(input, scheduledEmi: emiResult.value.emi);
    final schedule = AmortizationSchedule(
      scheduledEmi: emiResult.value.emi,
      financedPrincipal: financedPrincipal,
      entries: entries,
    );

    return CalculationResult<AmortizationSchedule>(
      value: schedule,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'principal': input.principal.amount.toString(),
          'currency': input.principal.currency.code,
          'annualInterestRatePercent': input.annualInterestRate.percent
              .toString(),
          'tenureMonths': input.tenureMonths,
          'processingFee': input.processingFee?.amount.toString(),
          'prepayment': input.prepayment?.amount.toString(),
        },
        assumptions: <String, Object?>{
          'repaymentFrequency': 'monthly',
          'interestMethod': 'reducingBalance',
          'rateConvention': 'nominalAnnualRateDividedBy12',
          'componentRounding': 'eachInstallment',
          'finalPaymentAdjustment': true,
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'emiFormulaId': EmiCalculator.formulaId,
          'scheduledEmi': schedule.scheduledEmi.amount.toString(),
          'paymentCount': schedule.paymentCount,
          'totalPrincipal': schedule.totalPrincipal.amount.toString(),
          'totalInterest': schedule.totalInterest.amount.toString(),
          'totalPayment': schedule.totalPayment.amount.toString(),
          'calculationScale': calculationScale,
        },
      ),
    );
  }

  List<AmortizationEntry> _buildEntries(
    LoanInput input, {
    required Money scheduledEmi,
  }) {
    final currency = input.principal.currency;
    final decimalPlaces = currency.decimalPlaces;
    final monthlyRate =
        (input.annualInterestRate.fraction / Decimal.fromInt(12)).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        );
    final entries = <AmortizationEntry>[];
    var openingBalance = input.financedPrincipal;

    for (
      var installmentNumber = 1;
      installmentNumber <= input.tenureMonths;
      installmentNumber++
    ) {
      final rawInterest = openingBalance.amount * monthlyRate;
      final interest = Money(
        amount: roundingPolicy.round(rawInterest, decimalPlaces: decimalPlaces),
        currency: currency,
      );
      final payoffAmount = openingBalance + interest;
      final isFinalScheduledInstallment =
          installmentNumber == input.tenureMonths;
      final payment =
          isFinalScheduledInstallment ||
              scheduledEmi.compareTo(payoffAmount) >= 0
          ? payoffAmount
          : scheduledEmi;
      final principal = payment - interest;

      if (!principal.isPositive) {
        throw StateError(
          'Rounded EMI does not cover installment interest; '
          'the loan would negatively amortize.',
        );
      }

      final closingBalance = openingBalance - principal;
      entries.add(
        AmortizationEntry(
          installmentNumber: installmentNumber,
          openingBalance: openingBalance,
          payment: payment,
          interest: interest,
          principal: principal,
          closingBalance: closingBalance,
        ),
      );
      openingBalance = closingBalance;

      if (openingBalance.isZero) break;
    }

    return entries;
  }
}
