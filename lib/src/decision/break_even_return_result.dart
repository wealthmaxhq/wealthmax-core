import 'package:meta/meta.dart';

import '../loan/loan_prepayment_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable return threshold at which invest and prepay have equal gain.
@immutable
final class BreakEvenReturnResult {
  factory BreakEvenReturnResult({
    required LoanPrepaymentResult loanPrepayment,
    required Money investedAmount,
    required Money requiredFutureValue,
    required Percentage annualExpenseRatio,
    required Percentage breakEvenNetAnnualReturn,
    required Percentage breakEvenGrossAnnualReturn,
    required int investmentHorizonMonths,
  }) {
    final currency = loanPrepayment.baseline.financedPrincipal.currency;
    for (final value in <Money>[investedAmount, requiredFutureValue]) {
      if (value.currency != currency) {
        throw ArgumentError(
          'All break-even result currencies must match ${currency.code}.',
        );
      }
      if (value.isNegative) {
        throw ArgumentError.value(
          value,
          'investmentValue',
          'Investment values must not be negative.',
        );
      }
    }
    if (investedAmount != loanPrepayment.appliedPrepayment) {
      throw ArgumentError(
        'Invested amount must equal the prepayment amount actually applied.',
      );
    }
    if (!investedAmount.isPositive) {
      throw ArgumentError.value(
        investedAmount,
        'investedAmount',
        'A positive applied prepayment is required for break-even analysis.',
      );
    }
    if (requiredFutureValue.amount <
        investedAmount.amount + loanPrepayment.interestSaved.amount) {
      throw ArgumentError(
        'Required future value must cover principal and interest saved.',
      );
    }
    if (annualExpenseRatio.isNegative) {
      throw ArgumentError.value(
        annualExpenseRatio,
        'annualExpenseRatio',
        'Annual expense ratio must not be negative.',
      );
    }
    if (investmentHorizonMonths <= 0) {
      throw ArgumentError.value(
        investmentHorizonMonths,
        'investmentHorizonMonths',
        'A positive investment horizon is required.',
      );
    }

    return BreakEvenReturnResult._(
      loanPrepayment: loanPrepayment,
      investedAmount: investedAmount,
      requiredFutureValue: requiredFutureValue,
      annualExpenseRatio: annualExpenseRatio,
      breakEvenNetAnnualReturn: breakEvenNetAnnualReturn,
      breakEvenGrossAnnualReturn: breakEvenGrossAnnualReturn,
      investmentHorizonMonths: investmentHorizonMonths,
    );
  }

  const BreakEvenReturnResult._({
    required this.loanPrepayment,
    required this.investedAmount,
    required this.requiredFutureValue,
    required this.annualExpenseRatio,
    required this.breakEvenNetAnnualReturn,
    required this.breakEvenGrossAnnualReturn,
    required this.investmentHorizonMonths,
  });

  final LoanPrepaymentResult loanPrepayment;
  final Money investedAmount;
  final Money requiredFutureValue;
  final Percentage annualExpenseRatio;
  final Percentage breakEvenNetAnnualReturn;
  final Percentage breakEvenGrossAnnualReturn;
  final int investmentHorizonMonths;

  Money get requiredInvestmentGain => requiredFutureValue - investedAmount;
  Money get interestSaved => loanPrepayment.interestSaved;

  BreakEvenReturnResult copyWith({
    LoanPrepaymentResult? loanPrepayment,
    Money? investedAmount,
    Money? requiredFutureValue,
    Percentage? annualExpenseRatio,
    Percentage? breakEvenNetAnnualReturn,
    Percentage? breakEvenGrossAnnualReturn,
    int? investmentHorizonMonths,
  }) {
    return BreakEvenReturnResult(
      loanPrepayment: loanPrepayment ?? this.loanPrepayment,
      investedAmount: investedAmount ?? this.investedAmount,
      requiredFutureValue: requiredFutureValue ?? this.requiredFutureValue,
      annualExpenseRatio: annualExpenseRatio ?? this.annualExpenseRatio,
      breakEvenNetAnnualReturn:
          breakEvenNetAnnualReturn ?? this.breakEvenNetAnnualReturn,
      breakEvenGrossAnnualReturn:
          breakEvenGrossAnnualReturn ?? this.breakEvenGrossAnnualReturn,
      investmentHorizonMonths:
          investmentHorizonMonths ?? this.investmentHorizonMonths,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BreakEvenReturnResult &&
            loanPrepayment == other.loanPrepayment &&
            investedAmount == other.investedAmount &&
            requiredFutureValue == other.requiredFutureValue &&
            annualExpenseRatio == other.annualExpenseRatio &&
            breakEvenNetAnnualReturn == other.breakEvenNetAnnualReturn &&
            breakEvenGrossAnnualReturn == other.breakEvenGrossAnnualReturn &&
            investmentHorizonMonths == other.investmentHorizonMonths;
  }

  @override
  int get hashCode => Object.hash(
    loanPrepayment,
    investedAmount,
    requiredFutureValue,
    annualExpenseRatio,
    breakEvenNetAnnualReturn,
    breakEvenGrossAnnualReturn,
    investmentHorizonMonths,
  );

  @override
  String toString() {
    return 'BreakEvenReturnResult('
        'investedAmount: $investedAmount, '
        'requiredFutureValue: $requiredFutureValue, '
        'requiredInvestmentGain: $requiredInvestmentGain, '
        'interestSaved: $interestSaved, '
        'annualExpenseRatio: $annualExpenseRatio, '
        'breakEvenNetAnnualReturn: $breakEvenNetAnnualReturn, '
        'breakEvenGrossAnnualReturn: $breakEvenGrossAnnualReturn, '
        'investmentHorizonMonths: $investmentHorizonMonths'
        ')';
  }
}
