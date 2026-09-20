import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/domain/enums.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 9, 20, 10, 30, 15, 123);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ExercisesCompanion exercise(String id, {String name = 'Squat'}) =>
      ExercisesCompanion.insert(
        id: id,
        name: name,
        category: ExerciseCategory.strength,
        equipment: Equipment.bodyweight,
        primaryMuscles: [MuscleGroup.quadriceps, MuscleGroup.glutes],
        createdAt: now,
        updatedAt: now,
      );

  RoutinesCompanion routine(String id) => RoutinesCompanion.insert(
    id: id,
    name: 'Full body',
    createdAt: now,
    updatedAt: now,
  );

  test('exercise round-trips enums, muscle list and defaults', () async {
    await db.into(db.exercises).insert(exercise('e1'));

    final row = await (db.select(
      db.exercises,
    )..where((e) => e.id.equals('e1'))).getSingle();

    expect(row.category, ExerciseCategory.strength);
    expect(row.equipment, Equipment.bodyweight);
    expect(row.primaryMuscles, [MuscleGroup.quadriceps, MuscleGroup.glutes]);
    expect(row.instructions, isEmpty);
    expect(row.coachKey, isNull);
    expect(row.isCustom, isFalse);
    expect(row.deletedAt, isNull);
  });

  test('timestamps keep millisecond precision and UTC', () async {
    await db.into(db.exercises).insert(exercise('e1'));

    final row = await db.select(db.exercises).getSingle();

    expect(row.createdAt.isUtc, isTrue);
    expect(row.createdAt, now);
  });

  test('routine defaults: not a template, no schedule', () async {
    await db.into(db.routines).insert(routine('r1'));

    final row = await db.select(db.routines).getSingle();

    expect(row.isTemplate, isFalse);
    expect(row.scheduleDays, isEmpty);
  });

  test('schedule days round-trip', () async {
    await db
        .into(db.routines)
        .insert(routine('r1').copyWith(scheduleDays: const Value([1, 3, 5])));

    final row = await db.select(db.routines).getSingle();

    expect(row.scheduleDays, [1, 3, 5]);
  });

  test('foreign keys are enforced', () async {
    final orphan = RoutineExercisesCompanion.insert(
      id: 're1',
      routineId: 'missing-routine',
      exerciseId: 'missing-exercise',
      position: 0,
      createdAt: now,
      updatedAt: now,
    );

    expect(
      db.into(db.routineExercises).insert(orphan),
      throwsA(isA<Exception>()),
    );
  });

  test('deleting a routine cascades to its exercises', () async {
    await db.into(db.exercises).insert(exercise('e1'));
    await db.into(db.routines).insert(routine('r1'));
    await db
        .into(db.routineExercises)
        .insert(
          RoutineExercisesCompanion.insert(
            id: 're1',
            routineId: 'r1',
            exerciseId: 'e1',
            position: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await (db.delete(db.routines)..where((r) => r.id.equals('r1'))).go();

    expect(await db.select(db.routineExercises).get(), isEmpty);
  });

  test('deleting a session cascades to its set logs', () async {
    await db.into(db.exercises).insert(exercise('e1'));
    await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            id: 's1',
            name: 'Push day',
            startedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.setLogs)
        .insert(
          SetLogsCompanion.insert(
            id: 'l1',
            sessionId: 's1',
            exerciseId: 'e1',
            setIndex: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await (db.delete(db.workoutSessions)..where((s) => s.id.equals('s1'))).go();

    expect(await db.select(db.setLogs).get(), isEmpty);
  });
}
