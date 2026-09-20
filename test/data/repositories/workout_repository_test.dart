import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:formcoach/data/seed/seed_service.dart';
import 'package:formcoach/data/seed/template_seeder.dart';

import '../../helpers/file_asset_bundle.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository repo;
  var now = DateTime.utc(2026, 9, 20, 10);
  var idCounter = 0;

  final pushDayId = TemplateSeeder.routineIdForSlug('push-day');
  final squatId = ExerciseSeeder.idForSlug('squat');
  final plankId = ExerciseSeeder.idForSlug('plank');
  final benchId = ExerciseSeeder.idForSlug('bench-press');

  setUp(() async {
    now = DateTime.utc(2026, 9, 20, 10);
    idCounter = 0;
    db = AppDatabase(NativeDatabase.memory());
    final bundle = FileAssetBundle();
    DateTime clock() => now;
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
    repo = WorkoutRepository(
      database: db,
      clock: clock,
      newId: () => 'id-${idCounter++}',
    );
  });
  tearDown(() => db.close());

  Future<ActiveWorkout> load(String id) async => (await repo.getWorkout(id))!;

  group('startWorkout', () {
    test('an empty workout has a default name and no sets', () async {
      final id = await repo.startWorkout();

      final workout = await load(id);
      expect(workout.session.name, 'Workout');
      expect(workout.session.routineId, isNull);
      expect(workout.exercises, isEmpty);
      expect((await repo.watchActiveSession().first)?.id, id);
    });

    test('from a routine it plans every set in order', () async {
      final id = await repo.startWorkout(routineId: pushDayId);

      final workout = await load(id);
      expect(workout.session.name, 'Push day');
      expect(
        workout.exercises.map((e) => e.exercise.name).first,
        'Bench press',
      );
      expect(workout.exercises, hasLength(5));
      expect(workout.exercises.first.sets, hasLength(4));
      expect(workout.exercises.first.sets.map((s) => s.setIndex), [0, 1, 2, 3]);
      expect(workout.exercises.first.sets.first.reps, 8);
      expect(workout.exercises.first.restSeconds, 120);
      expect(workout.completedSets, 0);
    });

    test('refuses to start while another workout is in progress', () async {
      await repo.startWorkout();

      expect(() => repo.startWorkout(), throwsStateError);
    });

    test('fails for an unknown routine', () async {
      expect(() => repo.startWorkout(routineId: 'missing'), throwsStateError);
      expect(await repo.watchActiveSession().first, isNull);
    });
  });

  group('editing sets', () {
    test('addExercise appends an exercise with one empty set', () async {
      final id = await repo.startWorkout(routineId: pushDayId);

      await repo.addExercise(id, squatId);

      final workout = await load(id);
      expect(workout.exercises.last.exercise.name, 'Squat');
      expect(workout.exercises.last.sets, hasLength(1));
      expect(workout.exercises.last.sets.single.reps, isNull);
      expect(workout.exercises.last.restSeconds, 90);
    });

    test('addExercise on an existing exercise adds a set instead', () async {
      final id = await repo.startWorkout(routineId: pushDayId);

      await repo.addExercise(id, benchId);

      final workout = await load(id);
      expect(workout.exercises, hasLength(5));
      expect(workout.exercises.first.sets, hasLength(5));
    });

    test('addSet copies the previous set and increments the index', () async {
      final id = await repo.startWorkout(routineId: pushDayId);

      await repo.addSet(id, benchId);

      final sets = (await load(id)).exercises.first.sets;
      expect(sets, hasLength(5));
      expect(sets.last.setIndex, 4);
      expect(sets.last.reps, 8);
    });

    test('addSet fails for an exercise that is not in the workout', () async {
      final id = await repo.startWorkout();

      expect(() => repo.addSet(id, squatId), throwsStateError);
    });

    test('reps and weight can be set and cleared', () async {
      final id = await repo.startWorkout(routineId: pushDayId);
      final setId = (await load(id)).exercises.first.sets.first.id;

      await repo.updateSetReps(setId, 10);
      await repo.updateSetWeight(setId, 62.5);
      var set = (await load(id)).exercises.first.sets.first;
      expect(set.reps, 10);
      expect(set.weightKg, 62.5);

      await repo.updateSetReps(setId, null);
      set = (await load(id)).exercises.first.sets.first;
      expect(set.reps, isNull);
      expect(set.weightKg, 62.5);
    });

    test('rejects out-of-range reps and weight', () async {
      final id = await repo.startWorkout(routineId: pushDayId);
      final setId = (await load(id)).exercises.first.sets.first.id;

      expect(() => repo.updateSetReps(setId, -1), throwsArgumentError);
      expect(() => repo.updateSetReps(setId, 1001), throwsArgumentError);
      expect(() => repo.updateSetWeight(setId, -1), throwsArgumentError);
      expect(() => repo.updateSetWeight(setId, 1000.5), throwsArgumentError);
    });

    test('duration can be set, cleared and is validated', () async {
      final id = await repo.startWorkout(routineId: pushDayId);
      final setId = (await load(id)).exercises.first.sets.first.id;

      await repo.updateSetDuration(setId, 45);
      expect((await load(id)).exercises.first.sets.first.durationSeconds, 45);
      await repo.updateSetDuration(setId, null);
      expect(
        (await load(id)).exercises.first.sets.first.durationSeconds,
        isNull,
      );
      expect(() => repo.updateSetDuration(setId, -1), throwsArgumentError);
      expect(() => repo.updateSetDuration(setId, 3601), throwsArgumentError);
    });

    test('updating an unknown set fails', () async {
      expect(() => repo.updateSetReps('missing', 5), throwsStateError);
    });

    test('completing a set records the time; undoing clears it', () async {
      final id = await repo.startWorkout(routineId: pushDayId);
      final setId = (await load(id)).exercises.first.sets.first.id;
      now = DateTime.utc(2026, 9, 20, 10, 5);

      await repo.setCompleted(setId, completed: true);
      expect((await load(id)).exercises.first.sets.first.completedAt, now);
      expect((await load(id)).completedSets, 1);

      await repo.setCompleted(setId, completed: false);
      expect((await load(id)).exercises.first.sets.first.completedAt, isNull);
    });

    test('removeSet hides the set', () async {
      final id = await repo.startWorkout(routineId: pushDayId);
      final setId = (await load(id)).exercises.first.sets.first.id;

      await repo.removeSet(setId);

      expect((await load(id)).exercises.first.sets, hasLength(3));
    });
  });

  group('finishing', () {
    test('drops unfinished sets and summarises the rest', () async {
      final id = await repo.startWorkout(routineId: pushDayId);
      final sets = (await load(id)).exercises.first.sets;
      await repo.updateSetWeight(sets[0].id, 60);
      await repo.updateSetWeight(sets[1].id, 60);
      await repo.setCompleted(sets[0].id, completed: true);
      await repo.setCompleted(sets[1].id, completed: true);
      now = DateTime.utc(2026, 9, 20, 10, 45);

      final summary = await repo.finishWorkout(id);

      expect(summary!.completedSets, 2);
      expect(summary.duration, const Duration(minutes: 45));
      expect(summary.volumeKg, 2 * 8 * 60);
      final finished = await load(id);
      expect(finished.isFinished, isTrue);
      expect(finished.exercises, hasLength(1));
      expect(finished.exercises.single.sets, hasLength(2));
      expect(await repo.watchActiveSession().first, isNull);
    });

    test('a new workout can start after finishing', () async {
      final id = await repo.startWorkout(routineId: pushDayId);
      final setId = (await load(id)).exercises.first.sets.first.id;
      await repo.setCompleted(setId, completed: true);
      await repo.finishWorkout(id);

      expect(await repo.startWorkout(), isNotNull);
    });

    test('a workout with no completed sets is discarded', () async {
      final id = await repo.startWorkout(routineId: pushDayId);

      final summary = await repo.finishWorkout(id);

      expect(summary, isNull);
      expect(await repo.getWorkout(id), isNull);
      expect(await repo.watchActiveSession().first, isNull);
    });

    test('a finished workout cannot be changed or finished again', () async {
      final id = await repo.startWorkout(routineId: pushDayId);
      final setId = (await load(id)).exercises.first.sets.first.id;
      await repo.setCompleted(setId, completed: true);
      await repo.finishWorkout(id);

      expect(() => repo.finishWorkout(id), throwsStateError);
      expect(() => repo.addSet(id, benchId), throwsStateError);
      expect(() => repo.addExercise(id, plankId), throwsStateError);
    });

    test('discardWorkout hides the session and its sets', () async {
      final id = await repo.startWorkout(routineId: pushDayId);

      await repo.discardWorkout(id);

      expect(await repo.getWorkout(id), isNull);
      final sets = await (db.select(
        db.setLogs,
      )..where((s) => s.sessionId.equals(id))).get();
      expect(sets.every((s) => s.deletedAt != null), isTrue);
    });
  });

  group('history', () {
    test('lists finished workouts newest first with their totals', () async {
      final first = await repo.startWorkout(routineId: pushDayId);
      final firstSet = (await load(first)).exercises.first.sets.first;
      await repo.updateSetWeight(firstSet.id, 50);
      await repo.setCompleted(firstSet.id, completed: true);
      now = DateTime.utc(2026, 9, 20, 10, 30);
      await repo.finishWorkout(first);

      now = DateTime.utc(2026, 9, 21, 9);
      final second = await repo.startWorkout();
      await repo.addExercise(second, plankId);
      final plankSet = (await load(second)).exercises.single.sets.single;
      await repo.setCompleted(plankSet.id, completed: true);
      now = DateTime.utc(2026, 9, 21, 9, 20);
      await repo.finishWorkout(second);

      final history = await repo.watchHistory().first;

      expect(history.map((e) => e.session.id), [second, first]);
      expect(history.first.completedSets, 1);
      expect(history.first.volumeKg, 0);
      expect(history.first.duration, const Duration(minutes: 20));
      expect(history.last.completedSets, 1);
      expect(history.last.volumeKg, 8 * 50);
    });

    test('leaves out unfinished, discarded and deleted workouts', () async {
      final active = await repo.startWorkout(routineId: pushDayId);
      expect(await repo.watchHistory().first, isEmpty);

      final setId = (await load(active)).exercises.first.sets.first.id;
      await repo.setCompleted(setId, completed: true);
      await repo.finishWorkout(active);
      expect(await repo.watchHistory().first, hasLength(1));

      await repo.discardWorkout(active);
      expect(await repo.watchHistory().first, isEmpty);
    });
  });

  test('watchWorkout emits again after a change', () async {
    final id = await repo.startWorkout(routineId: pushDayId);
    final setId = (await load(id)).exercises.first.sets.first.id;
    final emissions = <ActiveWorkout?>[];
    final subscription = repo.watchWorkout(id).listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await repo.setCompleted(setId, completed: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await subscription.cancel();

    expect(emissions.first!.completedSets, 0);
    expect(emissions.last!.completedSets, 1);
  });
}
