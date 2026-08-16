import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:wealthmax_core/wealthmax_core.dart';

void main() {
  final calculatedAt = DateTime.utc(2026, 7, 25, 12, 30);

  CalculationMetadata metadata({
    Map<String, Object?> inputs = const <String, Object?>{},
    Map<String, Object?> assumptions = const <String, Object?>{},
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CalculationMetadata(
      formulaId: 'future-value',
      formulaVersion: '2.1.0',
      calculatedAt: calculatedAt,
      inputs: inputs,
      assumptions: assumptions,
      details: details,
    );
  }

  const infoWarning = CalculationWarning(
    code: 'ESTIMATE',
    message: 'An estimated input was used.',
    severity: WarningSeverity.info,
  );
  const cautionWarning = CalculationWarning(
    code: 'STALE_RATE',
    message: 'The supplied rate may be stale.',
    severity: WarningSeverity.caution,
  );
  const criticalWarning = CalculationWarning(
    code: 'MISSING_INPUT',
    message: 'A required input was unavailable.',
    severity: WarningSeverity.critical,
  );

  group('CalculationResult', () {
    test('represents a successful result without warnings', () {
      final result = CalculationResult<int>(value: 42, metadata: metadata());

      expect(result.value, 42);
      expect(result.warnings, isEmpty);
      expect(result.hasWarnings, isFalse);
      expect(result.hasCriticalWarnings, isFalse);
      expect(result.warningCount, 0);
    });

    test('supports multiple warning severities', () {
      final result = CalculationResult<String>(
        value: 'review',
        warnings: const <CalculationWarning>[
          infoWarning,
          cautionWarning,
          criticalWarning,
        ],
        metadata: metadata(),
      );

      expect(result.warningCount, 3);
      expect(
        result.warnings.map((warning) => warning.severity),
        <WarningSeverity>[
          WarningSeverity.info,
          WarningSeverity.caution,
          WarningSeverity.critical,
        ],
      );
    });

    test('detects a critical warning', () {
      final result = CalculationResult<int>(
        value: 1,
        warnings: const <CalculationWarning>[criticalWarning],
        metadata: metadata(),
      );

      expect(result.hasCriticalWarnings, isTrue);
    });

    test('does not report caution as critical', () {
      final result = CalculationResult<int>(
        value: 1,
        warnings: const <CalculationWarning>[cautionWarning],
        metadata: metadata(),
      );

      expect(result.hasCriticalWarnings, isFalse);
    });

    test('map transforms the value and preserves context', () {
      final original = CalculationResult<int>(
        value: 21,
        warnings: const <CalculationWarning>[cautionWarning],
        metadata: metadata(),
      );

      final mapped = original.map<String>((value) => 'value:${value * 2}');

      expect(mapped.value, 'value:42');
      expect(mapped.warnings, original.warnings);
      expect(mapped.metadata, same(original.metadata));
    });

    test('defensively copies the supplied warning list', () {
      final warnings = <CalculationWarning>[infoWarning];
      final result = CalculationResult<int>(
        value: 1,
        warnings: warnings,
        metadata: metadata(),
      );

      warnings.add(criticalWarning);

      expect(result.warnings, const <CalculationWarning>[infoWarning]);
    });

    test('exposes an unmodifiable warning list', () {
      final result = CalculationResult<int>(
        value: 1,
        warnings: const <CalculationWarning>[infoWarning],
        metadata: metadata(),
      );

      expect(() => result.warnings.add(cautionWarning), throwsUnsupportedError);
    });

    test('has value equality and matching hash codes', () {
      final first = CalculationResult<int>(
        value: 42,
        warnings: const <CalculationWarning>[infoWarning],
        metadata: metadata(),
      );
      final second = CalculationResult<int>(
        value: 42,
        warnings: const <CalculationWarning>[infoWarning],
        metadata: metadata(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('uses warning order in equality', () {
      final first = CalculationResult<int>(
        value: 42,
        warnings: const <CalculationWarning>[infoWarning, cautionWarning],
        metadata: metadata(),
      );
      final second = CalculationResult<int>(
        value: 42,
        warnings: const <CalculationWarning>[cautionWarning, infoWarning],
        metadata: metadata(),
      );

      expect(first, isNot(second));
    });

    test('copyWith replaces selected fields', () {
      final original = CalculationResult<int>(
        value: 10,
        warnings: const <CalculationWarning>[infoWarning],
        metadata: metadata(),
      );
      final replacementMetadata = metadata(details: {'source': 'manual'});

      final copied = original.copyWith(
        value: 20,
        warnings: const <CalculationWarning>[cautionWarning],
        metadata: replacementMetadata,
      );

      expect(copied.value, 20);
      expect(copied.warnings, const <CalculationWarning>[cautionWarning]);
      expect(copied.metadata, replacementMetadata);
    });

    test('copyWith can assign null for a nullable generic value', () {
      final original = CalculationResult<String?>(
        value: 'known',
        metadata: metadata(),
      );

      expect(original.copyWith(value: null).value, isNull);
    });

    test('supports a Money value', () {
      final money = Money.parse('1250.75', currency: Currencies.inr);
      final result = CalculationResult<Money>(
        value: money,
        metadata: metadata(),
      );

      expect(result.value, money);
    });

    test('supports a Percentage value', () {
      final percentage = Percentage.fromPercent('12.5');
      final result = CalculationResult<Percentage>(
        value: percentage,
        metadata: metadata(),
      );

      expect(result.value, percentage);
    });

    test('supports String and int values', () {
      final stringResult = CalculationResult<String>(
        value: 'complete',
        metadata: metadata(),
      );
      final intResult = CalculationResult<int>(value: 7, metadata: metadata());

      expect(stringResult.value, 'complete');
      expect(intResult.value, 7);
    });

    test('has deterministic string output', () {
      final result = CalculationResult<int>(
        value: 42,
        warnings: const <CalculationWarning>[cautionWarning],
        metadata: metadata(inputs: {'z': 2, 'a': 1}),
      );

      expect(
        result.toString(),
        'CalculationResult<int>('
        'value: 42, '
        'warnings: [CalculationWarning('
        'code: STALE_RATE, '
        'message: The supplied rate may be stale., '
        'severity: caution)], '
        'metadata: CalculationMetadata('
        'formulaId: future-value, '
        'formulaVersion: 2.1.0, '
        'calculatedAt: 2026-07-25T12:30:00.000Z, '
        'inputs: {a: 1, z: 2}, '
        'assumptions: {}, '
        'details: {}))',
      );
    });
  });

  group('CalculationWarning', () {
    test('supports all severity values', () {
      expect(WarningSeverity.values, <WarningSeverity>[
        WarningSeverity.info,
        WarningSeverity.caution,
        WarningSeverity.critical,
      ]);
    });

    test('has value equality and matching hash codes', () {
      const first = CalculationWarning(
        code: 'ESTIMATE',
        message: 'An estimated input was used.',
        severity: WarningSeverity.info,
      );

      expect(first, infoWarning);
      expect(first.hashCode, infoWarning.hashCode);
    });

    test('copyWith replaces selected fields', () {
      final copied = infoWarning.copyWith(
        message: 'Updated message.',
        severity: WarningSeverity.caution,
      );

      expect(copied.code, infoWarning.code);
      expect(copied.message, 'Updated message.');
      expect(copied.severity, WarningSeverity.caution);
    });

    test('has deterministic string output', () {
      expect(
        infoWarning.toString(),
        'CalculationWarning('
        'code: ESTIMATE, '
        'message: An estimated input was used., '
        'severity: info)',
      );
    });
  });

  group('CalculationMetadata', () {
    test('defensively copies top-level maps', () {
      final inputs = <String, Object?>{'principal': 1000};
      final value = metadata(inputs: inputs);

      inputs['principal'] = 2000;
      inputs['rate'] = Decimal.parse('0.08');

      expect(value.inputs, <String, Object?>{'principal': 1000});
    });

    test('defensively copies nested maps and lists', () {
      final scenarios = <Object?>[
        <String, Object?>{'rate': '0.08'},
      ];
      final nested = <String, Object?>{'scenarios': scenarios};
      final value = metadata(details: nested);

      (scenarios.first! as Map<String, Object?>)['rate'] = '0.10';
      scenarios.add('later mutation');

      expect(value.details, <String, Object?>{
        'scenarios': <Object?>[
          <String, Object?>{'rate': '0.08'},
        ],
      });
    });

    test('exposes unmodifiable top-level maps', () {
      final value = metadata(inputs: {'principal': 1000});

      expect(() => value.inputs['principal'] = 2000, throwsUnsupportedError);
    });

    test('exposes unmodifiable nested maps and lists', () {
      final value = metadata(
        details: {
          'scenario': <String, Object?>{
            'rates': <Object?>['0.07', '0.08'],
          },
        },
      );
      final scenario = value.details['scenario']! as Map<Object?, Object?>;
      final rates = scenario['rates']! as List<Object?>;

      expect(() => scenario['name'] = 'base', throwsUnsupportedError);
      expect(() => rates.add('0.09'), throwsUnsupportedError);
    });

    test('has deep value equality independent of map insertion order', () {
      final first = metadata(
        inputs: {
          'principal': 1000,
          'schedule': <Object?>[1, 2, 3],
        },
      );
      final second = metadata(
        inputs: {
          'schedule': <Object?>[1, 2, 3],
          'principal': 1000,
        },
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('detects differences in nested metadata', () {
      final first = metadata(
        assumptions: {
          'rates': <Object?>['0.07', '0.08'],
        },
      );
      final second = metadata(
        assumptions: {
          'rates': <Object?>['0.07', '0.09'],
        },
      );

      expect(first, isNot(second));
    });

    test('copyWith replaces selected fields and snapshots new maps', () {
      final original = metadata(inputs: {'principal': 1000});
      final details = <String, Object?>{'audited': true};

      final copied = original.copyWith(
        formulaVersion: '2.2.0',
        details: details,
      );
      details['audited'] = false;

      expect(copied.formulaId, original.formulaId);
      expect(copied.formulaVersion, '2.2.0');
      expect(copied.inputs, original.inputs);
      expect(copied.details, <String, Object?>{'audited': true});
    });

    test('has deterministic string output for nested maps', () {
      final value = metadata(
        inputs: {
          'z': 2,
          'a': <String, Object?>{'y': 2, 'x': 1},
        },
        assumptions: {'inflation': '0.05'},
        details: {
          'tags': <Object?>['long-term', 'nominal'],
        },
      );

      expect(
        value.toString(),
        'CalculationMetadata('
        'formulaId: future-value, '
        'formulaVersion: 2.1.0, '
        'calculatedAt: 2026-07-25T12:30:00.000Z, '
        'inputs: {a: {x: 1, y: 2}, z: 2}, '
        'assumptions: {inflation: 0.05}, '
        'details: {tags: [long-term, nominal]})',
      );
    });
  });
}
