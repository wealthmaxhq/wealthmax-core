import 'package:meta/meta.dart';

import '../money/money.dart';

/// Immutable monetary summary produced by a loan calculation.
///
/// Calculation provenance and warnings belong in a
/// `CalculationResult<LoanResult>` wrapper.
@immutable
final class LoanResult {
  factory LoanResult({
    required Money emi,
    required Money totalInterest,
    required Money totalPayment,
  }) {
    _requireNonNegative(emi, 'emi');
    _requireNonNegative(totalInterest, 'totalInterest');
    _requireNonNegative(totalPayment, 'totalPayment');
    _requireSameCurrency(emi, totalInterest, 'totalInterest');
    _requireSameCurrency(emi, totalPayment, 'totalPayment');

    return LoanResult._(
      emi: emi,
      totalInterest: totalInterest,
      totalPayment: totalPayment,
    );
  }

  const LoanResult._({
    required this.emi,
    required this.totalInterest,
    required this.totalPayment,
  });

  /// Periodic installment amount.
  final Money emi;

  /// Interest paid over the complete loan schedule.
  final Money totalInterest;

  /// Sum of all scheduled installments.
  final Money totalPayment;

  LoanResult copyWith({Money? emi, Money? totalInterest, Money? totalPayment}) {
    return LoanResult(
      emi: emi ?? this.emi,
      totalInterest: totalInterest ?? this.totalInterest,
      totalPayment: totalPayment ?? this.totalPayment,
    );
  }

  static void _requireNonNegative(Money value, String fieldName) {
    if (value.isNegative) {
      throw ArgumentError.value(
        value,
        fieldName,
        'Amount must not be negative.',
      );
    }
  }

  static void _requireSameCurrency(
    Money reference,
    Money value,
    String fieldName,
  ) {
    if (reference.currency != value.currency) {
      throw ArgumentError.value(
        value,
        fieldName,
        'Currency must match EMI currency ${reference.currency.code}.',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LoanResult &&
            emi == other.emi &&
            totalInterest == other.totalInterest &&
            totalPayment == other.totalPayment;
  }

  @override
  int get hashCode => Object.hash(emi, totalInterest, totalPayment);

  @override
  String toString() {
    return 'LoanResult('
        'emi: $emi, '
        'totalInterest: $totalInterest, '
        'totalPayment: $totalPayment'
        ')';
  }
}
