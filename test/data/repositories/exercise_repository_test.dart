import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/exercise_filter.dart';
import 'package:formcoach/data/repositories/exercise_repository.dart';
import 'package:formcoach/domain/enums.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository repo;
  var idCounter = 0;

  setUp(() {
    idCounter = 0;
    db = AppDatabase(NativeDatabase.memory());
    repo = ExerciseRepository(
      database: db,
      clock: () => DateTime.utc(2026, 9, 20),
      newId: () => 'id-${idCounter++}',
    );
  });
  tearDown(() => db.close());

  Future<Exercise> add(
    String name, {
    ExerciseCategory category = ExerciseCategory.strength,
  }) => repo.createCustom(
    name: name,
    category: category,
    equipment: Equipment.bodyweight,
    primaryMuscles: [MuscleGroup.core],
  );

  Future<List<String>> names([
    ExerciseFilter filter = const ExerciseFilter(),
  ]) async =>
      (await repo.watchExercises(filter).first).map((e) => e.name).toList();

  test('lists exercises ordered by name', () async {
    await add('Zercher squat');
    await add('Arnold press');

    expect(await names(), ['Arnold press', 'Zercher squat']);
  });

  test('search is case-insensitive and matches part of the name', () async {
    await add('Bench press');
    await add('Squat');

    expect(await names(const ExerciseFilter(query: 'BENCH')), ['Bench press']);
    expect(await names(const ExerciseFilter(query: 'qua')), ['Squat']);
  });

  test('search treats wildcard characters literally', () async {
    await add('50% effort run');
    await add('Squat');

    expect(await names(const ExerciseFilter(query: '%')), ['50% effort run']);
    expect(await names(const ExerciseFilter(query: '_')), isEmpty);
  });

  test('filters by category', () async {
    await add('Plank', category: ExerciseCategory.core);
    await add('Squat');

    final result = await names(
      const ExerciseFilter(category: ExerciseCategory.core),
    );

    expect(result, ['Plank']);
  });

  test(
    'coach-supported filter returns only exercises with a coach key',
    () async {
      await add('Squat');
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: 'coach-1',
              name: 'Push-up',
              category: ExerciseCategory.strength,
              equipment: Equipment.bodyweight,
              primaryMuscles: [MuscleGroup.chest],
              coachKey: const Value('pushup'),
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );

      final result = await names(
        const ExerciseFilter(coachSupportedOnly: true),
      );

      expect(result, ['Push-up']);
    },
  );

  test('createCustom trims the name and marks the row as custom', () async {
    final created = await add('  Sled push  ');

    expect(created.name, 'Sled push');
    expect(created.isCustom, isTrue);
    expect(created.id, 'id-0');
  });

  test('createCustom rejects empty and overlong names', () {
    expect(() => add('   '), throwsArgumentError);
    expect(() => add('x' * 101), throwsArgumentError);
  });

  test('deleteCustom hides a custom exercise', () async {
    final created = await add('Sled push');

    final deleted = await repo.deleteCustom(created.id);

    expect(deleted, isTrue);
    expect(await names(), isEmpty);
    expect(await repo.watchById(created.id).first, isNull);
  });

  test('deleteCustom never deletes a built-in exercise', () async {
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: 'builtin',
            name: 'Squat',
            category: ExerciseCategory.strength,
            equipment: Equipment.bodyweight,
            primaryMuscles: [MuscleGroup.quadriceps],
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );

    final deleted = await repo.deleteCustom('builtin');

    expect(deleted, isFalse);
    expect(await names(), ['Squat']);
  });

  test('watchById emits the exercise', () async {
    final created = await add('Sled push');

    final found = await repo.watchById(created.id).first;

    expect(found?.name, 'Sled push');
  });
}
