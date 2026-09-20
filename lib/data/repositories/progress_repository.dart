import 'package:drift/drift.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/watch_load.dart';

/// One set that was done in a finished workout.
class CompletedSetRecord {
  const CompletedSetRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.completedAt,
    this.weightKg,
    this.reps,
    this.durationSeconds,
  });

  final String exerciseId;
  final String exerciseName;
  final DateTime completedAt;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
}

/// The Form Coach's score for one coached set.
class CoachScorePoint {
  const CoachScorePoint({
    required this.exerciseKey,
    required this.score,
    required this.at,
  });

  final String exerciseKey;
  final double score;
  final DateTime at;
}

/// Reads the numbers behind the Progress charts and records. Only workouts
/// that were finished count.
class ProgressRepository {
  ProgressRepository(this._database);

  final AppDatabase _database;

  /// Every completed set of every finished workout. Emits again on change.
  Stream<List<CompletedSetRecord>> watchCompletedSets() => watchLoad(
    database: _database,
    tables: [_database.setLogs, _database.workoutSessions, _database.exercises],
    load: () async {
      final sets = _database.setLogs;
      final sessions = _database.workoutSessions;
      final exercises = _database.exercises;
      final rows =
          await (_database.select(sets).join([
                innerJoin(sessions, sessions.id.equalsExp(sets.sessionId)),
                innerJoin(exercises, exercises.id.equalsExp(sets.exerciseId)),
              ])..where(
                sets.completedAt.isNotNull() &
                    sets.deletedAt.isNull() &
                    sessions.endedAt.isNotNull() &
                    sessions.deletedAt.isNull(),
              ))
              .get();
      return [
        for (final row in rows)
          CompletedSetRecord(
            exerciseId: row.readTable(exercises).id,
            exerciseName: row.readTable(exercises).name,
            completedAt: row.readTable(sets).completedAt!,
            weightKg: row.readTable(sets).weightKg,
            reps: row.readTable(sets).reps,
            durationSeconds: row.readTable(sets).durationSeconds,
          ),
      ];
    },
  );

  /// The coach's scores over time, oldest first.
  Stream<List<CoachScorePoint>> watchCoachScores() => watchLoad(
    database: _database,
    tables: [
      _database.coachAnalyses,
      _database.setLogs,
      _database.workoutSessions,
    ],
    load: () async {
      final analyses = _database.coachAnalyses;
      final sets = _database.setLogs;
      final sessions = _database.workoutSessions;
      final rows =
          await (_database.select(analyses).join([
                innerJoin(sets, sets.id.equalsExp(analyses.setLogId)),
                innerJoin(sessions, sessions.id.equalsExp(sets.sessionId)),
              ])..where(
                analyses.deletedAt.isNull() &
                    analyses.setScore.isNotNull() &
                    sets.deletedAt.isNull() &
                    sessions.endedAt.isNotNull() &
                    sessions.deletedAt.isNull(),
              ))
              .get();
      final points = [
        for (final row in rows)
          CoachScorePoint(
            exerciseKey: row.readTable(analyses).exerciseKey,
            score: row.readTable(analyses).setScore!,
            at: row.readTable(analyses).createdAt,
          ),
      ]..sort((a, b) => a.at.compareTo(b.at));
      return points;
    },
  );
}
