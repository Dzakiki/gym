import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:formcoach/data/local/converters.dart';
import 'package:formcoach/data/local/tables/coach_analyses.dart';
import 'package:formcoach/data/local/tables/exercises.dart';
import 'package:formcoach/data/local/tables/routines.dart';
import 'package:formcoach/data/local/tables/workouts.dart';
import 'package:formcoach/domain/enums.dart';

part 'app_database.g.dart';

/// The on-device SQLite database. It is the source of truth for the UI; a
/// sync service (added later) mirrors it to Supabase.
@DriftDatabase(
  tables: [
    Exercises,
    Routines,
    RoutineExercises,
    WorkoutSessions,
    SetLogs,
    CoachAnalyses,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database with a custom [executor] (used by tests).
  AppDatabase(super.e);

  /// Opens the persistent on-device database.
  AppDatabase.persistent() : super(driftDatabase(name: 'formcoach'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      // Version 2 added the coach_analyses table.
      if (from < 2) await migrator.createTable(coachAnalyses);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
