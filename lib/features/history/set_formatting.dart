import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/domain/weight_unit.dart';
import 'package:formcoach/features/workout/set_input.dart';

/// Describes a logged set, e.g. `62.5 kg x 8`, `8 reps` or `45 s`.
String formatSetLog(SetLog set, {WeightUnit unit = WeightUnit.kg}) {
  final weight = set.weightKg == null
      ? null
      : '${formatWeight(set.weightKg, unit: unit)} ${unit.label}';
  final reps = set.reps;
  final seconds = set.durationSeconds;

  if (reps != null) {
    return weight == null ? '$reps reps' : '$weight x $reps';
  }
  if (seconds != null) {
    return weight == null ? '$seconds s' : '$weight, $seconds s';
  }
  return weight ?? 'No data';
}
