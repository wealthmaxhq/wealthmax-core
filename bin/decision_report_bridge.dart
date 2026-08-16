import 'dart:convert';
import 'dart:io';

import 'package:wealthmax_core/wealthmax_core.dart';

Future<void> main() async {
  try {
    final request = _map(
      jsonDecode(await stdin.transform(utf8.decoder).join()),
      'request',
    );
    final calculatedAt = DateTime.parse(
      _string(request['calculatedAt'], 'calculatedAt'),
    );
    final input = _reportInput(_map(request['report'], 'report'));
    final report = const DecisionAnalysisReportCalculator().calculate(
      input,
      calculatedAt: calculatedAt,
    );
    final snapshot = const DecisionAnalysisReportSnapshotCalculator().calculate(
      report,
      calculatedAt: calculatedAt,
    );
    stdout.write(snapshot.value.encode());
  } on Object catch (error) {
    stderr.write(
      jsonEncode(<String, Object?>{
        'error': 'invalid_decision_report',
        'message': error.toString(),
      }),
    );
    exitCode = 64;
  }
}

DecisionAnalysisReportInput _reportInput(Map<String, Object?> value) {
  final cases = _list(value['cases'], 'report.cases');
  return DecisionAnalysisReportInput(
    title: _string(value['title'], 'report.title'),
    cases: cases.indexed.map(
      (entry) =>
          _caseInput(_map(entry.$2, 'report.cases[${entry.$1}]'), entry.$1),
    ),
  );
}

DecisionAnalysisCaseInput _caseInput(Map<String, Object?> value, int index) {
  final field = 'report.cases[$index]';
  final currency = Currencies.fromCode(
    _string(value['currency'], '$field.currency'),
  );
  final loanValue = _map(value['loan'], '$field.loan');
  final loan = LoanInput(
    principal: _money(
      loanValue['principal'],
      currency,
      '$field.loan.principal',
    ),
    annualInterestRate: _percentage(
      loanValue['annualInterestRatePercent'],
      '$field.loan.annualInterestRatePercent',
    ),
    tenureMonths: _integer(
      loanValue['tenureMonths'],
      '$field.loan.tenureMonths',
    ),
    processingFee: _optionalMoney(
      loanValue['processingFee'],
      currency,
      '$field.loan.processingFee',
    ),
    prepayment: _optionalMoney(
      loanValue['prepayment'],
      currency,
      '$field.loan.prepayment',
    ),
  );
  final strategy = HybridStrategyInput(
    loan: loan,
    extraCash: _money(value['extraCash'], currency, '$field.extraCash'),
    decisionInstallment: _integer(
      value['decisionInstallment'],
      '$field.decisionInstallment',
    ),
    grossAnnualInvestmentReturn: _percentage(
      value['grossAnnualInvestmentReturnPercent'],
      '$field.grossAnnualInvestmentReturnPercent',
    ),
    annualExpenseRatio: _percentage(
      value['annualExpenseRatioPercent'],
      '$field.annualExpenseRatioPercent',
    ),
    allocationStepPercent: _integer(
      value['allocationStepPercent'],
      '$field.allocationStepPercent',
    ),
  );
  final objectiveName = _string(value['objective'], '$field.objective');
  final objective = CommonHorizonStrategyObjective.values
      .where((candidate) => candidate.name == objectiveName)
      .firstOrNull;
  if (objective == null) {
    throw FormatException('Unsupported $field.objective: $objectiveName.');
  }
  final scenarios = _list(
    value['grossAnnualReturnScenariosPercent'],
    '$field.grossAnnualReturnScenariosPercent',
  );

  return DecisionAnalysisCaseInput(
    id: _string(value['id'], '$field.id'),
    label: _string(value['label'], '$field.label'),
    analysis: AdjustedDecisionAnalysisInput(
      analysis: CommonHorizonDecisionAnalysisInput(
        selection: CommonHorizonStrategySelectionInput(
          hybridStrategy: strategy,
          objective: objective,
        ),
        grossAnnualReturnScenarios: scenarios.indexed.map(
          (entry) => _percentage(
            entry.$2,
            '$field.grossAnnualReturnScenariosPercent[${entry.$1}]',
          ),
        ),
      ),
      investmentGainTaxRate: _percentage(
        value['investmentGainTaxRatePercent'],
        '$field.investmentGainTaxRatePercent',
      ),
      annualInflationRate: _percentage(
        value['annualInflationRatePercent'],
        '$field.annualInflationRatePercent',
      ),
    ),
  );
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return value.map(
    (key, nested) => MapEntry(_string(key, '$field key'), nested),
  );
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an array.');
  return value;
}

String _string(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value;
}

int _integer(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer.');
  return value;
}

Money _money(Object? value, Currency currency, String field) =>
    Money.parse(_string(value, field), currency: currency);

Money? _optionalMoney(Object? value, Currency currency, String field) =>
    value == null ? null : _money(value, currency, field);

Percentage _percentage(Object? value, String field) =>
    Percentage.fromPercent(_string(value, field));
