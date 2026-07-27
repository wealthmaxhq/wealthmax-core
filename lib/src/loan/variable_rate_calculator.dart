import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../percentage/percentage.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_entry.dart';
import 'amortization_schedule.dart';
import 'emi_calculator.dart';
import 'interest_rate_change.dart';
import 'loan_input.dart';
import 'scheduled_prepayment.dart';
import 'variable_rate_loan_result.dart';
import 'variable_rate_period.dart';

/// Builds a floating-rate schedule by recalculating EMI to retain tenure.
@immutable
final class VariableRateCalculator {
  const VariableRateCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
  });

  static const String formulaId = 'LN-004';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;

  CalculationResult<VariableRateLoanResult> calculate(
    LoanInput input, {
    required InterestRatePlan interestRatePlan,
    required DateTime calculatedAt,
    PrepaymentPlan? prepaymentPlan,
  }) {
    if (calculationScale <= 0) {
      throw ArgumentError.value(
        calculationScale,
        'calculationScale',
        'Must be greater than zero.',
      );
    }

    interestRatePlan.validateForTenure(input.tenureMonths);
    final prepayments = prepaymentPlan ?? PrepaymentPlan.empty();
    prepayments.validateFor(
      currency: input.principal.currency,
      tenureMonths: input.tenureMonths,
    );

    final initialEmi = _calculateEmi(
      principal: input.financedPrincipal,
      annualInterestRate: input.annualInterestRate,
      tenureMonths: input.tenureMonths,
      calculatedAt: calculatedAt,
    );
    final periods = <VariableRatePeriod>[
      VariableRatePeriod(
        effectiveInstallment: 1,
        annualInterestRate: input.annualInterestRate,
        scheduledEmi: initialEmi,
      ),
    ];
    final entries = input.financedPrincipal.isZero
        ? const <AmortizationEntry>[]
        : _buildEntries(
            input,
            interestRatePlan: interestRatePlan,
            prepaymentPlan: prepayments,
            periods: periods,
            initialEmi: initialEmi,
            calculatedAt: calculatedAt,
          );
    final schedule = AmortizationSchedule(
      scheduledEmi: initialEmi,
      financedPrincipal: input.financedPrincipal,
      entries: entries,
    );
    final result = VariableRateLoanResult(schedule: schedule, periods: periods);

    return CalculationResult<VariableRateLoanResult>(
      value: result,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'principal': input.principal.amount.toString(),
          'currency': input.principal.currency.code,
          'initialAnnualInterestRatePercent': input.annualInterestRate.percent
              .toString(),
          'tenureMonths': input.tenureMonths,
          'rateChanges': interestRatePlan.changes
              .map(
                (change) => <String, Object?>{
                  'effectiveInstallment': change.effectiveInstallment,
                  'annualInterestRatePercent': change.annualInterestRate.percent
                      .toString(),
                },
              )
              .toList(growable: false),
        },
        assumptions: <String, Object?>{
          'rateChangeTiming': 'beforeInstallmentInterest',
          'rateChangeEffect': 'recalculateEmiKeepRemainingTenure',
          'prepaymentTiming': 'afterScheduledInstallment',
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'emiFormulaId': EmiCalculator.formulaId,
          'appliedRatePeriods': periods
              .map(
                (period) => <String, Object?>{
                  'effectiveInstallment': period.effectiveInstallment,
                  'annualInterestRatePercent': period.annualInterestRate.percent
                      .toString(),
                  'scheduledEmi': period.scheduledEmi.amount.toString(),
                },
              )
              .toList(growable: false),
          'paymentCount': schedule.paymentCount,
          'totalInterest': schedule.totalInterest.amount.toString(),
          'totalPayment': schedule.totalPayment.amount.toString(),
          'totalPrepayment': schedule.totalPrepayment.amount.toString(),
        },
      ),
    );
  }

  List<AmortizationEntry> _buildEntries(
    LoanInput input, {
    required InterestRatePlan interestRatePlan,
    required PrepaymentPlan prepaymentPlan,
    required List<VariableRatePeriod> periods,
    required Money initialEmi,
    required DateTime calculatedAt,
  }) {
    final currency = input.principal.currency;
    final decimalPlaces = currency.decimalPlaces;
    final entries = <AmortizationEntry>[];
    var openingBalance = input.financedPrincipal;
    var activeRate = input.annualInterestRate;
    var scheduledEmi = initialEmi;

    for (
      var installmentNumber = 1;
      installmentNumber <= input.tenureMonths;
      installmentNumber++
    ) {
      final rateChange = interestRatePlan.changeAt(installmentNumber);
      if (rateChange != null) {
        activeRate = rateChange.annualInterestRate;
        scheduledEmi = _calculateEmi(
          principal: openingBalance,
          annualInterestRate: activeRate,
          tenureMonths: input.tenureMonths - installmentNumber + 1,
          calculatedAt: calculatedAt,
        );
        periods.add(
          VariableRatePeriod(
            effectiveInstallment: installmentNumber,
            annualInterestRate: activeRate,
            scheduledEmi: scheduledEmi,
          ),
        );
      }

      final monthlyRate = (activeRate.fraction / Decimal.fromInt(12)).toDecimal(
        scaleOnInfinitePrecision: calculationScale,
      );
      final interest = Money(
        amount: roundingPolicy.round(
          openingBalance.amount * monthlyRate,
          decimalPlaces: decimalPlaces,
        ),
        currency: currency,
      );
      final payoffAmount = openingBalance + interest;
      final isFinalInstallment = installmentNumber == input.tenureMonths;
      final payment =
          isFinalInstallment || scheduledEmi.compareTo(payoffAmount) >= 0
          ? payoffAmount
          : scheduledEmi;
      final principal = payment - interest;
      if (!principal.isPositive) {
        throw StateError(
          'Recalculated EMI does not cover installment interest; '
          'the loan would negatively amortize.',
        );
      }

      final balanceAfterPayment = openingBalance - principal;
      final requestedPrepayment = prepaymentPlan.totalForInstallment(
        installmentNumber,
        currency,
      );
      final appliedPrepayment =
          requestedPrepayment.compareTo(balanceAfterPayment) > 0
          ? balanceAfterPayment
          : requestedPrepayment;
      final closingBalance = balanceAfterPayment - appliedPrepayment;
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

    return entries;
  }

  Money _calculateEmi({
    required Money principal,
    required Percentage annualInterestRate,
    required int tenureMonths,
    required DateTime calculatedAt,
  }) {
    if (principal.isZero) return Money.zero(principal.currency);
    return EmiCalculator(
          roundingPolicy: roundingPolicy,
          calculationScale: calculationScale,
        )
        .calculate(
          LoanInput(
            principal: principal,
            annualInterestRate: annualInterestRate,
            tenureMonths: tenureMonths,
          ),
          calculatedAt: calculatedAt,
        )
        .value
        .emi;
  }
}
