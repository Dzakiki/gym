import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/coach_repository.dart';
import 'package:formcoach/data/repositories/coach_result.dart';
import 'package:formcoach/data/repositories/progress_repository.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:formcoach/data/seed/seed_service.dart';
import 'package:formcoach/data/seed/template_seeder.dart';

import '../../helpers/file_asset_bundle.dart';

void main() {
  late AppDatabase db;
  late ProgressRepository progress;
  late WorkoutRepository workouts;
  late CoachRepository coach;
  var now = DateTime.utc(2026, 9, 21, 10);
  var idCounter = 0;

  setUp(() async {
    now = DateTime.utc(2026, 9, 21, 10);
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
    progress = ProgressRepository(db);
    workouts = WorkoutRepository(
      database: db,
      clock: clock,
      newId: () => 'w-${idCounter++}',
    );
    coach = CoachRepository(
      database: db,
      clock: clock,
      newId: () => 'c-${idCounter++}',
    );
  });
  tearDown(() => db.close());

  /// Does the first set of the first exercise of Push day and returns the
  /// session and set ids. The workout is finished when [finish] is true.
  Future<({String session, String set})> doOneSet({
    double? weight,
    int? reps,
    bool finish = true,
  }) async {
    final session = await workouts.startWorkout(
      routineId: TemplateSeeder.routineIdForSlug('push-day'),
    );
    final set = (await workouts.getWorkout(session))!
        .exercises
        .first
        .sets
        .first;
    if (weight != null) await workouts.updateSetWeight(set.id, weight);
    if (reps != null) await workouts.updateSetReps(set.id, reps);
    await workouts.setCompleted(set.id, completed: true);
    if (finish) await workouts.finishWorkout(session);
    return (session: session, set: set.id);
  }

  test('no data gives empty lists', () async {
    expect(await progress.watchCompletedSets().first, isEmpty);
    expect(await progress.watchCoachScores().first, isEmpty);
  });

  test('completed sets of finished workouts are listed with details', () async {
    await doOneSet(weight: 80, reps: 5);

    final sets = await progress.watchCompletedSets().first;

    expect(sets, hasLength(1));
    expect(sets.single.exerciseName, 'Bench press');
    expect(sets.single.weightKg, 80);
    expect(sets.single.reps, 5);
    expect(sets.single.completedAt, now);
  });

  test('sets of a workout still in progress are not counted', () async {
    await doOneSet(weight: 80, reps: 5, finish: false);

    expect(await progress.watchCompletedSets().first, isEmpty);
  });

  test('discarded workouts and unticked sets are not counted', () async {
    final done = await doOneSet(weight: 80, reps: 5);
    await workouts.discardWorkout(done.session);

    expect(await progress.watchCompletedSets().first, isEmpty);
  });

  test('coach scores are listed oldest first', () async {
    final first = await doOneSet(reps: 5);
    await coach.saveCoachedSet(
      setLogId: first.set,
      exerciseKey: 'squat',
      result: const CoachResult(
        repsCounted: 5,
        partialReps: 0,
        setScore: 80,
        reps: [],
      ),
    );
    now = DateTime.utc(2026, 9, 28, 10);
    final second = await doOneSet(reps: 5);
    await coach.saveCoachedSet(
      setLogId: second.set,
      exerciseKey: 'squat',
      result: const CoachResult(
        repsCounted: 5,
        partialReps: 0,
        setScore: 92,
        reps: [],
      ),
    );

    final scores = await progress.watchCoachScores().first;

    expect(scores.map((p) => p.score), [80, 92]);
    expect(scores.first.exerciseKey, 'squat');
    expect(scores.first.at.isBefore(scores.last.at), isTrue);
  });

  test('scores of unfinished workouts are not counted', () async {
    final unfinished = await doOneSet(reps: 5, finish: false);
    await coach.saveCoachedSet(
      setLogId: unfinished.set,
      exerciseKey: 'squat',
      result: const CoachResult(
        repsCounted: 5,
        partialReps: 0,
        setScore: 80,
        reps: [],
      ),
    );

    expect(await progress.watchCoachScores().first, isEmpty);
  });
}
