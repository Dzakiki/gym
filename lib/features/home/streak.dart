/// The Monday of the week containing [date], as a local date without time.
DateTime weekStart(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day - (local.weekday - 1));
}

/// How consistently the user has been training.
class WorkoutStreak {
  const WorkoutStreak({required this.weeks, required this.thisWeek});

  /// Consecutive weeks (Monday to Sunday) with at least one workout, ending
  /// with this week or, if nothing has been done yet this week, last week.
  final int weeks;

  /// Workouts done so far this week.
  final int thisWeek;
}

/// Works out the streak from the times workouts were finished, as of [now].
///
/// The streak survives a quiet start to the week: it only breaks once a whole
/// week has passed without a workout.
WorkoutStreak computeStreak(Iterable<DateTime> workoutTimes, DateTime now) {
  final weeks = <DateTime>{for (final time in workoutTimes) weekStart(time)};
  final currentWeek = weekStart(now);
  final thisWeek = workoutTimes
      .where((time) => weekStart(time) == currentWeek)
      .length;

  DateTime previous(DateTime week) =>
      DateTime(week.year, week.month, week.day - 7);

  var cursor = weeks.contains(currentWeek)
      ? currentWeek
      : previous(currentWeek);
  var count = 0;
  while (weeks.contains(cursor)) {
    count++;
    cursor = previous(cursor);
  }
  return WorkoutStreak(weeks: count, thisWeek: thisWeek);
}
