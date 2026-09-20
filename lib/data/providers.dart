import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/core/ids.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/exercise_repository.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';

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

final exerciseSeederProvider = Provider<ExerciseSeeder>((ref) {
  return ExerciseSeeder(
    database: ref.watch(appDatabaseProvider),
    assetBundle: rootBundle,
    clock: ref.watch(clockProvider),
  );
});
