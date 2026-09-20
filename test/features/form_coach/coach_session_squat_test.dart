import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/coach_session.dart';
import 'package:formcoach/features/form_coach/engine/rep_scorer.dart';
import 'package:formcoach/features/form_coach/exercises/squat.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Feeds [frames] to a fresh squat session and returns everything it said.
({CoachSession session, List<CoachUpdate> updates}) _run(
  List<PoseFrame> frames,
) {
  final session = CoachSession(definition: squat);
  final updates = [for (final frame in frames) session.update(frame)];
  return (session: session, updates: updates);
}

List<String> _cues(List<CoachUpdate> updates) => [
  for (final u in updates)
    if (u.cue != null) u.cue!.code,
];

Set<String> _faultsOf(CoachSession session) => {
  for (final rep in session.reps) ...rep.faultCodes,
};

void main() {
  group('good squats', () {
    test('every repetition is counted and judged excellent', () {
      final run = _run(squatFrames(const SquatMotion(reps: 4)));

      expect(run.session.repCount, 4);
      expect(run.session.partialCount, 0);
      expect(run.session.reps.every((r) => r.faults.isEmpty), isTrue);
      expect(
        run.session.reps.every((r) => r.quality == RepQuality.excellent),
        isTrue,
      );
      expect(run.session.setScore, greaterThanOrEqualTo(95));
    });

    test('the coach stays quiet except for praise', () {
      final run = _run(squatFrames(const SquatMotion(reps: 4)));

      expect(_cues(run.updates).toSet(), {'praise'});
    });

    test('reports each completed repetition once, in order', () {
      final run = _run(squatFrames(const SquatMotion(reps: 3)));

      final indexes = [
        for (final u in run.updates)
          if (u.completedRep != null) u.completedRep!.index,
      ];
      expect(indexes, [1, 2, 3]);
    });

    test('works the same when facing left', () {
      final run = _run(
        squatFrames(const SquatMotion(reps: 3, facingRight: false)),
      );

      expect(run.session.repCount, 3);
      expect(run.session.reps.every((r) => r.faults.isEmpty), isTrue);
    });

    test('keeps counting through detection jitter', () {
      final run = _run(squatFrames(const SquatMotion(reps: 5, noise: 0.004)));

      expect(run.session.repCount, 5);
      expect(run.session.partialCount, 0);
      expect(run.session.setScore, greaterThanOrEqualTo(75));
    });

    test('picks a body side and keeps it', () {
      final run = _run(squatFrames(const SquatMotion(reps: 1)));

      expect(run.session.side, BodySide.left);
    });
  });

  group('faulty squats', () {
    test('half squats are counted but told to go deeper', () {
      final run = _run(squatFrames(const SquatMotion(bottomKnee: 95)));

      expect(run.session.repCount, 3);
      expect(_faultsOf(run.session), contains('squat_depth'));
      expect(run.updates.map((u) => u.cue?.text), contains('Go deeper'));
    });

    test('quarter squats are partial reps and are not counted', () {
      final run = _run(squatFrames(const SquatMotion(bottomKnee: 115)));

      expect(run.session.repCount, 0);
      expect(run.session.partialCount, 3);
      expect(run.session.setScore, isNull);
      expect(run.updates.where((u) => u.partialRep), hasLength(3));
    });

    test('partial reps are not nagged about every time', () {
      final run = _run(squatFrames(const SquatMotion(bottomKnee: 115)));

      // Three partial reps a few seconds apart: the cue has a 6 s cooldown.
      expect(_cues(run.updates), ['partial_rep', 'partial_rep']);
    });

    test('leaning too far forward is picked up and mentioned', () {
      final run = _run(squatFrames(const SquatMotion(torsoLeanAtBottom: 60)));

      expect(_faultsOf(run.session), {'squat_torso_lean'});
      expect(run.updates.map((u) => u.cue?.text), contains('Chest up'));
    });

    test('knees far past the toes are picked up', () {
      final run = _run(squatFrames(const SquatMotion(shinLeanAtBottom: 75)));

      expect(_faultsOf(run.session), contains('squat_knee_forward'));
    });

    test('dropping down too fast is picked up', () {
      final run = _run(
        squatFrames(const SquatMotion(down: Duration(milliseconds: 500))),
      );

      expect(_faultsOf(run.session), contains('squat_tempo'));
      expect(
        run.updates.map((u) => u.cue?.text),
        contains('Slow down on the way down'),
      );
    });

    test('a fault costs points', () {
      final good = _run(squatFrames(const SquatMotion(reps: 2)));
      final leaning = _run(
        squatFrames(const SquatMotion(reps: 2, torsoLeanAtBottom: 60)),
      );

      expect(leaning.session.setScore!, lessThan(good.session.setScore!));
    });

    test('a single bad repetition is not nagged about', () {
      final run = _run(
        squatFrames(const SquatMotion(reps: 1, torsoLeanAtBottom: 60)),
      );

      expect(run.session.repCount, 1);
      expect(_cues(run.updates), isNot(contains('squat_torso_lean')));
      expect(run.updates.map((u) => u.cue?.text), isNot(contains('Chest up')));
    });
  });

  group('tracking', () {
    test('says so when the person leaves the view, then resumes counting', () {
      final first = squatFrames(const SquatMotion(reps: 1));
      final gapStart = first.last.timestamp + const Duration(milliseconds: 33);
      final gap = [
        for (var i = 0; i < 90; i++)
          PoseFrame(
            timestamp: gapStart + Duration(milliseconds: 33 * i),
            points: const {},
          ),
      ];
      final second = squatFrames(
        const SquatMotion(reps: 1),
        start: gap.last.timestamp + const Duration(milliseconds: 33),
      );

      final run = _run([...first, ...gap, ...second]);

      expect(run.updates.any((u) => !u.tracking), isTrue);
      expect(_cues(run.updates), contains('pose_lost'));
      expect(run.updates.last.tracking, isTrue);
      expect(run.session.repCount, 2);
    });

    test('a brief dropout is not reported', () {
      final frames = squatFrames(const SquatMotion(reps: 1));
      final withGap = [
        ...frames.take(20),
        for (final frame in frames.skip(20).take(5))
          PoseFrame(timestamp: frame.timestamp, points: const {}),
        ...frames.skip(25),
      ];

      final run = _run(withGap);

      expect(run.updates.every((u) => u.tracking), isTrue);
      expect(_cues(run.updates), isNot(contains('pose_lost')));
    });
  });

  test('reset starts a new set', () {
    final run = _run(squatFrames(const SquatMotion(reps: 2)));

    run.session.reset();

    expect(run.session.repCount, 0);
    expect(run.session.reps, isEmpty);
    expect(run.session.setScore, isNull);
    expect(run.session.side, isNull);
  });
}
