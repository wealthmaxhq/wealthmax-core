import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  group('Money', () {
    test('parses a decimal amount without using binary floating point', () {
      final money = Money.parse('1250.75', currency: Currencies.inr);

      expect(money.amount, Decimal.parse('1250.75'));
      expect(money.currency, Currencies.inr);
    });

    test('reports an invalid amount as a format error', () {
      expect(
        () => Money.parse('not-an-amount', currency: Currencies.inr),
        throwsFormatException,
      );
    });

    test('creates zero money', () {
      final money = Money.zero(Currencies.inr);

      expect(money.amount, Decimal.zero);
      expect(money.currency, Currencies.inr);
      expect(money.isZero, isTrue);
      expect(money.isPositive, isFalse);
      expect(money.isNegative, isFalse);
    });

    test('identifies positive money', () {
      final money = Money.parse('0.01', currency: Currencies.inr);

      expect(money.isZero, isFalse);
      expect(money.isPositive, isTrue);
      expect(money.isNegative, isFalse);
    });

    test('identifies negative money', () {
      final money = Money.parse('-0.01', currency: Currencies.inr);

      expect(money.isZero, isFalse);
      expect(money.isPositive, isFalse);
      expect(money.isNegative, isTrue);
    });

    test('adds money with the same currency', () {
      final first = Money.parse('100.25', currency: Currencies.inr);
      final second = Money.parse('50.75', currency: Currencies.inr);

      final result = first + second;

      expect(result.amount, Decimal.parse('151'));
      expect(result.currency, Currencies.inr);
    });

    test('subtracts money with the same currency', () {
      final first = Money.parse('200', currency: Currencies.inr);
      final second = Money.parse('75.50', currency: Currencies.inr);

      final result = first - second;

      expect(result.amount, Decimal.parse('124.50'));
    });

    test('rejects addition using different currencies', () {
      final rupees = Money.parse('100', currency: Currencies.inr);
      final dollars = Money.parse('100', currency: Currencies.usd);

      expect(
        () => rupees + dollars,
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Cannot add money in INR and USD'),
          ),
        ),
      );
    });

    test('rejects subtraction using different currencies', () {
      final rupees = Money.parse('100', currency: Currencies.inr);
      final dollars = Money.parse('100', currency: Currencies.usd);

      expect(
        () => rupees - dollars,
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Cannot subtract money in INR and USD'),
          ),
        ),
      );
    });

    test('rejects comparison using different currencies', () {
      final rupees = Money.parse('100', currency: Currencies.inr);
      final dollars = Money.parse('100', currency: Currencies.usd);

      expect(
        () => rupees.compareTo(dollars),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Cannot compare money in INR and USD'),
          ),
        ),
      );
    });

    test('multiplies money by an exact decimal factor', () {
      final money = Money.parse('0.10', currency: Currencies.inr);

      final result = money.multiply(Decimal.parse('0.20'));

      expect(result.amount, Decimal.parse('0.02'));
      expect(result.currency, Currencies.inr);
    });

    test('supports the multiplication operator with a Decimal', () {
      final money = Money.parse('-12.5', currency: Currencies.usd);

      expect(
        money * Decimal.parse('-2'),
        Money.parse('25', currency: Currencies.usd),
      );
    });

    test('negates money', () {
      final money = Money.parse('500', currency: Currencies.inr);

      final result = money.negate();

      expect(result.amount, Decimal.parse('-500'));
      expect(result.isNegative, isTrue);
    });

    test('returns the absolute value', () {
      final money = Money.parse('-500', currency: Currencies.inr);

      final result = money.abs();

      expect(result.amount, Decimal.parse('500'));
      expect(result.isPositive, isTrue);
    });

    test('absolute value returns an already non-negative value unchanged', () {
      final positive = Money.parse('500', currency: Currencies.inr);
      final zero = Money.zero(Currencies.inr);

      expect(positive.abs(), same(positive));
      expect(zero.abs(), same(zero));
    });

    test('compares money with the same currency', () {
      final lower = Money.parse('99.99', currency: Currencies.inr);
      final higher = Money.parse('100', currency: Currencies.inr);

      expect(lower.compareTo(higher), lessThan(0));
      expect(higher.compareTo(lower), greaterThan(0));
      expect(higher.compareTo(higher), 0);
    });

    test('supports value equality', () {
      final first = Money.parse('100.00', currency: Currencies.inr);
      final second = Money.parse('100', currency: Currencies.inr);

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
    });

    test('money in different currencies is not equal', () {
      final rupees = Money.parse('100', currency: Currencies.inr);
      final dollars = Money.parse('100', currency: Currencies.usd);

      expect(rupees, isNot(equals(dollars)));
    });

    test('toString deterministically uses code followed by decimal amount', () {
      final money = Money.parse('125.50', currency: Currencies.inr);

      expect(money.toString(), 'INR 125.5');
    });
  });
}
