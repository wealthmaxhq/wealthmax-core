import 'package:meta/meta.dart';

/// The importance of a [CalculationWarning].
enum WarningSeverity {
  /// Informational context that does not indicate a calculation concern.
  info,

  /// A condition that should be reviewed when using the result.
  caution,

  /// A serious condition that may make the result unsuitable for use.
  critical,
}

/// An immutable warning produced during a financial calculation.
@immutable
final class CalculationWarning {
  const CalculationWarning({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final WarningSeverity severity;

  CalculationWarning copyWith({
    String? code,
    String? message,
    WarningSeverity? severity,
  }) {
    return CalculationWarning(
      code: code ?? this.code,
      message: message ?? this.message,
      severity: severity ?? this.severity,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalculationWarning &&
            code == other.code &&
            message == other.message &&
            severity == other.severity;
  }

  @override
  int get hashCode => Object.hash(code, message, severity);

  @override
  String toString() {
    return 'CalculationWarning('
        'code: $code, '
        'message: $message, '
        'severity: ${severity.name}'
        ')';
  }
}

/// Immutable provenance and context for a financial calculation.
@immutable
final class CalculationMetadata {
  factory CalculationMetadata({
    required String formulaId,
    required String formulaVersion,
    required DateTime calculatedAt,
    Map<String, Object?> inputs = const <String, Object?>{},
    Map<String, Object?> assumptions = const <String, Object?>{},
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CalculationMetadata._(
      formulaId: formulaId,
      formulaVersion: formulaVersion,
      calculatedAt: calculatedAt,
      inputs: _freezeStringMap(inputs),
      assumptions: _freezeStringMap(assumptions),
      details: _freezeStringMap(details),
    );
  }

  const CalculationMetadata._({
    required this.formulaId,
    required this.formulaVersion,
    required this.calculatedAt,
    required this.inputs,
    required this.assumptions,
    required this.details,
  });

  final String formulaId;
  final String formulaVersion;
  final DateTime calculatedAt;
  final Map<String, Object?> inputs;
  final Map<String, Object?> assumptions;
  final Map<String, Object?> details;

  CalculationMetadata copyWith({
    String? formulaId,
    String? formulaVersion,
    DateTime? calculatedAt,
    Map<String, Object?>? inputs,
    Map<String, Object?>? assumptions,
    Map<String, Object?>? details,
  }) {
    return CalculationMetadata(
      formulaId: formulaId ?? this.formulaId,
      formulaVersion: formulaVersion ?? this.formulaVersion,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      inputs: inputs ?? this.inputs,
      assumptions: assumptions ?? this.assumptions,
      details: details ?? this.details,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalculationMetadata &&
            formulaId == other.formulaId &&
            formulaVersion == other.formulaVersion &&
            calculatedAt == other.calculatedAt &&
            _deepEquals(inputs, other.inputs) &&
            _deepEquals(assumptions, other.assumptions) &&
            _deepEquals(details, other.details);
  }

  @override
  int get hashCode {
    return Object.hash(
      formulaId,
      formulaVersion,
      calculatedAt,
      _deepHash(inputs),
      _deepHash(assumptions),
      _deepHash(details),
    );
  }

  @override
  String toString() {
    return 'CalculationMetadata('
        'formulaId: $formulaId, '
        'formulaVersion: $formulaVersion, '
        'calculatedAt: ${calculatedAt.toIso8601String()}, '
        'inputs: ${_stableString(inputs)}, '
        'assumptions: ${_stableString(assumptions)}, '
        'details: ${_stableString(details)}'
        ')';
  }
}

/// An immutable value and its calculation warnings and provenance.
@immutable
final class CalculationResult<T> {
  factory CalculationResult({
    required T value,
    required CalculationMetadata metadata,
    Iterable<CalculationWarning> warnings = const <CalculationWarning>[],
  }) {
    return CalculationResult<T>._(
      value: value,
      warnings: List<CalculationWarning>.unmodifiable(warnings),
      metadata: metadata,
    );
  }

  const CalculationResult._({
    required this.value,
    required this.warnings,
    required this.metadata,
  });

  static const Object _unset = Object();

  final T value;
  final List<CalculationWarning> warnings;
  final CalculationMetadata metadata;

  bool get hasWarnings => warnings.isNotEmpty;

  bool get hasCriticalWarnings {
    return warnings.any(
      (warning) => warning.severity == WarningSeverity.critical,
    );
  }

  int get warningCount => warnings.length;

  CalculationResult<R> map<R>(R Function(T value) transform) {
    return CalculationResult<R>(
      value: transform(value),
      warnings: warnings,
      metadata: metadata,
    );
  }

  CalculationResult<T> copyWith({
    Object? value = _unset,
    Iterable<CalculationWarning>? warnings,
    CalculationMetadata? metadata,
  }) {
    return CalculationResult<T>(
      value: identical(value, _unset) ? this.value : value as T,
      warnings: warnings ?? this.warnings,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalculationResult<T> &&
            _deepEquals(value, other.value) &&
            _deepEquals(warnings, other.warnings) &&
            metadata == other.metadata;
  }

  @override
  int get hashCode {
    return Object.hash(_deepHash(value), _deepHash(warnings), metadata);
  }

  @override
  String toString() {
    return 'CalculationResult<$T>('
        'value: ${_stableString(value)}, '
        'warnings: ${_stableString(warnings)}, '
        'metadata: $metadata'
        ')';
  }
}

Map<String, Object?> _freezeStringMap(Map<String, Object?> source) {
  return Map<String, Object?>.unmodifiable(
    source.map((key, value) => MapEntry<String, Object?>(key, _freeze(value))),
  );
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable(
      value.map(
        (key, nestedValue) =>
            MapEntry<Object?, Object?>(_freeze(key), _freeze(nestedValue)),
      ),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freeze));
  }
  if (value is Set) {
    return Set<Object?>.unmodifiable(value.map(_freeze));
  }
  return value;
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    final unmatched = right.entries.toList();
    for (final leftEntry in left.entries) {
      final match = unmatched.indexWhere(
        (rightEntry) =>
            _deepEquals(leftEntry.key, rightEntry.key) &&
            _deepEquals(leftEntry.value, rightEntry.value),
      );
      if (match < 0) return false;
      unmatched.removeAt(match);
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Set && right is Set) {
    if (left.length != right.length) return false;
    final unmatched = right.toList();
    for (final leftValue in left) {
      final match = unmatched.indexWhere(
        (rightValue) => _deepEquals(leftValue, rightValue),
      );
      if (match < 0) return false;
      unmatched.removeAt(match);
    }
    return true;
  }
  return left == right;
}

int _deepHash(Object? value) {
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map(
        (entry) => Object.hash(_deepHash(entry.key), _deepHash(entry.value)),
      ),
    );
  }
  if (value is List) {
    return Object.hashAll(value.map(_deepHash));
  }
  if (value is Set) {
    return Object.hashAllUnordered(value.map(_deepHash));
  }
  return value.hashCode;
}

String _stableString(Object? value) {
  if (value is Map) {
    final entries =
        value.entries
            .map(
              (entry) => (
                key: _stableString(entry.key),
                value: _stableString(entry.value),
              ),
            )
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    return '{${entries.map((entry) => '${entry.key}: ${entry.value}').join(', ')}}';
  }
  if (value is List) {
    return '[${value.map(_stableString).join(', ')}]';
  }
  if (value is Set) {
    final values = value.map(_stableString).toList()..sort();
    return '{${values.join(', ')}}';
  }
  return value.toString();
}
