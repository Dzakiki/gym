import 'package:drift/drift.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/core/ids.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/watch_load.dart';

/// One exercise of a workout with the sets logged or planned for it.
class ActiveExercise {
  const ActiveExercise({
    required this.exercise,
    required this.sets,
    required this.restSeconds,
  });

  final Exercise exercise;

  /// Sets in order. A set is done when its `completedAt` is not null.
  final List<SetLog> sets;

  /// Suggested rest after a set, taken from the routine or the default.
  final int restSeconds;
}

/// A workout session with its exercises in order.
class ActiveWorkout {
  const ActiveWorkout({required this.session, required this.exercises});

  final WorkoutSession session;
  final List<ActiveExercise> exercises;

  bool get isFinished => session.endedAt != null;

  int get completedSets => exercises.fold(
    0,
    (sum, e) => sum + e.sets.where((s) => s.completedAt != null).length,
  );
}

/// What a finished workout amounted to.
class WorkoutSummary {
  const WorkoutSummary({
    required this.duration,
    required this.completedSets,
    required this.volumeKg,
  });

  final Duration duration;
  final int completedSets;

  /// Sum of reps x weight over the completed sets that have both.
  final double volumeKg;
}

/// Starts, edits and finishes workouts.
class WorkoutRepository {
  WorkoutRepository({
    required this._database,
    required this._clock,
    required this._newId,
  });

  static const defaultRestSeconds = 90;
  static const maxReps = 1000;
  static const maxWeightKg = 1000.0;
  static const maxDurationSeconds = 3600;

  final AppDatabase _database;
  final Clock _clock;
  final IdGenerator _newId;

