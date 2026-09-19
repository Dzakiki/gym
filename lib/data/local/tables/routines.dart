import 'package:drift/drift.dart';
import 'package:formcoach/data/local/converters.dart';
import 'package:formcoach/data/local/tables/exercises.dart';
import 'package:formcoach/data/local/tables/sync_columns.dart';

/// A named workout plan. Templates are read-only starting points that users
/// copy into their own routines.
class Routines extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();

  /// ISO weekdays (1 = Monday ... 7 = Sunday) this routine is scheduled on.
  TextColumn get scheduleDays =>
      text().map(const IntListConverter()).withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One exercise inside a routine, with its targets. Ordered by [position].
@TableIndex(name: 'idx_routine_exercises_routine', columns: {#routineId})
class RoutineExercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get routineId =>
      text().references(Routines, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetSeconds => integer().nullable()();
  RealColumn get targetWeightKg => real().nullable()();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
