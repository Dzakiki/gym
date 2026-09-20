import 'package:formcoach/data/local/app_database.dart';

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Short name of an ISO weekday (1 = Monday ... 7 = Sunday).
String weekdayLabel(int isoWeekday) {
  RangeError.checkValueInInterval(isoWeekday, 1, 7, 'isoWeekday');
  return _weekdayNames[isoWeekday - 1];
}

/// Describes the target of one routine exercise, e.g. `3 x 10` or `3 x 30 s`.
String formatTarget(RoutineExercise entry) {
  final sets = entry.targetSets;
  if (entry.targetReps != null) return '$sets x ${entry.targetReps}';
  if (entry.targetSeconds != null) return '$sets x ${entry.targetSeconds} s';
  return '$sets sets';
}

/// Formats a rest period in seconds, e.g. `90 s` or `2 min`.
String formatRest(int seconds) {
  if (seconds >= 60 && seconds % 60 == 0) return '${seconds ~/ 60} min';
  return '$seconds s';
}
