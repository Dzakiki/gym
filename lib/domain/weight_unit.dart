/// The unit weights are shown and typed in. Weights are always stored in
/// kilograms; the unit only changes how they are displayed and entered.
enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.label);

  static const _kgPerPound = 0.45359237;

  final String label;

  /// Converts a weight stored in kilograms to this unit.
  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg / _kgPerPound;

  /// Converts a weight typed in this unit to kilograms.
  double toKg(double value) =>
      this == WeightUnit.kg ? value : value * _kgPerPound;
}
