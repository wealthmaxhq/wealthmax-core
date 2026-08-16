import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  group('Currency', () {
    test('contains correct INR details', () {
      expect(Currencies.inr.code, 'INR');
      expect(Currencies.inr.numericCode, 356);
      expect(Currencies.inr.name, 'Indian Rupee');
      expect(Currencies.inr.symbol, '₹');
      expect(Currencies.inr.decimalPlaces, 2);
    });

    test('contains correct USD details', () {
      expect(Currencies.usd.code, 'USD');
      expect(Currencies.usd.numericCode, 840);
      expect(Currencies.usd.name, 'US Dollar');
      expect(Currencies.usd.symbol, r'$');
      expect(Currencies.usd.decimalPlaces, 2);
    });

    test('finds a currency using a case-insensitive code', () {
      expect(Currencies.fromCode('inr'), same(Currencies.inr));
      expect(Currencies.fromCode(' USD '), same(Currencies.usd));
    });

    test('throws for unsupported currency codes', () {
      expect(() => Currencies.fromCode('ABC'), throwsArgumentError);
    });

    test('currency equality works correctly', () {
      expect(Currencies.inr, equals(Currencies.inr));
      expect(Currencies.inr, isNot(equals(Currencies.usd)));
    });

    test('toString returns the currency code', () {
      expect(Currencies.inr.toString(), 'INR');
    });
  });
}
