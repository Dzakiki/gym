import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
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
}
