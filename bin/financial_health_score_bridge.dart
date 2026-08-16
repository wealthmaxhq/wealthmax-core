import 'dart:convert';
import 'dart:io';

import 'package:wealthmax_core/wealthmax_core.dart';

Future<void> main() async {
  try {
    final value = _map(jsonDecode(await stdin.transform(utf8.decoder).join()));
    final currency = Currencies.fromCode(_string(value, 'currency'));
    Money money(String field) =>
        Money.parse(_string(value, field), currency: currency);
    final result = const FinancialHealthScoreCalculator().calculate(
      FinancialHealthScoreInput(
        liquidSavings: money('liquidSavings'),
        monthlyNetIncome: money('monthlyNetIncome'),
        monthlyEssentialExpenses: money('monthlyEssentialExpenses'),
        monthlyDebtPayments: money('monthlyDebtPayments'),
        monthlySavings: money('monthlySavings'),
      ),
    );
    stdout.write(
      jsonEncode(<String, Object>{
        'apiVersion': 'v1',
        'score': result.score,
        'rating': result.rating.name,
        'componentScores': <String, int>{
          'emergencyFund': result.emergencyFundScore,
          'debtBurden': result.debtBurdenScore,
          'savingsRate': result.savingsRateScore,
        },
        'metrics': <String, String>{
          'emergencyFundMonths': result.emergencyFundMonths.toString(),
          'debtToIncomePercent': result.debtToIncomePercent.toString(),
          'savingsRatePercent': result.savingsRatePercent.toString(),
        },
        'findings': result.findings.map((finding) => finding.name).toList(),
      }),
    );
  } on Object catch (error) {
    stderr.write(jsonEncode(<String, String>{'message': error.toString()}));
    exitCode = 64;
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException('Request must be an object.');
  return value.map((key, nested) => MapEntry(key.toString(), nested));
}

String _string(Map<String, Object?> value, String field) {
  final nested = value[field];
  if (nested is! String || nested.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return nested;
}
