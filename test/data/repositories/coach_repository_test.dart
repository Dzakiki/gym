import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/coach_repository.dart';
import 'package:formcoach/data/repositories/coach_result.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:formcoach/data/seed/seed_service.dart';
import 'package:formcoach/data/seed/template_seeder.dart';

import '../../helpers/file_asset_bundle.dart';

const _squatRepGood = RepResult(
  score: 100,
  faults: [],
  descentMs: 1500,
  ascentMs: 1400,
);
const _squatRepLean = RepResult(
  score: 80,
  faults: ['squat_torso_lean'],
  descentMs: 1600,
  ascentMs: 1500,
);

void main() {
  late AppDatabase db;
  late CoachRepository coach;
  late WorkoutRepository workouts;
  late String sessionId;
  late String setId;
  var idCounter = 0;
  final now = DateTime.utc(2026, 9, 20, 10);

  setUp(() async {
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
    coach = CoachRepository(
      database: db,
      clock: clock,
      newId: () => 'a-${idCounter++}',
    );
    workouts = WorkoutRepository(
      database: db,
      clock: clock,
      newId: () => 'w-${idCounter++}',
    );
    sessionId = await workouts.startWorkout(
      routineId: TemplateSeeder.routineIdForSlug('home-bodyweight'),
    );
    setId = (await workouts.getWorkout(sessionId))!
        .exercises
        .first
        .sets
        .first
        .id;
  });
  tearDown(() => db.close());

  Future<SetLog> setRow() =>
      (db.select(db.setLogs)..where((s) => s.id.equals(setId))).getSingle();

  test('a coached rep set fills the set and stores the analysis', () async {
    await coach.saveCoachedSet(
      setLogId: setId,
      exerciseKey: 'squat',
      result: const CoachResult(
        repsCounted: 2,
        partialReps: 1,
        setScore: 90,
        reps: [_squatRepGood, _squatRepLean],
      ),
    );

    final set = await setRow();
    expect(set.reps, 2);
    expect(set.coached, isTrue);
    expect(set.completedAt, now);
    final analysis = await db.select(db.coachAnalyses).getSingle();
    expect(analysis.setLogId, setId);
    expect(analysis.exerciseKey, 'squat');
    expect(analysis.engineVersion, coachEngineVersion);
    expect(analysis.setScore, 90);
    expect(analysis.repsCounted, 2);
    expect(analysis.partialReps, 1);
    expect(analysis.holdSeconds, isNull);
    expect(jsonDecode(analysis.faults), {'squat_torso_lean': 1});
    final perRep = jsonDecode(analysis.perRep) as List<dynamic>;
    expect(perRep, hasLength(2));
    expect((perRep.last as Map<String, dynamic>)['score'], 80);
  });

  test('a coached hold stores seconds instead of reps', () async {
    await coach.saveCoachedSet(
      setLogId: setId,
      exerciseKey: 'plank',
      result: const CoachResult(
        repsCounted: 0,
        partialReps: 0,
        holdSeconds: 42.4,
        setScore: 88,
        reps: [],
      ),
    );

    final set = await setRow();
    expect(set.reps, isNull);
    expect(set.durationSeconds, 42);
    expect(set.coached, isTrue);
    expect((await db.select(db.coachAnalyses).getSingle()).holdSeconds, 42.4);
  });

  test('coaching the same set again replaces the analysis', () async {
    const first = CoachResult(
      repsCounted: 1,
      partialReps: 0,
      setScore: 70,
      reps: [_squatRepLean],
    );
    const second = CoachResult(
      repsCounted: 3,
      partialReps: 0,
      setScore: 100,
      reps: [_squatRepGood, _squatRepGood, _squatRepGood],
    );

    await coach.saveCoachedSet(
      setLogId: setId,
      exerciseKey: 'squat',
      result: first,
    );
    await coach.saveCoachedSet(
      setLogId: setId,
      exerciseKey: 'squat',
      result: second,
    );

    final all = await db.select(db.coachAnalyses).get();
    expect(all, hasLength(2));
    expect(all.where((a) => a.deletedAt == null).single.setScore, 100);
    expect((await setRow()).reps, 3);
  });

  test('an unknown set is an error and writes nothing', () async {
    await expectLater(
      coach.saveCoachedSet(
        setLogId: 'missing',
        exerciseKey: 'squat',
        result: const CoachResult(repsCounted: 1, partialReps: 0, reps: []),
      ),
      throwsStateError,
    );

    expect(await db.select(db.coachAnalyses).get(), isEmpty);
  });

  test('analyses of a workout are found by set id', () async {
    await coach.saveCoachedSet(
      setLogId: setId,
      exerciseKey: 'squat',
      result: const CoachResult(
        repsCounted: 1,
        partialReps: 0,
        setScore: 95,
        reps: [_squatRepGood],
      ),
    );

    final bySet = await coach.watchForSession(sessionId).first;

    expect(bySet.keys, [setId]);
    expect(bySet[setId]!.setScore, 95);
    expect(await coach.watchForSession('other').first, isEmpty);
  });

  test('fault counts add up over repetitions', () {
    const result = CoachResult(
      repsCounted: 3,
      partialReps: 0,
      reps: [_squatRepLean, _squatRepGood, _squatRepLean],
    );

    expect(result.faultCounts, {'squat_torso_lean': 2});
    expect(result.isHold, isFalse);
  });

  test('deleting a set removes its analysis', () async {
    await coach.saveCoachedSet(
      setLogId: setId,
      exerciseKey: 'squat',
      result: const CoachResult(repsCounted: 1, partialReps: 0, reps: []),
    );

    await (db.delete(db.setLogs)..where((s) => s.id.equals(setId))).go();

    expect(await db.select(db.coachAnalyses).get(), isEmpty);
  });
}
