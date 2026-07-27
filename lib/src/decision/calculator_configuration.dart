void validateDecisionCalculatorConfiguration({
  required int calculationScale,
  required int maximumIterations,
}) {
  if (calculationScale <= 0) {
    throw ArgumentError.value(
      calculationScale,
      'calculationScale',
      'Must be greater than zero.',
    );
  }
  if (maximumIterations <= 0) {
    throw ArgumentError.value(
      maximumIterations,
      'maximumIterations',
      'Must be greater than zero.',
    );
  }
}
