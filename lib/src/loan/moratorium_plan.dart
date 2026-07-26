import 'package:meta/meta.dart';

/// Payment behavior during a loan moratorium.
enum MoratoriumType {
  /// No installment is paid; accrued interest is added to principal.
  fullPayment,

  /// Accrued interest is paid monthly; principal remains unchanged.
  interestOnly,
}

/// How the repayment tenure is treated after the moratorium.
enum MoratoriumTenureTreatment {
  /// Preserve all original repayment installments and extend elapsed tenure.
  extendTenure,

  /// Count moratorium months inside the original contractual tenure.
  withinOriginalTenure,
}

/// Immutable, explicit loan moratorium assumptions.
@immutable
final class MoratoriumPlan {
  factory MoratoriumPlan({
    required int months,
    required MoratoriumType type,
    required MoratoriumTenureTreatment tenureTreatment,
  }) {
    if (months < 0) {
      throw ArgumentError.value(
        months,
        'months',
        'Moratorium months must not be negative.',
      );
    }
    return MoratoriumPlan._(
      months: months,
      type: type,
      tenureTreatment: tenureTreatment,
    );
  }

  const MoratoriumPlan._({
    required this.months,
    required this.type,
    required this.tenureTreatment,
  });

  final int months;
  final MoratoriumType type;
  final MoratoriumTenureTreatment tenureTreatment;

  int repaymentTenureMonths(int originalTenureMonths) {
    if (originalTenureMonths <= 0) {
      throw ArgumentError.value(
        originalTenureMonths,
        'originalTenureMonths',
        'Original tenure must be greater than zero.',
      );
    }
    if (tenureTreatment == MoratoriumTenureTreatment.extendTenure) {
      return originalTenureMonths;
    }
    final remaining = originalTenureMonths - months;
    if (remaining <= 0) {
      throw ArgumentError.value(
        months,
        'months',
        'Moratorium must leave at least one repayment month when it is '
            'included within the original tenure.',
      );
    }
    return remaining;
  }

  MoratoriumPlan copyWith({
    int? months,
    MoratoriumType? type,
    MoratoriumTenureTreatment? tenureTreatment,
  }) {
    return MoratoriumPlan(
      months: months ?? this.months,
      type: type ?? this.type,
      tenureTreatment: tenureTreatment ?? this.tenureTreatment,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MoratoriumPlan &&
            months == other.months &&
            type == other.type &&
            tenureTreatment == other.tenureTreatment;
  }

  @override
  int get hashCode => Object.hash(months, type, tenureTreatment);

  @override
  String toString() {
    return 'MoratoriumPlan('
        'months: $months, '
        'type: ${type.name}, '
        'tenureTreatment: ${tenureTreatment.name}'
        ')';
  }
}
