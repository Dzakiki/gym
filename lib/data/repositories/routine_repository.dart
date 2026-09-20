import 'dart:async';

import 'package:drift/drift.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/core/ids.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/routine_draft.dart';

/// One exercise of a routine together with the exercise it refers to.
class RoutineItem {
  const RoutineItem({required this.entry, required this.exercise});

  final RoutineExercise entry;
  final Exercise exercise;
}

/// A routine with its exercises in order.
class RoutineDetail {
  const RoutineDetail({required this.routine, required this.items});

  final Routine routine;
  final List<RoutineItem> items;
}

/// Reads and writes routines and the program templates they are copied from.
class RoutineRepository {
  RoutineRepository({
    required this._database,
    required this._clock,
    required this._newId,
  });

  final AppDatabase _database;
  final Clock _clock;
  final IdGenerator _newId;

  /// The user's routines, or the built-in templates when [templates] is true.
  Stream<List<Routine>> watchRoutines({required bool templates}) {
    final query = _database.select(_database.routines)
      ..where((r) => r.deletedAt.isNull() & r.isTemplate.equals(templates))
      ..orderBy([(r) => OrderingTerm.asc(r.name)]);
    return query.watch();
  }

  /// The routine with [id] and its exercises, or null if it does not exist.
  /// Emits again whenever the routine, its exercises or the exercise
  /// library change.
  Stream<RoutineDetail?> watchDetail(String id) {
    late final StreamController<RoutineDetail?> controller;
    StreamSubscription<void>? updates;

    Future<void> emit() async {
      try {
        final detail = await getDetail(id);
        if (!controller.isClosed) controller.add(detail);
      } on Object catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<RoutineDetail?>(
      onListen: () {
        unawaited(emit());
        updates = _database
            .tableUpdates(
              TableUpdateQuery.onAllTables([
                _database.routines,
                _database.routineExercises,
                _database.exercises,
              ]),
            )
            .listen((_) => unawaited(emit()));
      },
      onCancel: () async {
        await updates?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  /// Loads the routine with [id] and its exercises once.
  Future<RoutineDetail?> getDetail(String id) async {
    final routine = await (_database.select(
      _database.routines,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
    if (routine == null) return null;

    final entries = _database.routineExercises;
    final exercises = _database.exercises;
    final rows =
        await (_database.select(entries).join([
                innerJoin(
                  exercises,
                  exercises.id.equalsExp(entries.exerciseId),
                ),
              ])
              ..where(entries.routineId.equals(id) & entries.deletedAt.isNull())
              ..orderBy([OrderingTerm.asc(entries.position)]))
            .get();

    return RoutineDetail(
      routine: routine,
      items: [
        for (final row in rows)
          RoutineItem(
            entry: row.readTable(entries),
            exercise: row.readTable(exercises),
          ),
      ],
    );
  }

  /// Creates or updates a routine from [draft] and returns its id.
  ///
  /// Throws [ArgumentError] if the draft is invalid and [StateError] if the
  /// routine does not exist or is a read-only template. Exercises removed from
  /// the draft are soft-deleted; the others keep their id and creation time.
  Future<String> saveRoutine(RoutineDraft draft) {
    final error = draft.validationError;
    if (error != null) throw ArgumentError(error);

    return _database.transaction(() async {
      final now = _clock();
      final routineId = draft.id ?? _newId();
      final name = draft.name.trim();
      final description = draft.description.trim();

      if (draft.id == null) {
        await _database
            .into(_database.routines)
            .insert(
              RoutinesCompanion.insert(
                id: routineId,
                name: name,
                description: Value(description),
                scheduleDays: Value(draft.scheduleDays),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        final updated =
            await (_database.update(_database.routines)..where(
                  (r) =>
                      r.id.equals(routineId) &
                      r.isTemplate.equals(false) &
                      r.deletedAt.isNull(),
                ))
                .write(
                  RoutinesCompanion(
                    name: Value(name),
                    description: Value(description),
                    scheduleDays: Value(draft.scheduleDays),
                    updatedAt: Value(now),
                  ),
                );
        if (updated == 0) {
          throw StateError(
            'Routine $routineId does not exist or is read-only.',
          );
        }
      }

      final keptIds = <String>[];
      for (var position = 0; position < draft.items.length; position++) {
        final item = draft.items[position];
        final itemId = item.id ?? _newId();
        keptIds.add(itemId);
        await _database
            .into(_database.routineExercises)
            .insert(
              RoutineExercisesCompanion.insert(
                id: itemId,
                routineId: routineId,
                exerciseId: item.exerciseId,
                position: position,
                targetSets: Value(item.targetSets),
                targetReps: Value(item.targetReps),
                targetSeconds: Value(item.targetSeconds),
                restSeconds: Value(item.restSeconds),
                createdAt: now,
                updatedAt: now,
              ),
              onConflict: DoUpdate(
                (old) => RoutineExercisesCompanion(
                  position: Value(position),
                  targetSets: Value(item.targetSets),
                  targetReps: Value(item.targetReps),
                  targetSeconds: Value(item.targetSeconds),
                  restSeconds: Value(item.restSeconds),
                  updatedAt: Value(now),
                ),
              ),
            );
      }

      await (_database.update(_database.routineExercises)..where(
            (e) =>
                e.routineId.equals(routineId) &
                e.deletedAt.isNull() &
                e.id.isNotIn(keptIds),
          ))
          .write(
            RoutineExercisesCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return routineId;
    });
  }

  /// Copies a template into a new, editable routine of the user.
  /// Returns the new routine's id, or null if [templateId] is not a template.
  Future<String?> copyTemplate(String templateId) {
    return _database.transaction(() async {
      final template = await getDetail(templateId);
      if (template == null || !template.routine.isTemplate) return null;

      final now = _clock();
      final routineId = _newId();
      await _database
          .into(_database.routines)
          .insert(
            RoutinesCompanion.insert(
              id: routineId,
              name: template.routine.name,
              description: Value(template.routine.description),
              scheduleDays: Value(template.routine.scheduleDays),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final item in template.items) {
        await _database
            .into(_database.routineExercises)
            .insert(
              RoutineExercisesCompanion.insert(
                id: _newId(),
                routineId: routineId,
                exerciseId: item.entry.exerciseId,
                position: item.entry.position,
                targetSets: Value(item.entry.targetSets),
                targetReps: Value(item.entry.targetReps),
                targetSeconds: Value(item.entry.targetSeconds),
                targetWeightKg: Value(item.entry.targetWeightKg),
                restSeconds: Value(item.entry.restSeconds),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      return routineId;
    });
  }

  /// Soft-deletes a routine and its exercises. Templates cannot be deleted.
  /// Returns true if a routine was deleted.
  Future<bool> deleteRoutine(String id) {
    return _database.transaction(() async {
      final now = _clock();
      final deleted =
          await (_database.update(_database.routines)..where(
                (r) =>
                    r.id.equals(id) &
                    r.isTemplate.equals(false) &
                    r.deletedAt.isNull(),
              ))
              .write(
                RoutinesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
              );
      if (deleted == 0) return false;

      await (_database.update(
        _database.routineExercises,
      )..where((e) => e.routineId.equals(id) & e.deletedAt.isNull())).write(
        RoutineExercisesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      return true;
    });
  }
}
