import 'package:drift/drift.dart';
import 'package:formcoach/data/local/tables/exercises.dart';
import 'package:formcoach/data/local/tables/routines.dart';
import 'package:formcoach/data/local/tables/sync_columns.dart';

/// One performed workout. [endedAt] is null while the workout is in progress.
class WorkoutSessions extends Table with SyncColumns {
  TextColumn get id => text()();

  /// The routine this workout was started from, if any.
  TextColumn get routineId => text().nullable().references(Routines, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One performed set. Weight is always stored in kilograms; the UI converts.
@TableIndex(name: 'idx_set_logs_session', columns: {#sessionId})
@TableIndex(name: 'idx_set_logs_exercise', columns: {#exerciseId})
class SetLogs extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get setIndex => integer()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get rpe => real().nullable()();

  /// True when the set was recorded with the AI Form Coach.
  BoolColumn get coached => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
