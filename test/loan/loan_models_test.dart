import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Money inr(String value) => Money.parse(value, currency: Currencies.inr);
  Money usd(String value) => Money.parse(value, currency: Currencies.usd);

  group('LoanInput', () {
    test('stores required values', () {
      final input = LoanInput(
        principal: inr('5000000'),
        annualInterestRate: Percentage.fromPercent('8.5'),
        tenureMonths: 240,
      );

      expect(input.principal, inr('5000000'));
      expect(input.annualInterestRate, Percentage.fromPercent('8.5'));
      expect(input.tenureMonths, 240);
      expect(input.processingFee, isNull);
      expect(input.prepayment, isNull);
    });

    test('stores optional monetary inputs', () {
      final input = LoanInput(
        principal: inr('5000000'),
        annualInterestRate: Percentage.fromPercent('8.5'),
        tenureMonths: 240,
        processingFee: inr('25000'),
        prepayment: inr('500000'),
      );

      expect(input.processingFee, inr('25000'));
      expect(input.prepayment, inr('500000'));
      expect(input.financedPrincipal, inr('4500000'));
    });

    test('financed principal equals principal without prepayment', () {
      final input = LoanInput(
        principal: inr('1000'),
        annualInterestRate: Percentage.fromPercent('0'),
        tenureMonths: 1,
      );

      expect(input.financedPrincipal, inr('1000'));
    });

    test('accepts zero interest', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('0'),
          tenureMonths: 12,
        ),
        returnsNormally,
      );
    });

    test('accepts zero optional monetary amounts', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: 12,
          processingFee: inr('0'),
          prepayment: inr('0'),
        ),
        returnsNormally,
      );
    });

    test('rejects zero principal', () {
      expect(
        () => LoanInput(
          principal: inr('0'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: 12,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative principal', () {
      expect(
        () => LoanInput(
          principal: inr('-1'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: 12,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative interest', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('-0.01'),
          tenureMonths: 12,
        ),
        throwsArgumentError,
      );
    });

    test('rejects zero tenure', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative tenure', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects processing fee in another currency', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: 12,
          processingFee: usd('10'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects prepayment in another currency', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: 12,
          prepayment: usd('10'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative processing fee', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: 12,
          processingFee: inr('-1'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative prepayment', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: 12,
          prepayment: inr('-1'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects prepayment greater than principal', () {
      expect(
        () => LoanInput(
          principal: inr('1000'),
          annualInterestRate: Percentage.fromPercent('5'),
          tenureMonths: 12,
          prepayment: inr('1000.01'),
        ),
        throwsArgumentError,
      );
    });

    test('supports prepayment equal to principal', () {
      final input = LoanInput(
        principal: inr('1000'),
        annualInterestRate: Percentage.fromPercent('5'),
        tenureMonths: 12,
        prepayment: inr('1000'),
      );

      expect(input.financedPrincipal, Money.zero(Currencies.inr));
    });

    test('supports value equality and matching hash codes', () {
      final first = LoanInput(
        principal: inr('1000'),
        annualInterestRate: Percentage.fromPercent('5'),
        tenureMonths: 12,
        processingFee: inr('10'),
      );
      final second = LoanInput(
        principal: inr('1000'),
        annualInterestRate: Percentage.fromPercent('5'),
        tenureMonths: 12,
        processingFee: inr('10'),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('copyWith replaces values and can clear optional amounts', () {
      final original = LoanInput(
        principal: inr('1000'),
        annualInterestRate: Percentage.fromPercent('5'),
        tenureMonths: 12,
        processingFee: inr('10'),
        prepayment: inr('100'),
      );

      final copy = original.copyWith(
        tenureMonths: 24,
        processingFee: null,
        prepayment: null,
      );

      expect(copy.principal, original.principal);
      expect(copy.tenureMonths, 24);
      expect(copy.processingFee, isNull);
      expect(copy.prepayment, isNull);
    });

    test('has deterministic string output', () {
      final input = LoanInput(
        principal: inr('1000'),
        annualInterestRate: Percentage.fromPercent('5'),
        tenureMonths: 12,
      );

      expect(
        input.toString(),
        'LoanInput(principal: INR 1000, annualInterestRate: 5%, '
        'tenureMonths: 12, processingFee: null, prepayment: null)',
      );
    });
  });

  group('LoanResult', () {
    test('stores monetary summary', () {
      final result = LoanResult(
        emi: inr('100'),
        totalInterest: inr('200'),
        totalPayment: inr('1200'),
      );

      expect(result.emi, inr('100'));
      expect(result.totalInterest, inr('200'));
      expect(result.totalPayment, inr('1200'));
    });

    test('accepts zero values', () {
      expect(
        () => LoanResult(
          emi: inr('0'),
          totalInterest: inr('0'),
          totalPayment: inr('0'),
        ),
        returnsNormally,
      );
    });

    test('rejects negative EMI', () {
      expect(
        () => LoanResult(
          emi: inr('-1'),
          totalInterest: inr('0'),
          totalPayment: inr('0'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative total interest', () {
      expect(
        () => LoanResult(
          emi: inr('1'),
          totalInterest: inr('-1'),
          totalPayment: inr('1'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative total payment', () {
      expect(
        () => LoanResult(
          emi: inr('1'),
          totalInterest: inr('0'),
          totalPayment: inr('-1'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects total interest in another currency', () {
      expect(
        () => LoanResult(
          emi: inr('1'),
          totalInterest: usd('1'),
          totalPayment: inr('1'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects total payment in another currency', () {
      expect(
        () => LoanResult(
          emi: inr('1'),
          totalInterest: inr('1'),
          totalPayment: usd('1'),
        ),
        throwsArgumentError,
      );
    });

    test('supports value equality and matching hash codes', () {
      final first = LoanResult(
        emi: inr('100'),
        totalInterest: inr('200'),
        totalPayment: inr('1200'),
      );
      final second = LoanResult(
        emi: inr('100'),
        totalInterest: inr('200'),
        totalPayment: inr('1200'),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('copyWith replaces selected values', () {
      final original = LoanResult(
        emi: inr('100'),
        totalInterest: inr('200'),
        totalPayment: inr('1200'),
      );

      final copy = original.copyWith(emi: inr('110'));

      expect(copy.emi, inr('110'));
      expect(copy.totalInterest, original.totalInterest);
      expect(copy.totalPayment, original.totalPayment);
    });

    test('has deterministic string output', () {
      final result = LoanResult(
        emi: inr('100'),
        totalInterest: inr('200'),
        totalPayment: inr('1200'),
      );

      expect(
        result.toString(),
        'LoanResult(emi: INR 100, totalInterest: INR 200, '
        'totalPayment: INR 1200)',
      );
    });
  });
}
