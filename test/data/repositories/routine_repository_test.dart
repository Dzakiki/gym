import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/routine_draft.dart';
import 'package:formcoach/data/repositories/routine_repository.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:formcoach/data/seed/seed_service.dart';
import 'package:formcoach/data/seed/template_seeder.dart';

import '../../helpers/file_asset_bundle.dart';

void main() {
  late AppDatabase db;
  late RoutineRepository repo;
  var idCounter = 0;
  final pushDayId = TemplateSeeder.routineIdForSlug('push-day');

  setUp(() async {
    idCounter = 0;
    db = AppDatabase(NativeDatabase.memory());
    DateTime clock() => DateTime.utc(2026, 9, 20);
    final bundle = FileAssetBundle();
    await SeedService(
      exercises: ExerciseSeeder(
        database: db,
        assetBundle: bundle,
        clock: clock,
      ),
      templates: TemplateSeeder(
        database: db,
        assetBundle: bundle,
        clock: clock,
      ),
    ).seedAll();
    repo = RoutineRepository(
      database: db,
      clock: clock,
      newId: () => 'new-${idCounter++}',
    );
  });
  tearDown(() => db.close());

  test('lists templates separately from the user routines', () async {
    final templates = await repo.watchRoutines(templates: true).first;
    final mine = await repo.watchRoutines(templates: false).first;

    expect(templates.map((r) => r.name), [
      'Beginner full body',
      'Home bodyweight',
      'Leg day',
      'Pull day',
      'Push day',
    ]);
    expect(mine, isEmpty);
  });

  test('loads a routine with its exercises in order', () async {
    final detail = await repo.watchDetail(pushDayId).first;

    expect(detail, isNotNull);
    expect(detail!.routine.name, 'Push day');
    expect(detail.items.map((i) => i.exercise.name), [
      'Bench press',
      'Dumbbell shoulder press',
      'Lateral raise',
      'Overhead tricep extension',
      'Push-up',
    ]);
    expect(detail.items.first.entry.targetSets, 4);
    expect(detail.items.first.entry.targetReps, 8);
  });

  test('watchDetail is null for an unknown routine', () async {
    expect(await repo.watchDetail('missing').first, isNull);
  });

  test('copyTemplate creates an independent, editable routine', () async {
    final newId = await repo.copyTemplate(pushDayId);

    expect(newId, 'new-0');
    final copy = (await repo.watchDetail(newId!).first)!;
    expect(copy.routine.isTemplate, isFalse);
    expect(copy.routine.name, 'Push day');
    expect(copy.items, hasLength(5));
    expect(copy.items.map((i) => i.entry.id).toSet(), hasLength(5));
    expect(copy.items.every((i) => i.entry.routineId == newId), isTrue);
    expect(await repo.watchRoutines(templates: false).first, hasLength(1));
    expect(await repo.watchRoutines(templates: true).first, hasLength(5));
  });

  test('copyTemplate returns null for a non-template or unknown id', () async {
    final copyId = (await repo.copyTemplate(pushDayId))!;

    expect(await repo.copyTemplate(copyId), isNull);
    expect(await repo.copyTemplate('missing'), isNull);
  });

  test('deleteRoutine hides the routine and its exercises', () async {
    final copyId = (await repo.copyTemplate(pushDayId))!;

    final deleted = await repo.deleteRoutine(copyId);

    expect(deleted, isTrue);
    expect(await repo.watchRoutines(templates: false).first, isEmpty);
    expect(await repo.watchDetail(copyId).first, isNull);
    final rows = await (db.select(
      db.routineExercises,
    )..where((e) => e.routineId.equals(copyId))).get();
    expect(rows.every((r) => r.deletedAt != null), isTrue);
  });

  test('deleteRoutine refuses to delete a template', () async {
    expect(await repo.deleteRoutine(pushDayId), isFalse);
    expect(await repo.watchDetail(pushDayId).first, isNotNull);
  });

  test('watchDetail emits again after a change', () async {
    final copyId = (await repo.copyTemplate(pushDayId))!;
    final emissions = <RoutineDetail?>[];
    final subscription = repo.watchDetail(copyId).listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await repo.deleteRoutine(copyId);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await subscription.cancel();

    expect(emissions.first, isNotNull);
    expect(emissions.last, isNull);
  });

  group('saveRoutine', () {
    final squatId = ExerciseSeeder.idForSlug('squat');
    final plankId = ExerciseSeeder.idForSlug('plank');

    DraftItem squat() =>
        DraftItem.forExercise(exerciseId: squatId, exerciseName: 'Squat');
    DraftItem plank() => DraftItem.forExercise(
      exerciseId: plankId,
      exerciseName: 'Plank',
    ).withSeconds(30);

    test('creates a new routine with ordered exercises', () async {
      final id = await repo.saveRoutine(
        RoutineDraft(
          name: '  My legs ',
          description: 'Leg work',
          scheduleDays: const [2, 4],
          items: [squat(), plank()],
        ),
      );

      final saved = (await repo.getDetail(id))!;
      expect(saved.routine.name, 'My legs');
      expect(saved.routine.isTemplate, isFalse);
      expect(saved.routine.scheduleDays, [2, 4]);
      expect(saved.items.map((i) => i.exercise.name), ['Squat', 'Plank']);
      expect(saved.items.last.entry.targetSeconds, 30);
      expect(saved.items.last.entry.targetReps, isNull);
    });

    test('updates in place: reorders, edits and removes exercises', () async {
      final id = await repo.saveRoutine(
        RoutineDraft(name: 'Legs', items: [squat(), plank()]),
      );
      final original = (await repo.getDetail(id))!;
      final squatRow = original.items.first.entry;
      final plankRow = original.items.last.entry;

      await repo.saveRoutine(
        RoutineDraft(
          id: id,
          name: 'Legs v2',
          items: [
            DraftItem(
              id: plankRow.id,
              exerciseId: plankId,
              exerciseName: 'Plank',
            ).withSeconds(60),
          ],
        ),
      );

      final updated = (await repo.getDetail(id))!;
      expect(updated.routine.name, 'Legs v2');
      expect(updated.items, hasLength(1));
      expect(updated.items.single.entry.id, plankRow.id);
      expect(updated.items.single.entry.position, 0);
      expect(updated.items.single.entry.targetSeconds, 60);
      expect(updated.items.single.entry.createdAt, plankRow.createdAt);
      final removed = await (db.select(
        db.routineExercises,
      )..where((e) => e.id.equals(squatRow.id))).getSingle();
      expect(removed.deletedAt, isNotNull);
    });

    test('rejects an invalid draft without writing anything', () async {
      expect(
        () => repo.saveRoutine(const RoutineDraft(name: '')),
        throwsArgumentError,
      );
      expect(await repo.watchRoutines(templates: false).first, isEmpty);
    });

    test('refuses to edit a template', () async {
      expect(
        () => repo.saveRoutine(
          RoutineDraft(id: pushDayId, name: 'Hacked', items: [squat()]),
        ),
        throwsStateError,
      );
      expect((await repo.getDetail(pushDayId))!.routine.name, 'Push day');
    });

    test('refuses to edit an unknown routine', () async {
      expect(
        () => repo.saveRoutine(
          RoutineDraft(id: 'missing', name: 'x', items: [squat()]),
        ),
        throwsStateError,
      );
    });

    test('rolls back everything if an exercise does not exist', () async {
      final bad = DraftItem.forExercise(
        exerciseId: 'no-such-exercise',
        exerciseName: 'Ghost',
      );

      await expectLater(
        repo.saveRoutine(RoutineDraft(name: 'Broken', items: [squat(), bad])),
        throwsA(anything),
      );

      expect(await repo.watchRoutines(templates: false).first, isEmpty);
    });
  });
}
