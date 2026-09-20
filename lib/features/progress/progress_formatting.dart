import 'package:formcoach/domain/weight_unit.dart';
import 'package:formcoach/features/progress/progress_stats.dart';
import 'package:formcoach/features/workout/set_input.dart';

/// Describes a personal record, e.g. `Bench press, heaviest: 80 kg x 5`.
String describeRecord(PersonalRecord record, WeightUnit unit) {
  final name = record.exerciseName;
  return switch (record.kind) {
    RecordKind.heaviest =>
      '$name, heaviest: '
          '${formatWeight(record.value, unit: unit)} ${unit.label}'
          '${record.reps == null ? '' : ' x ${record.reps}'}',
    RecordKind.mostReps => '$name, most reps: ${record.value.round()}',
    RecordKind.longestHold => '$name, longest hold: ${record.value.round()} s',
    RecordKind.bestForm => '$name, best form: ${record.value.round()}',
  };
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A short day and month for a chart axis, e.g. `21 Sep`.
String shortDate(DateTime date) => '${date.day} ${_months[date.month - 1]}';
