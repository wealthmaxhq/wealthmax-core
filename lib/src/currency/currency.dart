import 'package:meta/meta.dart';

@immutable
final class Currency {
  const Currency._({
    required this.code,
    required this.numericCode,
    required this.name,
    required this.symbol,
    required this.decimalPlaces,
  });

  final String code;
  final int numericCode;
  final String name;
  final String symbol;
  final int decimalPlaces;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Currency &&
            code == other.code &&
            numericCode == other.numericCode;
  }

  @override
  int get hashCode => Object.hash(code, numericCode);

  @override
  String toString() => code;
}

abstract final class Currencies {
  static const Currency inr = Currency._(
    code: 'INR',
    numericCode: 356,
    name: 'Indian Rupee',
    symbol: '\u20B9',
    decimalPlaces: 2,
  );

  static const Currency usd = Currency._(
    code: 'USD',
    numericCode: 840,
    name: 'US Dollar',
    symbol: r'$',
    decimalPlaces: 2,
  );

  static const Currency eur = Currency._(
    code: 'EUR',
    numericCode: 978,
    name: 'Euro',
    symbol: '\u20AC',
    decimalPlaces: 2,
  );

  static const List<Currency> values = <Currency>[inr, usd, eur];

  static Currency fromCode(String code) {
    final normalizedCode = code.trim().toUpperCase();

    for (final currency in values) {
      if (currency.code == normalizedCode) {
        return currency;
      }
    }

    throw ArgumentError.value(code, 'code', 'Unsupported currency code.');
  }
}
