import 'package:decimal/decimal.dart';

import '../money/money.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_entry.dart';
import 'loan_input.dart';
import 'scheduled_prepayment.dart';

/// Shared internal kernel for fixed-rate, reducing-balance loan schedules.
///
/// Keeping EMI summaries and amortization schedules on this single path
/// prevents rounding or final-payment rules from drifting apart.
final class FixedLoanScheduleKernel {
  const FixedLoanScheduleKernel({
    required this.roundingPolicy,
    required this.calculationScale,
  });

  final RoundingPolicy roundingPolicy;
  final int calculationScale;

  static const String emiFormulaId = 'LN-001';

  Money calculateScheduledEmi(LoanInput input) {
    final financedPrincipal = input.financedPrincipal;
    final rawEmi = _calculateRawEmi(input);
    return Money(
      amount: roundingPolicy.round(
        rawEmi,
        decimalPlaces: financedPrincipal.currency.decimalPlaces,
      ),
      currency: financedPrincipal.currency,
    );
  }

  List<AmortizationEntry> buildEntries(
    LoanInput input, {
    required Money scheduledEmi,
    PrepaymentPlan? prepaymentPlan,
  }) {
    final financedPrincipal = input.financedPrincipal;
    if (financedPrincipal.isZero) return const <AmortizationEntry>[];

    final plan = prepaymentPlan ?? PrepaymentPlan.empty();
    final currency = input.principal.currency;
    final monthlyRate =
        (input.annualInterestRate.fraction / Decimal.fromInt(12)).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        );
    final entries = <AmortizationEntry>[];
    var openingBalance = financedPrincipal;

    for (
      var installmentNumber = 1;
      installmentNumber <= input.tenureMonths;
      installmentNumber++
    ) {
      final interest = Money(
        amount: roundingPolicy.round(
          openingBalance.amount * monthlyRate,
          decimalPlaces: currency.decimalPlaces,
        ),
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

      final balanceAfterScheduledPayment = openingBalance - principal;
      final requestedPrepayment = plan.totalForInstallment(
        installmentNumber,
        currency,
      );
      final appliedPrepayment =
          requestedPrepayment.compareTo(balanceAfterScheduledPayment) > 0
          ? balanceAfterScheduledPayment
          : requestedPrepayment;
      final closingBalance = balanceAfterScheduledPayment - appliedPrepayment;
      entries.add(
        AmortizationEntry(
          installmentNumber: installmentNumber,
          openingBalance: openingBalance,
          payment: payment,
          interest: interest,
          principal: principal,
          prepayment: appliedPrepayment,
          closingBalance: closingBalance,
        ),
      );
      openingBalance = closingBalance;

      if (openingBalance.isZero) break;
    }

    if (!openingBalance.isZero) {
      throw StateError(
        'Loan schedule did not close within the configured tenure.',
      );
    }

    return entries;
  }

  Decimal _calculateRawEmi(LoanInput input) {
    final principal = input.financedPrincipal.amount;
    if (principal == Decimal.zero) return Decimal.zero;

    final periods = Decimal.fromInt(input.tenureMonths);
    if (input.annualInterestRate.isZero) {
      return (principal / periods).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
    }

    final monthlyRate =
        (input.annualInterestRate.fraction / Decimal.fromInt(12)).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        );
    final growthFactor = Decimal.one + monthlyRate;
    final compounded = _powAtScale(growthFactor, input.tenureMonths);
    final numerator = principal * monthlyRate * compounded;
    final denominator = compounded - Decimal.one;

    return (numerator / denominator).toDecimal(
      scaleOnInfinitePrecision: calculationScale,
    );
  }

  Decimal _powAtScale(Decimal base, int exponent) {
    var result = Decimal.one;
    var factor = base;
    var remainingExponent = exponent;

    while (remainingExponent > 0) {
      if (remainingExponent.isOdd) {
        result = _roundIntermediate(result * factor);
      }

      remainingExponent ~/= 2;
      if (remainingExponent > 0) {
        factor = _roundIntermediate(factor * factor);
      }
    }

    return result;
  }

  Decimal _roundIntermediate(Decimal value) {
    return RoundingPolicy.halfEven.round(
      value,
      decimalPlaces: calculationScale,
    );
  }
}
