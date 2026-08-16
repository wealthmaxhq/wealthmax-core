import 'package:meta/meta.dart';

import '../loan/loan_prepayment_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';

/// The numerically favored option under the supplied deterministic assumptions.
enum OpportunityCostPreference { prepay, invest, equivalent }

/// Immutable outcome of a one-time prepay-versus-invest comparison.
@immutable
final class OpportunityCostResult {
  factory OpportunityCostResult({
    required LoanPrepaymentResult loanPrepayment,
    required Money investedAmount,
    required Money investmentFutureValue,
    required Percentage netAnnualInvestmentReturn,
    required int investmentHorizonMonths,
  }) {
    final currency = loanPrepayment.baseline.financedPrincipal.currency;
    for (final value in <Money>[investedAmount, investmentFutureValue]) {
      if (value.currency != currency) {
        throw ArgumentError(
          'All opportunity-cost result currencies must match $currency.',
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
    if (investmentHorizonMonths < 0) {
      throw ArgumentError.value(
        investmentHorizonMonths,
        'investmentHorizonMonths',
        'Investment horizon must not be negative.',
      );
    }

    return OpportunityCostResult._(
      loanPrepayment: loanPrepayment,
      investedAmount: investedAmount,
      investmentFutureValue: investmentFutureValue,
      netAnnualInvestmentReturn: netAnnualInvestmentReturn,
      investmentHorizonMonths: investmentHorizonMonths,
    );
  }

  const OpportunityCostResult._({
    required this.loanPrepayment,
    required this.investedAmount,
    required this.investmentFutureValue,
    required this.netAnnualInvestmentReturn,
    required this.investmentHorizonMonths,
  });

  final LoanPrepaymentResult loanPrepayment;
  final Money investedAmount;
  final Money investmentFutureValue;
  final Percentage netAnnualInvestmentReturn;
  final int investmentHorizonMonths;

  Money get interestSaved => loanPrepayment.interestSaved;
  Money get investmentGain => investmentFutureValue - investedAmount;

  /// Positive means investing produces more nominal gain; negative means
  /// prepayment saves more nominal interest.
  Money get nominalAdvantage => investmentGain - interestSaved;

  OpportunityCostPreference get preferredOption {
    if (nominalAdvantage.isPositive) return OpportunityCostPreference.invest;
    if (nominalAdvantage.isNegative) return OpportunityCostPreference.prepay;
    return OpportunityCostPreference.equivalent;
  }

  OpportunityCostResult copyWith({
    LoanPrepaymentResult? loanPrepayment,
    Money? investedAmount,
    Money? investmentFutureValue,
    Percentage? netAnnualInvestmentReturn,
    int? investmentHorizonMonths,
  }) {
    return OpportunityCostResult(
      loanPrepayment: loanPrepayment ?? this.loanPrepayment,
      investedAmount: investedAmount ?? this.investedAmount,
      investmentFutureValue:
          investmentFutureValue ?? this.investmentFutureValue,
      netAnnualInvestmentReturn:
          netAnnualInvestmentReturn ?? this.netAnnualInvestmentReturn,
      investmentHorizonMonths:
          investmentHorizonMonths ?? this.investmentHorizonMonths,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OpportunityCostResult &&
            loanPrepayment == other.loanPrepayment &&
            investedAmount == other.investedAmount &&
            investmentFutureValue == other.investmentFutureValue &&
            netAnnualInvestmentReturn == other.netAnnualInvestmentReturn &&
            investmentHorizonMonths == other.investmentHorizonMonths;
  }

  @override
  int get hashCode => Object.hash(
    loanPrepayment,
    investedAmount,
    investmentFutureValue,
    netAnnualInvestmentReturn,
    investmentHorizonMonths,
  );

  @override
  String toString() {
    return 'OpportunityCostResult('
        'investedAmount: $investedAmount, '
        'investmentFutureValue: $investmentFutureValue, '
        'investmentGain: $investmentGain, '
        'interestSaved: $interestSaved, '
        'nominalAdvantage: $nominalAdvantage, '
        'preferredOption: ${preferredOption.name}, '
        'netAnnualInvestmentReturn: $netAnnualInvestmentReturn, '
        'investmentHorizonMonths: $investmentHorizonMonths'
        ')';
  }
}
