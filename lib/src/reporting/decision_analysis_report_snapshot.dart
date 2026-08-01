import 'dart:convert';

import 'package:meta/meta.dart';

/// Versioned, JSON-safe representation of a decision-analysis report.
///
/// Exact decimal values are encoded as strings so storage and presentation
/// layers cannot introduce binary floating-point drift.
@immutable
final class DecisionAnalysisReportSnapshot {
  factory DecisionAnalysisReportSnapshot({
    required int schemaVersion,
    required Map<String, Object?> data,
  }) {
    if (schemaVersion <= 0) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Schema version must be greater than zero.',
      );
    }
    final frozen = _freezeStringMap(data);
    if (frozen['schemaVersion'] != schemaVersion) {
      throw ArgumentError(
        'Snapshot data schemaVersion must match the model schemaVersion.',
      );
    }
    _validateJsonValue(frozen);
    return DecisionAnalysisReportSnapshot._(
      schemaVersion: schemaVersion,
      data: frozen,
    );
  }

  const DecisionAnalysisReportSnapshot._({
    required this.schemaVersion,
    required this.data,
  });

  final int schemaVersion;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => data;
  String encode() => jsonEncode(data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecisionAnalysisReportSnapshot &&
          schemaVersion == other.schemaVersion &&
          encode() == other.encode();

  @override
  int get hashCode => Object.hash(schemaVersion, encode());

  @override
  String toString() =>
      'DecisionAnalysisReportSnapshot(schemaVersion: $schemaVersion, '
      'data: ${encode()})';
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
            MapEntry<Object?, Object?>(key, _freeze(nestedValue)),
      ),
    );
  }
  if (value is Iterable) {
    return List<Object?>.unmodifiable(value.map(_freeze));
  }
  return value;
}

void _validateJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return;
  }
  if (value is List) {
    for (final nestedValue in value) {
      _validateJsonValue(nestedValue);
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError('Snapshot map keys must be strings.');
      }
      _validateJsonValue(entry.value);
    }
    return;
  }
  throw ArgumentError(
    'Snapshot values must be JSON-safe; found ${value.runtimeType}.',
  );
}
