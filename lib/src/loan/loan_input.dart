import 'package:meta/meta.dart';

import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable inputs shared by reducing-balance loan calculations.
///
/// Monetary charges must use the same currency as [principal]. Construction
/// fails immediately when an input cannot describe a valid loan.
@immutable
final class LoanInput {
  /// Maximum supported loan term: 100 years of monthly installments.
  static const int maximumTenureMonths = 1200;

  factory LoanInput({
    required Money principal,
    required Percentage annualInterestRate,
    required int tenureMonths,
    Money? processingFee,
    Money? prepayment,
  }) {
    if (!principal.isPositive) {
      throw ArgumentError.value(
        principal,
        'principal',
        'Principal must be greater than zero.',
      );
    }
    if (annualInterestRate.isNegative) {
      throw ArgumentError.value(
        annualInterestRate,
        'annualInterestRate',
        'Annual interest rate must not be negative.',
      );
    }
    if (tenureMonths <= 0) {
      throw ArgumentError.value(
        tenureMonths,
        'tenureMonths',
        'Tenure must be greater than zero months.',
      );
    }
    if (tenureMonths > maximumTenureMonths) {
      throw ArgumentError.value(
        tenureMonths,
        'tenureMonths',
        'Tenure must not exceed $maximumTenureMonths months.',
      );
    }

    _validateOptionalMoney(
      value: processingFee,
      fieldName: 'processingFee',
      principal: principal,
    );
    _validateOptionalMoney(
      value: prepayment,
      fieldName: 'prepayment',
      principal: principal,
    );
    if (prepayment != null && prepayment.compareTo(principal) > 0) {
      throw ArgumentError.value(
        prepayment,
        'prepayment',
        'Prepayment must not exceed principal.',
      );
    }

    return LoanInput._(
      principal: principal,
      annualInterestRate: annualInterestRate,
      tenureMonths: tenureMonths,
      processingFee: processingFee,
      prepayment: prepayment,
    );
  }

  const LoanInput._({
    required this.principal,
    required this.annualInterestRate,
    required this.tenureMonths,
    required this.processingFee,
    required this.prepayment,
  });

  /// Original amount borrowed.
  final Money principal;

  /// Nominal annual interest rate expressed in percentage points.
  final Percentage annualInterestRate;

  /// Number of scheduled monthly installments.
  final int tenureMonths;

  /// Optional up-front lender processing charge.
  final Money? processingFee;

  /// Optional amount applied to principal before a calculation.
  final Money? prepayment;

  /// Principal remaining after applying [prepayment].
  Money get financedPrincipal =>
      principal - (prepayment ?? Money.zero(principal.currency));

  LoanInput copyWith({
    Money? principal,
    Percentage? annualInterestRate,
    int? tenureMonths,
    Object? processingFee = _unset,
    Object? prepayment = _unset,
  }) {
    return LoanInput(
      principal: principal ?? this.principal,
      annualInterestRate: annualInterestRate ?? this.annualInterestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      processingFee: identical(processingFee, _unset)
          ? this.processingFee
          : processingFee as Money?,
      prepayment: identical(prepayment, _unset)
          ? this.prepayment
          : prepayment as Money?,
    );
  }

  static const Object _unset = Object();

  static void _validateOptionalMoney({
    required Money? value,
    required String fieldName,
    required Money principal,
  }) {
    if (value == null) return;
    if (value.currency != principal.currency) {
      throw ArgumentError.value(
        value,
        fieldName,
        'Currency must match principal currency ${principal.currency.code}.',
      );
    }
    if (value.isNegative) {
      throw ArgumentError.value(
        value,
        fieldName,
        'Amount must not be negative.',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LoanInput &&
            principal == other.principal &&
            annualInterestRate == other.annualInterestRate &&
            tenureMonths == other.tenureMonths &&
            processingFee == other.processingFee &&
            prepayment == other.prepayment;
  }

  @override
  int get hashCode => Object.hash(
    principal,
    annualInterestRate,
    tenureMonths,
    processingFee,
    prepayment,
  );

  @override
  String toString() {
    return 'LoanInput('
        'principal: $principal, '
        'annualInterestRate: $annualInterestRate, '
        'tenureMonths: $tenureMonths, '
        'processingFee: $processingFee, '
        'prepayment: $prepayment'
        ')';
  }
}
