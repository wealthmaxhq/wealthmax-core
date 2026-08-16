import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 8, 6, 12);

  LoanInput loan({String rate = '10', Currency currency = Currencies.inr}) {
    return LoanInput(
      principal: Money.parse('100000', currency: currency),
      annualInterestRate: Percentage.fromPercent(rate),
      tenureMonths: 24,
    );
  }

  ReturnSensitivityInput input({
    LoanInput? loanInput,
    String expenseRatio = '1',
    List<String> scenarios = const <String>['0', '8', '12', '20'],
  }) {
    final selectedLoan = loanInput ?? loan();
    return ReturnSensitivityInput(
      loan: selectedLoan,
      extraCash: Money.parse(
        '10000',
        currency: selectedLoan.principal.currency,
      ),
      decisionInstallment: 1,
      annualExpenseRatio: Percentage.fromPercent(expenseRatio),
      grossAnnualReturnScenarios: scenarios.map(Percentage.fromPercent),
    );
  }

  group('ReturnSensitivityInput', () {
    test('sorts and defensively copies unique scenarios', () {
      final source = <Percentage>[
        Percentage.fromPercent('20'),
        Percentage.fromPercent('0'),
        Percentage.fromPercent('10'),
      ];
      final value = ReturnSensitivityInput(
        loan: loan(),
        extraCash: Money.parse('10000', currency: Currencies.inr),
        decisionInstallment: 1,
        annualExpenseRatio: Percentage.fromPercent('1'),
        grossAnnualReturnScenarios: source,
      );
      source.add(Percentage.fromPercent('30'));

      expect(value.grossAnnualReturnScenarios, <Percentage>[
        Percentage.fromPercent('0'),
        Percentage.fromPercent('10'),
        Percentage.fromPercent('20'),
      ]);
      expect(
        () =>
            value.grossAnnualReturnScenarios.add(Percentage.fromPercent('30')),
        throwsUnsupportedError,
      );
    });

    test('rejects empty, duplicate, invalid, or excessive scenarios', () {
      expect(() => input(scenarios: const <String>[]), throwsArgumentError);
      expect(
        () => input(scenarios: const <String>['10', '10']),
        throwsArgumentError,
      );
      expect(
        () => input(scenarios: const <String>['-100.01']),
        throwsArgumentError,
      );
      expect(
        () => input(scenarios: List<String>.generate(102, (index) => '$index')),
        throwsArgumentError,
      );
    });

    test('supports copyWith, equality, hashing, and output', () {
      final original = input();
      final changed = original.copyWith(
        grossAnnualReturnScenarios: <Percentage>[Percentage.fromPercent('5')],
      );
      final expected = original.copyWith(
        grossAnnualReturnScenarios: <Percentage>[Percentage.fromPercent('5')],
      );

      expect(changed, expected);
      expect(changed.hashCode, expected.hashCode);
      expect(changed.toString(), contains('grossAnnualReturnScenarios'));
    });
  });

  group('ReturnSensitivityCalculator', () {
    test('classifies zero-rate loan around a zero-return threshold', () {
      final result = const ReturnSensitivityCalculator()
          .calculate(
            input(
              loanInput: loan(rate: '0'),
              expenseRatio: '0',
              scenarios: const <String>['-1', '0', '1'],
            ),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(
        result.points.map((point) => point.preferredOption),
        <OpportunityCostPreference>[
          OpportunityCostPreference.prepay,
          OpportunityCostPreference.equivalent,
          OpportunityCostPreference.invest,
        ],
      );
      expect(result.prepayScenarioCount, 1);
      expect(result.equivalentScenarioCount, 1);
      expect(result.investScenarioCount, 1);
    });

    test('nominal advantage increases monotonically with return', () {
      final result = const ReturnSensitivityCalculator()
          .calculate(input(), calculatedAt: calculatedAt)
          .value;

      for (var index = 1; index < result.points.length; index++) {
        expect(
          result.points[index].nominalAdvantage.compareTo(
            result.points[index - 1].nominalAdvantage,
          ),
          greaterThan(0),
        );
      }
    });

    test('first invest scenario is the lowest evaluated investing return', () {
      final result = const ReturnSensitivityCalculator()
          .calculate(
            input(scenarios: const <String>['0', '5', '10', '15', '20']),
            calculatedAt: calculatedAt,
          )
          .value;
      final investingPoints = result.points.where(
        (point) => point.preferredOption == OpportunityCostPreference.invest,
      );

      expect(result.firstInvestScenario, investingPoints.first);
    });

    test('reports no first invest scenario when all favor prepayment', () {
      final result = const ReturnSensitivityCalculator()
          .calculate(
            input(scenarios: const <String>['-10', '0']),
            calculatedAt: calculatedAt,
          )
          .value;

      expect(result.firstInvestScenario, isNull);
      expect(result.investScenarioCount, 0);
    });

    test('break-even threshold lies between adjacent crossover scenarios', () {
      const calculator = ReturnSensitivityCalculator();
      final result = calculator
          .calculate(
            input(scenarios: const <String>['0', '5', '10', '15', '20']),
            calculatedAt: calculatedAt,
          )
          .value;
      final firstInvest = result.firstInvestScenario!;
      final firstInvestIndex = result.points.indexOf(firstInvest);
      final previous = result.points[firstInvestIndex - 1];

      expect(
        previous.grossAnnualReturn.compareTo(
          result.breakEven.breakEvenGrossAnnualReturn,
        ),
        lessThanOrEqualTo(0),
      );
      expect(
        firstInvest.grossAnnualReturn.compareTo(
          result.breakEven.breakEvenGrossAnnualReturn,
        ),
        greaterThanOrEqualTo(0),
      );
    });

    test('higher fee moves the break-even threshold upward', () {
      const calculator = ReturnSensitivityCalculator();
      final noFee = calculator.calculate(
        input(expenseRatio: '0'),
        calculatedAt: calculatedAt,
      );
      final highFee = calculator.calculate(
        input(expenseRatio: '2'),
        calculatedAt: calculatedAt,
      );

      expect(
        highFee.value.breakEven.breakEvenGrossAnnualReturn.compareTo(
          noFee.value.breakEven.breakEvenGrossAnnualReturn,
        ),
        greaterThan(0),
      );
    });

    test('preserves another currency', () {
      final result = const ReturnSensitivityCalculator().calculate(
        input(loanInput: loan(currency: Currencies.usd)),
        calculatedAt: calculatedAt,
      );

      expect(result.value.breakEven.investedAmount.currency, Currencies.usd);
      expect(
        result.value.points.first.nominalAdvantage.currency,
        Currencies.usd,
      );
    });

    test('returns transparent OPT-003 metadata and limitations', () {
      final result = const ReturnSensitivityCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.metadata.formulaId, 'OPT-003');
      expect(result.metadata.formulaVersion, '1.0.0');
      expect(result.metadata.calculatedAt, calculatedAt);
      expect(result.metadata.details['scenarioCount'], 4);
      expect(
        result.metadata.assumptions['breakEvenFormulaId'],
        BreakEvenReturnCalculator.formulaId,
      );
      expect(
        result.metadata.assumptions['comparisonFormulaId'],
        OpportunityCostCalculator.formulaId,
      );
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll(<String>[
          'OPT-003-SCENARIOS-NOT-PROBABILITIES',
          'OPT-003-TAX-INFLATION-RISK-EXCLUDED',
        ]),
      );
    });

    test('supports result semantics and deterministic calculation', () {
      const calculator = ReturnSensitivityCalculator();
      final value = input();
      final first = calculator.calculate(value, calculatedAt: calculatedAt);
      final second = calculator.calculate(value, calculatedAt: calculatedAt);

      expect(first, second);
      expect(first.value.hashCode, second.value.hashCode);
      expect(first.value.toString(), contains('prepayScenarioCount'));
      expect(first.value.points.first.toString(), contains('nominalAdvantage'));
    });

    test('scenario advantage is exact Money in the loan currency', () {
      final result = const ReturnSensitivityCalculator().calculate(
        input(),
        calculatedAt: calculatedAt,
      );

      expect(result.value.points.first.nominalAdvantage.amount, isA<Decimal>());
      expect(
        result.value.points.first.nominalAdvantage.currency,
        Currencies.inr,
      );
    });
  });
}
