import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/core/ids.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/coach_repository.dart';
import 'package:formcoach/data/repositories/exercise_repository.dart';
import 'package:formcoach/data/repositories/routine_repository.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:formcoach/data/seed/seed_service.dart';
import 'package:formcoach/data/seed/template_seeder.dart';

/// The single on-device database. Tests override this with an in-memory one.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.persistent();
  ref.onDispose(database.close);
  return database;
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository(
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return CoachRepository(
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

final seedServiceProvider = Provider<SeedService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final clock = ref.watch(clockProvider);
  return SeedService(
    exercises: ExerciseSeeder(
      database: database,
      assetBundle: rootBundle,
      clock: clock,
    ),
    templates: TemplateSeeder(
      database: database,
      assetBundle: rootBundle,
      clock: clock,
    ),
  );
});
