import 'package:formcoach/data/repositories/progress_repository.dart';
import 'package:formcoach/features/form_coach/exercises/registry.dart';
import 'package:formcoach/features/home/streak.dart';

/// The training volume (reps x weight) of one week.
class WeeklyVolume {
  const WeeklyVolume({required this.weekStart, required this.volumeKg});

  /// The Monday of the week, as a local date.
  final DateTime weekStart;
  final double volumeKg;
}

/// Volume per week for the last [weeks] weeks up to and including the week of
/// [now], oldest first. Weeks without training have zero volume.
List<WeeklyVolume> weeklyVolumes(
  Iterable<CompletedSetRecord> sets,
  DateTime now, {
  int weeks = 8,
}) {
  final totals = <DateTime, double>{};
  for (final set in sets) {
    final reps = set.reps;
    final weight = set.weightKg;
    if (reps == null || weight == null) continue;
    totals.update(
      weekStart(set.completedAt),
      (sum) => sum + reps * weight,
      ifAbsent: () => reps * weight,
    );
  }

  final thisWeek = weekStart(now);
  return [
    for (var i = weeks - 1; i >= 0; i--)
      _week(
        DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * i),
        totals,
      ),
  ];
}

WeeklyVolume _week(DateTime start, Map<DateTime, double> totals) =>
    WeeklyVolume(weekStart: start, volumeKg: totals[start] ?? 0);

enum RecordKind { heaviest, mostReps, longestHold, bestForm }

/// A personal best.
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseName,
    required this.kind,
    required this.value,
    required this.achievedAt,
    this.reps,
  });

  final String exerciseName;
  final RecordKind kind;

  /// Kilograms, repetitions, seconds or a 0-100 score, depending on [kind].
  final double value;

  /// For [RecordKind.heaviest]: the repetitions done with that weight.
  final int? reps;
  final DateTime achievedAt;
}

/// The user's personal bests, most recent first: the heaviest weight lifted,
/// the most repetitions without added weight, the longest timed hold, and the
/// best Form Coach score, each per exercise.
List<PersonalRecord> personalRecords(
  Iterable<CompletedSetRecord> sets,
  Iterable<CoachScorePoint> scores,
) {
  final records = <PersonalRecord>[];

  final byExercise = <String, List<CompletedSetRecord>>{};
  for (final set in sets) {
    byExercise.putIfAbsent(set.exerciseId, () => []).add(set);
  }
  for (final group in byExercise.values) {
    final name = group.first.exerciseName;

    final heaviest = _best(
      group,
      (s) => (s.weightKg ?? 0) > 0 && s.reps != null,
      (s) => s.weightKg!,
    );
    if (heaviest != null) {
      records.add(
        PersonalRecord(
          exerciseName: name,
          kind: RecordKind.heaviest,
          value: heaviest.weightKg!,
          reps: heaviest.reps,
          achievedAt: heaviest.completedAt,
        ),
      );
    }

    final mostReps = _best(
      group,
      (s) => (s.weightKg ?? 0) == 0 && (s.reps ?? 0) > 0,
      (s) => s.reps!,
    );
    if (mostReps != null) {
      records.add(
        PersonalRecord(
          exerciseName: name,
          kind: RecordKind.mostReps,
          value: mostReps.reps!.toDouble(),
          achievedAt: mostReps.completedAt,
        ),
      );
    }

    final longest = _best(
      group,
      (s) => s.reps == null && (s.durationSeconds ?? 0) > 0,
      (s) => s.durationSeconds!,
    );
    if (longest != null) {
      records.add(
        PersonalRecord(
          exerciseName: name,
          kind: RecordKind.longestHold,
          value: longest.durationSeconds!.toDouble(),
          achievedAt: longest.completedAt,
        ),
      );
    }
  }

  final bestScores = <String, CoachScorePoint>{};
  for (final point in scores) {
    final current = bestScores[point.exerciseKey];
    if (current == null ||
        point.score > current.score ||
        (point.score == current.score && point.at.isAfter(current.at))) {
      bestScores[point.exerciseKey] = point;
    }
  }
  for (final point in bestScores.values) {
    records.add(
      PersonalRecord(
        exerciseName:
            coachDefinitionFor(point.exerciseKey)?.name ?? point.exerciseKey,
        kind: RecordKind.bestForm,
        value: point.score,
        achievedAt: point.at,
      ),
    );
  }

  records.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
  return records;
}

/// The set matching [where] with the highest [key]; on a tie the most recent.
CompletedSetRecord? _best(
  List<CompletedSetRecord> sets,
  bool Function(CompletedSetRecord) where,
  num Function(CompletedSetRecord) key,
) {
  final candidates = sets.where(where).toList();
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final byValue = key(b).compareTo(key(a));
    return byValue != 0 ? byValue : b.completedAt.compareTo(a.completedAt);
  });
  return candidates.first;
}
