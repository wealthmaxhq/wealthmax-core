import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../calculation/calculation_result.dart';
import '../money/money.dart';
import '../rounding/rounding_policy.dart';
import 'amortization_calculator.dart';
import 'amortization_entry.dart';
import 'amortization_schedule.dart';
import 'emi_change_result.dart';
import 'emi_payment_period.dart';
import 'loan_input.dart';
import 'scheduled_emi_change.dart';
import 'scheduled_prepayment.dart';

/// Applies explicit EMI replacements, allowing tenure to shorten or extend.
@immutable
final class EmiChangeCalculator {
  const EmiChangeCalculator({
    this.roundingPolicy = RoundingPolicy.halfUp,
    this.calculationScale = 32,
    this.maxInstallments = 1200,
  }) : assert(calculationScale > 0),
       assert(maxInstallments > 0);

  static const String formulaId = 'LN-005';
  static const String formulaVersion = '1.0.0';

  final RoundingPolicy roundingPolicy;
  final int calculationScale;

  /// Safety limit that prevents a reduced EMI from creating an endless loan.
  final int maxInstallments;

  CalculationResult<EmiChangeResult> calculate(
    LoanInput input, {
    required EmiChangePlan emiChangePlan,
    required DateTime calculatedAt,
    PrepaymentPlan? prepaymentPlan,
  }) {
    if (maxInstallments < input.tenureMonths) {
      throw ArgumentError.value(
        maxInstallments,
        'maxInstallments',
        'Calculation limit must cover contractual tenure.',
      );
    }
    emiChangePlan.validateFor(
      currency: input.principal.currency,
      maxInstallments: maxInstallments,
    );
    final prepayments = prepaymentPlan ?? PrepaymentPlan.empty();
    prepayments.validateFor(
      currency: input.principal.currency,
      tenureMonths: maxInstallments,
    );
    final baseline =
        AmortizationCalculator(
              roundingPolicy: roundingPolicy,
              calculationScale: calculationScale,
            )
            .calculate(
              input,
              calculatedAt: calculatedAt,
              prepaymentPlan: prepayments,
            )
            .value;
    final initialEmi = baseline.scheduledEmi;
    final periods = <EmiPaymentPeriod>[
      EmiPaymentPeriod(effectiveInstallment: 1, scheduledEmi: initialEmi),
    ];

    final strategy = input.financedPrincipal.isZero
        ? baseline
        : emiChangePlan.isEmpty
        ? baseline
        : AmortizationSchedule(
            scheduledEmi: initialEmi,
            financedPrincipal: input.financedPrincipal,
            entries: _buildEntries(
              input,
              emiChangePlan: emiChangePlan,
              prepaymentPlan: prepayments,
              periods: periods,
              initialEmi: initialEmi,
            ),
          );
    final result = EmiChangeResult(
      baseline: baseline,
      strategy: strategy,
      periods: periods,
    );

    return CalculationResult<EmiChangeResult>(
      value: result,
      metadata: CalculationMetadata(
        formulaId: formulaId,
        formulaVersion: formulaVersion,
        calculatedAt: calculatedAt.toUtc(),
        inputs: <String, Object?>{
          'principal': input.principal.amount.toString(),
          'currency': input.principal.currency.code,
          'annualInterestRatePercent': input.annualInterestRate.percent
              .toString(),
          'contractualTenureMonths': input.tenureMonths,
          'emiChanges': emiChangePlan.changes
              .map(
                (change) => <String, Object?>{
                  'effectiveInstallment': change.effectiveInstallment,
                  'newEmi': change.newEmi.amount.toString(),
                },
              )
              .toList(growable: false),
        },
        assumptions: <String, Object?>{
          'emiChangeTiming': 'beforeInstallmentPayment',
          'emiChangeEffect': 'changeTenure',
          'prepaymentTiming': 'afterScheduledInstallment',
          'roundingPolicy': roundingPolicy.name,
        },
        details: <String, Object?>{
          'baselinePaymentCount': baseline.paymentCount,
          'strategyPaymentCount': strategy.paymentCount,
          'installmentDifference': result.installmentDifference,
          'interestDifference': result.interestDifference.amount.toString(),
          'maxInstallments': maxInstallments,
          'appliedEmiPeriods': periods
              .map(
                (period) => <String, Object?>{
                  'effectiveInstallment': period.effectiveInstallment,
                  'scheduledEmi': period.scheduledEmi.amount.toString(),
                },
              )
              .toList(growable: false),
        },
      ),
    );
  }

  List<AmortizationEntry> _buildEntries(
    LoanInput input, {
    required EmiChangePlan emiChangePlan,
    required PrepaymentPlan prepaymentPlan,
    required List<EmiPaymentPeriod> periods,
    required Money initialEmi,
  }) {
    final currency = input.principal.currency;
    final decimalPlaces = currency.decimalPlaces;
    final monthlyRate =
        (input.annualInterestRate.fraction / Decimal.fromInt(12)).toDecimal(
          scaleOnInfinitePrecision: calculationScale,
        );
    final entries = <AmortizationEntry>[];
    var openingBalance = input.financedPrincipal;
    var scheduledEmi = initialEmi;

    for (
      var installmentNumber = 1;
      installmentNumber <= maxInstallments;
      installmentNumber++
    ) {
      final change = emiChangePlan.changeAt(installmentNumber);
      if (change != null) {
        scheduledEmi = change.newEmi;
        periods.add(
          EmiPaymentPeriod(
            effectiveInstallment: installmentNumber,
            scheduledEmi: scheduledEmi,
          ),
        );
      }
      final interest = Money(
        amount: roundingPolicy.round(
          openingBalance.amount * monthlyRate,
          decimalPlaces: decimalPlaces,
        ),
        currency: currency,
      );
      if (scheduledEmi.compareTo(interest) <= 0) {
        throw StateError(
          'Scheduled EMI does not exceed installment interest; '
          'the loan would negatively amortize.',
        );
      }
      final payoffAmount = openingBalance + interest;
      final payment = scheduledEmi.compareTo(payoffAmount) >= 0
          ? payoffAmount
          : scheduledEmi;
      final principal = payment - interest;
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
      if (openingBalance.isZero) return entries;
    }

    throw StateError(
      'Loan did not close within $maxInstallments installments.',
    );
  }
}
