import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../loan/loan_input.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';

/// Immutable scenario grid for prepay-versus-invest sensitivity analysis.
@immutable
final class ReturnSensitivityInput {
  factory ReturnSensitivityInput({
    required LoanInput loan,
    required Money extraCash,
    required int decisionInstallment,
    required Percentage annualExpenseRatio,
    required Iterable<Percentage> grossAnnualReturnScenarios,
  }) {
    if (!extraCash.isPositive) {
      throw ArgumentError.value(
        extraCash,
        'extraCash',
        'Extra cash must be greater than zero.',
      );
    }
    if (extraCash.currency != loan.principal.currency) {
      throw ArgumentError.value(
        extraCash,
        'extraCash',
        'Currency must match loan currency ${loan.principal.currency.code}.',
      );
    }
    if (decisionInstallment <= 0 || decisionInstallment > loan.tenureMonths) {
      throw ArgumentError.value(
        decisionInstallment,
        'decisionInstallment',
        'Decision installment must be within the contractual loan tenure.',
      );
    }
    if (annualExpenseRatio.isNegative ||
        annualExpenseRatio.percent >= Decimal.fromInt(100)) {
      throw ArgumentError.value(
        annualExpenseRatio,
        'annualExpenseRatio',
        'Annual expense ratio must be at least 0% and less than 100%.',
      );
    }

    final scenarios = List<Percentage>.of(grossAnnualReturnScenarios)
      ..sort((first, second) => first.compareTo(second));
    if (scenarios.isEmpty) {
      throw ArgumentError.value(
        scenarios,
        'grossAnnualReturnScenarios',
        'At least one return scenario is required.',
      );
    }
    if (scenarios.length > maximumScenarios) {
      throw ArgumentError.value(
        scenarios.length,
        'grossAnnualReturnScenarios',
        'No more than $maximumScenarios scenarios are allowed.',
      );
    }
    for (var index = 0; index < scenarios.length; index++) {
      if (scenarios[index].percent < Decimal.fromInt(-100)) {
        throw ArgumentError.value(
          scenarios[index],
          'grossAnnualReturnScenarios',
          'Return scenarios must not be less than -100%.',
        );
      }
      if (index > 0 && scenarios[index] == scenarios[index - 1]) {
        throw ArgumentError.value(
          scenarios[index],
          'grossAnnualReturnScenarios',
          'Return scenarios must be unique.',
        );
      }
    }

    return ReturnSensitivityInput._(
      loan: loan,
      extraCash: extraCash,
      decisionInstallment: decisionInstallment,
      annualExpenseRatio: annualExpenseRatio,
      grossAnnualReturnScenarios: UnmodifiableListView(scenarios),
    );
  }

  const ReturnSensitivityInput._({
    required this.loan,
    required this.extraCash,
    required this.decisionInstallment,
    required this.annualExpenseRatio,
    required this.grossAnnualReturnScenarios,
  });

  static const int maximumScenarios = 101;

  final LoanInput loan;
  final Money extraCash;
  final int decisionInstallment;
  final Percentage annualExpenseRatio;
  final List<Percentage> grossAnnualReturnScenarios;

  ReturnSensitivityInput copyWith({
    LoanInput? loan,
    Money? extraCash,
    int? decisionInstallment,
    Percentage? annualExpenseRatio,
    Iterable<Percentage>? grossAnnualReturnScenarios,
  }) {
    return ReturnSensitivityInput(
      loan: loan ?? this.loan,
      extraCash: extraCash ?? this.extraCash,
      decisionInstallment: decisionInstallment ?? this.decisionInstallment,
      annualExpenseRatio: annualExpenseRatio ?? this.annualExpenseRatio,
      grossAnnualReturnScenarios:
          grossAnnualReturnScenarios ?? this.grossAnnualReturnScenarios,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReturnSensitivityInput &&
            loan == other.loan &&
            extraCash == other.extraCash &&
            decisionInstallment == other.decisionInstallment &&
            annualExpenseRatio == other.annualExpenseRatio &&
            _listsEqual(
              grossAnnualReturnScenarios,
              other.grossAnnualReturnScenarios,
            );
  }

  @override
  int get hashCode => Object.hash(
    loan,
    extraCash,
    decisionInstallment,
    annualExpenseRatio,
    Object.hashAll(grossAnnualReturnScenarios),
  );

  static bool _listsEqual(List<Object> first, List<Object> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'ReturnSensitivityInput('
        'loan: $loan, '
        'extraCash: $extraCash, '
        'decisionInstallment: $decisionInstallment, '
        'annualExpenseRatio: $annualExpenseRatio, '
        'grossAnnualReturnScenarios: $grossAnnualReturnScenarios'
        ')';
  }
}
