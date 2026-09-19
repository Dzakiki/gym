import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:formcoach/data/local/converters.dart';
import 'package:formcoach/data/local/tables/exercises.dart';
import 'package:formcoach/data/local/tables/routines.dart';
import 'package:formcoach/data/local/tables/workouts.dart';
import 'package:formcoach/domain/enums.dart';

part 'app_database.g.dart';

/// The on-device SQLite database. It is the source of truth for the UI; a
/// sync service (added later) mirrors it to Supabase.
@DriftDatabase(
  tables: [Exercises, Routines, RoutineExercises, WorkoutSessions, SetLogs],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database with a custom [executor] (used by tests).
  AppDatabase(super.e);

  /// Opens the persistent on-device database.
  AppDatabase.persistent() : super(driftDatabase(name: 'formcoach'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
