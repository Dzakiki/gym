import 'package:drift/drift.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/core/ids.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/exercise_filter.dart';
import 'package:formcoach/domain/enums.dart';

/// Reads and writes the exercise library.
class ExerciseRepository {
  ExerciseRepository({
    required this._database,
    required this._clock,
    required this._newId,
  });

  static const maxNameLength = 100;

  final AppDatabase _database;
  final Clock _clock;
  final IdGenerator _newId;

  /// Exercises matching [filter], ordered by name. Emits again on any change.
  Stream<List<Exercise>> watchExercises([
    ExerciseFilter filter = const ExerciseFilter(),
  ]) {
    final query = _database.select(_database.exercises)
      ..where((e) => e.deletedAt.isNull())
      ..orderBy([(e) => OrderingTerm.asc(e.name)]);

    final text = filter.query.trim();
    if (text.isNotEmpty) {
      query.where(
        (e) => e.name.like('%${_escapeLike(text)}%', escapeChar: r'\'),
      );
    }
    final category = filter.category;
    if (category != null) {
      query.where((e) => e.category.equalsValue(category));
    }
    if (filter.coachSupportedOnly) {
      query.where((e) => e.coachKey.isNotNull());
    }
    return query.watch();
  }

  /// The exercise with [id], or null if it does not exist or was deleted.
  Stream<Exercise?> watchById(String id) {
    final query = _database.select(_database.exercises)
      ..where((e) => e.id.equals(id) & e.deletedAt.isNull());
    return query.watchSingleOrNull();
  }

  /// Creates a user-made exercise. Throws [ArgumentError] for an invalid name.
  Future<Exercise> createCustom({
    required String name,
    required ExerciseCategory category,
    required Equipment equipment,
    required List<MuscleGroup> primaryMuscles,
    String instructions = '',
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'must be 1-$maxNameLength characters',
      );
    }
    final now = _clock();
    return _database
        .into(_database.exercises)
        .insertReturning(
          ExercisesCompanion.insert(
            id: _newId(),
            name: trimmed,
            category: category,
            equipment: equipment,
            primaryMuscles: primaryMuscles,
            instructions: Value(instructions.trim()),
            isCustom: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Soft-deletes a user-made exercise. Built-in exercises are never deleted.
  /// Returns true if a row was deleted.
  Future<bool> deleteCustom(String id) async {
    final now = _clock();
    final updated =
        await (_database.update(
          _database.exercises,
        )..where((e) => e.id.equals(id) & e.isCustom.equals(true))).write(
          ExercisesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
    return updated > 0;
  }

  /// Escapes LIKE wildcards so user input is matched literally.
  static String _escapeLike(String input) => input
      .replaceAll(r'\', r'\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