  SimpleSelectStatement<$WorkoutSessionsTable, WorkoutSession> _activeQuery() {
    return _database.select(_database.workoutSessions)
      ..where((s) => s.endedAt.isNull() & s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
      ..limit(1);
  }

  /// The workout in progress, or null. Emits again when it changes.
  Stream<WorkoutSession?> watchActiveSession() =>
      _activeQuery().watchSingleOrNull();

  /// The workout in progress right now, or null.
  Future<WorkoutSession?> getActiveSession() =>
      _activeQuery().getSingleOrNull();

  /// The workout with [id] and its sets, or null if it does not exist.
  Stream<ActiveWorkout?> watchWorkout(String id) => watchLoad(
    database: _database,
    tables: [
      _database.workoutSessions,
      _database.setLogs,
      _database.exercises,
      _database.routineExercises,
    ],
    load: () => getWorkout(id),
  );

  /// Loads the workout with [id] once.
  Future<ActiveWorkout?> getWorkout(String id) async {
    final session = await (_database.select(
      _database.workoutSessions,
    )..where((s) => s.id.equals(id) & s.deletedAt.isNull())).getSingleOrNull();
    if (session == null) return null;

    final sets = _database.setLogs;
    final exercises = _database.exercises;
    final rows =
        await (_database.select(sets).join([
                innerJoin(exercises, exercises.id.equalsExp(sets.exerciseId)),
              ])
              ..where(sets.sessionId.equals(id) & sets.deletedAt.isNull())
              ..orderBy([
                OrderingTerm.asc(sets.exerciseOrder),
                OrderingTerm.asc(sets.setIndex),
              ]))
            .get();

    final rest = await _restByExercise(session.routineId);
    final grouped = <String, List<SetLog>>{};
    final byId = <String, Exercise>{};
    for (final row in rows) {
      final exercise = row.readTable(exercises);
      byId[exercise.id] = exercise;
      grouped.putIfAbsent(exercise.id, () => []).add(row.readTable(sets));
    }
    return ActiveWorkout(
      session: session,
      exercises: [
        for (final entry in grouped.entries)
          ActiveExercise(
            exercise: byId[entry.key]!,
            sets: entry.value,
            restSeconds: rest[entry.key] ?? defaultRestSeconds,
          ),
      ],
    );
  }

  Future<Map<String, int>> _restByExercise(String? routineId) async {
    if (routineId == null) return const {};
    final entries =
        await (_database.select(_database.routineExercises)..where(
              (e) => e.routineId.equals(routineId) & e.deletedAt.isNull(),
            ))
            .get();
    return {for (final e in entries) e.exerciseId: e.restSeconds};
  }

  /// Starts a workout, optionally from a routine or template, and returns its
  /// id. The routine's planned sets are created ready to be ticked off.
  /// Throws [StateError] if a workout is already in progress or the routine
  /// does not exist.
  Future<String> startWorkout({String? routineId}) {
    return _database.transaction(() async {
      final active = await getActiveSession();
      if (active != null) throw StateError('A workout is already in progress.');

      final now = _clock();
      var name = 'Workout';
      List<RoutineExercise> plan = const [];
      if (routineId != null) {
        final routine =
            await (_database.select(_database.routines)
                  ..where((r) => r.id.equals(routineId) & r.deletedAt.isNull()))
                .getSingleOrNull();
        if (routine == null) throw StateError('Routine $routineId not found.');
        name = routine.name;
        plan =
            await (_database.select(_database.routineExercises)
                  ..where(
                    (e) => e.routineId.equals(routineId) & e.deletedAt.isNull(),
                  )
                  ..orderBy([(e) => OrderingTerm.asc(e.position)]))
                .get();
      }

      final sessionId = _newId();
      await _database
          .into(_database.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              id: sessionId,
              routineId: Value(routineId),
              name: name,
              startedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (var order = 0; order < plan.length; order++) {
        final item = plan[order];
        for (var index = 0; index < item.targetSets; index++) {
          await _insertSet(
            sessionId: sessionId,
            exerciseId: item.exerciseId,
            exerciseOrder: order,
            setIndex: index,
            reps: item.targetReps,
            weightKg: item.targetWeightKg,
            durationSeconds: item.targetSeconds,
            now: now,
          );
        }
      }
      return sessionId;
    });
  }

  Future<void> _insertSet({
    required String sessionId,
    required String exerciseId,
    required int exerciseOrder,
    required int setIndex,
    required DateTime now,
    int? reps,
    double? weightKg,
    int? durationSeconds,
  }) {
    return _database
        .into(_database.setLogs)
        .insert(
          SetLogsCompanion.insert(
            id: _newId(),
            sessionId: sessionId,
            exerciseId: exerciseId,
            exerciseOrder: Value(exerciseOrder),
            setIndex: setIndex,
            reps: Value(reps),
            weightKg: Value(weightKg),
            durationSeconds: Value(durationSeconds),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Adds [exerciseId] to the end of an unfinished workout with one empty set.
  /// If the workout already has the exercise, one more set is added to it.
  Future<void> addExercise(String sessionId, String exerciseId) {
    return _database.transaction(() async {
      await _requireOpen(sessionId);
      final existing =
          await (_database.select(_database.setLogs)..where(
                (s) =>
                    s.sessionId.equals(sessionId) &
                    s.exerciseId.equals(exerciseId) &
                    s.deletedAt.isNull(),
              ))
              .get();
      if (existing.isNotEmpty) return addSet(sessionId, exerciseId);
      final order = _database.setLogs.exerciseOrder.max();
      final highest =
          await (_database.selectOnly(_database.setLogs)
                ..addColumns([order])
                ..where(
                  _database.setLogs.sessionId.equals(sessionId) &
                      _database.setLogs.deletedAt.isNull(),
                ))
              .map((row) => row.read(order))
              .getSingle();
      await _insertSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        exerciseOrder: highest == null ? 0 : highest + 1,
        setIndex: 0,
        now: _clock(),
      );
    });
  }

  /// Adds one more set to an exercise, copying the previous set's numbers.
  Future<void> addSet(String sessionId, String exerciseId) {
    return _database.transaction(() async {
      await _requireOpen(sessionId);
      final existing =
          await (_database.select(_database.setLogs)
                ..where(
                  (s) =>
                      s.sessionId.equals(sessionId) &
                      s.exerciseId.equals(exerciseId) &
                      s.deletedAt.isNull(),
                )
                ..orderBy([(s) => OrderingTerm.asc(s.setIndex)]))
              .get();
      if (existing.isEmpty) {
        throw StateError('Exercise $exerciseId is not part of this workout.');
      }
      final last = existing.last;
      await _insertSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        exerciseOrder: last.exerciseOrder,
        setIndex: last.setIndex + 1,
        reps: last.reps,
        weightKg: last.weightKg,
        durationSeconds: last.durationSeconds,
        now: _clock(),
      );
    });
  }

  /// Sets the reps of a set. Pass null to clear. Throws [ArgumentError] if
  /// the value is negative or above [maxReps].
  Future<void> updateSetReps(String setId, int? reps) {
    if (reps != null && (reps < 0 || reps > maxReps)) {
      throw ArgumentError.value(reps, 'reps', 'must be 0-$maxReps');
    }
    return _updateSet(setId, SetLogsCompanion(reps: Value(reps)));
  }

  /// Sets the weight of a set in kg. Pass null to clear. Throws
  /// [ArgumentError] if the value is negative or above [maxWeightKg].
  Future<void> updateSetWeight(String setId, double? weightKg) {
    if (weightKg != null && (weightKg < 0 || weightKg > maxWeightKg)) {
      throw ArgumentError.value(weightKg, 'weightKg', 'must be 0-$maxWeightKg');
    }
    return _updateSet(setId, SetLogsCompanion(weightKg: Value(weightKg)));
  }

  /// Sets the duration of a timed set in seconds. Pass null to clear. Throws
  /// [ArgumentError] if the value is negative or above [maxDurationSeconds].
  Future<void> updateSetDuration(String setId, int? seconds) {
    if (seconds != null && (seconds < 0 || seconds > maxDurationSeconds)) {
      throw ArgumentError.value(
        seconds,
        'seconds',
        'must be 0-$maxDurationSeconds',
      );
    }
    return _updateSet(setId, SetLogsCompanion(durationSeconds: Value(seconds)));
  }

  /// Marks a set as done or not done.
  Future<void> setCompleted(String setId, {required bool completed}) {
    return _updateSet(
      setId,
      SetLogsCompanion(completedAt: Value(completed ? _clock() : null)),
    );
  }

  Future<void> _updateSet(String setId, SetLogsCompanion changes) async {
    final updated =
        await (_database.update(_database.setLogs)
              ..where((s) => s.id.equals(setId) & s.deletedAt.isNull()))
            .write(changes.copyWith(updatedAt: Value(_clock())));
    if (updated == 0) throw StateError('Set $setId not found.');
  }

  /// Removes a set from an unfinished workout.
  Future<void> removeSet(String setId) async {
    final now = _clock();
    await (_database.update(_database.setLogs)
          ..where((s) => s.id.equals(setId) & s.deletedAt.isNull()))
        .write(SetLogsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  Future<void> _requireOpen(String sessionId) async {
    final session =
        await (_database.select(_database.workoutSessions)
              ..where((s) => s.id.equals(sessionId) & s.deletedAt.isNull()))
            .getSingleOrNull();
    if (session == null) throw StateError('Workout $sessionId not found.');
    if (session.endedAt != null) {
      throw StateError('Workout $sessionId is already finished.');
    }
  }

  /// Finishes a workout. Sets that were not completed are dropped. A workout
  /// with no completed sets is discarded and null is returned.
  Future<WorkoutSummary?> finishWorkout(String sessionId) {
    return _database.transaction(() async {
      await _requireOpen(sessionId);
      final now = _clock();
      final sets =
          await (_database.select(_database.setLogs)..where(
                (s) => s.sessionId.equals(sessionId) & s.deletedAt.isNull(),
              ))
              .get();
      final done = sets.where((s) => s.completedAt != null).toList();
      if (done.isEmpty) {
        await discardWorkout(sessionId);
        return null;
      }

      await (_database.update(_database.setLogs)..where(
            (s) =>
                s.sessionId.equals(sessionId) &
                s.completedAt.isNull() &
                s.deletedAt.isNull(),
          ))
          .write(
            SetLogsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );
      await (_database.update(
        _database.workoutSessions,
      )..where((s) => s.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(endedAt: Value(now), updatedAt: Value(now)),
      );

      final session = await (_database.select(
        _database.workoutSessions,
      )..where((s) => s.id.equals(sessionId))).getSingle();
      return WorkoutSummary(
        duration: now.difference(session.startedAt),
        completedSets: done.length,
        volumeKg: done.fold(
          0,
          (sum, s) => sum + (s.reps ?? 0) * (s.weightKg ?? 0),
        ),
      );
    });
  }

  /// Deletes an unfinished workout and its sets.
  Future<void> discardWorkout(String sessionId) {
    return _database.transaction(() async {
      final now = _clock();
      await (_database.update(
            _database.setLogs,
          )..where((s) => s.sessionId.equals(sessionId) & s.deletedAt.isNull()))
          .write(
            SetLogsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );
      await (_database.update(
        _database.workoutSessions,
      )..where((s) => s.id.equals(sessionId) & s.deletedAt.isNull())).write(
        WorkoutSessionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }
}
