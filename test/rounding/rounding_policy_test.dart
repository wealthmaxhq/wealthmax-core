import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  Decimal round(
    RoundingPolicy policy,
    String value, {
    required int decimalPlaces,
  }) {
    return policy.round(Decimal.parse(value), decimalPlaces: decimalPlaces);
  }

  group('halfUp', () {
    test('rounds positive 1.005 away from zero at an exact tie', () {
      expect(
        round(RoundingPolicy.halfUp, '1.005', decimalPlaces: 2),
        Decimal.parse('1.01'),
      );
    });

    test('rounds negative 1.005 away from zero at an exact tie', () {
      expect(
        round(RoundingPolicy.halfUp, '-1.005', decimalPlaces: 2),
        Decimal.parse('-1.01'),
      );
    });

    test('rounds positive 1.015 away from zero at an exact tie', () {
      expect(
        round(RoundingPolicy.halfUp, '1.015', decimalPlaces: 2),
        Decimal.parse('1.02'),
      );
    });

    test('rounds negative 1.015 away from zero at an exact tie', () {
      expect(
        round(RoundingPolicy.halfUp, '-1.015', decimalPlaces: 2),
        Decimal.parse('-1.02'),
      );
    });
  });

  group('halfDown', () {
    test('rounds positive ties toward zero', () {
      expect(
        round(RoundingPolicy.halfDown, '1.005', decimalPlaces: 2),
        Decimal.parse('1'),
      );
    });

    test('rounds negative ties toward zero', () {
      expect(
        round(RoundingPolicy.halfDown, '-1.005', decimalPlaces: 2),
        Decimal.parse('-1'),
      );
    });

    test('still rounds values above a tie away from zero', () {
      expect(
        round(RoundingPolicy.halfDown, '1.0051', decimalPlaces: 2),
        Decimal.parse('1.01'),
      );
    });
  });

  group('halfEven', () {
    test('rounds 1.005 to an even final digit', () {
      expect(
        round(RoundingPolicy.halfEven, '1.005', decimalPlaces: 2),
        Decimal.parse('1'),
      );
    });

    test('rounds negative 1.005 to an even final digit', () {
      expect(
        round(RoundingPolicy.halfEven, '-1.005', decimalPlaces: 2),
        Decimal.parse('-1'),
      );
    });

    test('rounds 1.015 to an even final digit', () {
      expect(
        round(RoundingPolicy.halfEven, '1.015', decimalPlaces: 2),
        Decimal.parse('1.02'),
      );
    });

    test('rounds negative 1.015 to an even final digit', () {
      expect(
        round(RoundingPolicy.halfEven, '-1.015', decimalPlaces: 2),
        Decimal.parse('-1.02'),
      );
    });

    test('rounds 2.5 down to even at zero decimal places', () {
      expect(
        round(RoundingPolicy.halfEven, '2.5', decimalPlaces: 0),
        Decimal.parse('2'),
      );
    });

    test('rounds 3.5 up to even at zero decimal places', () {
      expect(
        round(RoundingPolicy.halfEven, '3.5', decimalPlaces: 0),
        Decimal.parse('4'),
      );
    });

    test('rounds negative 2.5 toward the even integer', () {
      expect(
        round(RoundingPolicy.halfEven, '-2.5', decimalPlaces: 0),
        Decimal.parse('-2'),
      );
    });

    test('rounds negative 3.5 toward the even integer', () {
      expect(
        round(RoundingPolicy.halfEven, '-3.5', decimalPlaces: 0),
        Decimal.parse('-4'),
      );
    });
  });

  group('directed policies', () {
    test('ceiling rounds a positive value toward positive infinity', () {
      expect(
        round(RoundingPolicy.ceiling, '1.231', decimalPlaces: 2),
        Decimal.parse('1.24'),
      );
    });

    test('ceiling rounds a negative value toward positive infinity', () {
      expect(
        round(RoundingPolicy.ceiling, '-1.239', decimalPlaces: 2),
        Decimal.parse('-1.23'),
      );
    });

    test('floor rounds a positive value toward negative infinity', () {
      expect(
        round(RoundingPolicy.floor, '1.239', decimalPlaces: 2),
        Decimal.parse('1.23'),
      );
    });

    test('floor rounds a negative value toward negative infinity', () {
      expect(
        round(RoundingPolicy.floor, '-1.231', decimalPlaces: 2),
        Decimal.parse('-1.24'),
      );
    });

    test('towardZero discards positive excess precision', () {
      expect(
        round(RoundingPolicy.towardZero, '1.239', decimalPlaces: 2),
        Decimal.parse('1.23'),
      );
    });

    test('towardZero discards negative excess precision', () {
      expect(
        round(RoundingPolicy.towardZero, '-1.239', decimalPlaces: 2),
        Decimal.parse('-1.23'),
      );
    });

    test('awayFromZero increases a positive magnitude', () {
      expect(
        round(RoundingPolicy.awayFromZero, '1.231', decimalPlaces: 2),
        Decimal.parse('1.24'),
      );
    });

    test('awayFromZero increases a negative magnitude', () {
      expect(
        round(RoundingPolicy.awayFromZero, '-1.231', decimalPlaces: 2),
        Decimal.parse('-1.24'),
      );
    });
  });

  group('general behavior', () {
    test('returns zero for every policy', () {
      for (final policy in RoundingPolicy.values) {
        expect(
          policy.round(Decimal.zero, decimalPlaces: 4),
          Decimal.zero,
          reason: '$policy',
        );
      }
    });

    test('preserves values already within the requested precision', () {
      for (final policy in RoundingPolicy.values) {
        expect(
          round(policy, '123.45', decimalPlaces: 4),
          Decimal.parse('123.45'),
          reason: '$policy',
        );
      }
    });

    test('handles very large values exactly', () {
      expect(
        round(
          RoundingPolicy.halfEven,
          '999999999999999999999999999999.995',
          decimalPlaces: 2,
        ),
        Decimal.parse('1000000000000000000000000000000'),
      );
    });

    test('distinguishes all nearest policies at an even tie', () {
      final value = Decimal.parse('2.5');

      expect(
        RoundingPolicy.halfUp.round(value, decimalPlaces: 0),
        Decimal.parse('3'),
      );
      expect(
        RoundingPolicy.halfDown.round(value, decimalPlaces: 0),
        Decimal.parse('2'),
      );
      expect(
        RoundingPolicy.halfEven.round(value, decimalPlaces: 0),
        Decimal.parse('2'),
      );
    });

    test('distinguishes halfDown and halfEven at an odd tie', () {
      final value = Decimal.parse('3.5');

      expect(
        RoundingPolicy.halfDown.round(value, decimalPlaces: 0),
        Decimal.parse('3'),
      );
      expect(
        RoundingPolicy.halfEven.round(value, decimalPlaces: 0),
        Decimal.parse('4'),
      );
    });

    test('rejects negative decimal places for every policy', () {
      for (final policy in RoundingPolicy.values) {
        expect(
          () => policy.round(Decimal.one, decimalPlaces: -1),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'decimalPlaces')
                .having((error) => error.invalidValue, 'invalidValue', -1),
          ),
          reason: '$policy',
        );
      }
    });
  });
}
