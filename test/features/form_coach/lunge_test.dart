import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/demo/lunge_synth.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/coach_session.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/exercises/lunge.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

({CoachSession session, List<CoachUpdate> updates}) _run(
  List<PoseFrame> frames,
) {
  final session = CoachSession(definition: lunge);
  final updates = [for (final frame in frames) session.update(frame)];
  return (session: session, updates: updates);
}

Set<String> _faultsOf(CoachSession session) => {
  for (final rep in session.reps) ...rep.faultCodes,
};

Iterable<String?> _cueTexts(List<CoachUpdate> updates) =>
    updates.map((u) => u.cue?.text);

RepSummary _rep({
  double backKnee = 0.3,
  double torsoLean = 10,
  double kneeOverToe = 0.05,
}) {
  MetricStats fixed(double value) =>
      MetricStats(min: value, max: value, atBottom: value);
  return RepSummary(
    stats: {
      LungeMetric.backKneeHeight: fixed(backKnee),
      LungeMetric.torsoLean: fixed(torsoLean),
      LungeMetric.kneeOverToe: fixed(kneeOverToe),
      LungeMetric.frontKneeAngle: fixed(90),
    },
    descent: const Duration(milliseconds: 1500),
    ascent: const Duration(milliseconds: 1500),
    startedAt: Duration.zero,
    endedAt: const Duration(seconds: 3),
  );
}

double _severity(String code, RepSummary rep) =>
    lunge.rules.singleWhere((r) => r.code == code).check(rep);

void main() {
  group('measureLunge', () {
    PoseFrame frame({
      double knee = 90,
      double step = 0.25,
      bool frontIsLeft = true,
      bool facingRight = true,
    }) => PoseFrame(
      timestamp: Duration.zero,
      points: lungePose(
        frontKneeAngle: knee,
        stepLength: step,
        frontIsLeft: frontIsLeft,
        facingRight: facingRight,
      ),
    );

    test('reads the front knee angle from the pose', () {
      for (final angle in [170.0, 130.0, 90.0]) {
        final metrics = measureLunge(frame(knee: angle), BodySide.left)!;

        expect(metrics[LungeMetric.frontKneeAngle], closeTo(angle, 1e-6));
      }
    });

    test('the back knee gets closer to the floor as the person lowers', () {
      double height(double knee) => measureLunge(
        frame(knee: knee),
        BodySide.left,
      )![LungeMetric.backKneeHeight]!;

      expect(height(170), greaterThan(height(130)));
      expect(height(130), greaterThan(height(90)));
      expect(height(90), lessThan(LungeLimits.maxBackKneeHeight));
    });

    test(
      'finds the front leg whichever leg it is and whichever way they face',
      () {
        final base = measureLunge(frame(), BodySide.left)!;
        final swapped = measureLunge(frame(frontIsLeft: false), BodySide.left)!;
        final mirrored = measureLunge(
          frame(frontIsLeft: false, facingRight: false),
          BodySide.left,
        )!;

        for (final metric in base.keys) {
          expect(swapped[metric], closeTo(base[metric]!, 1e-9), reason: metric);
          expect(
            mirrored[metric],
            closeTo(base[metric]!, 1e-9),
            reason: metric,
          );
        }
      },
    );

    test('a short step pushes the front knee towards the toes', () {
      double overToe(double step) => measureLunge(
        frame(step: step),
        BodySide.left,
      )![LungeMetric.kneeOverToe]!;

      expect(overToe(0.12), greaterThan(overToe(0.25)));
      expect(overToe(0.25), greaterThan(overToe(0.4)));
    });

    test('returns null when a needed landmark is missing', () {
      final points = lungePose(frontKneeAngle: 90)..remove(Landmark.rightKnee);

      expect(
        measureLunge(
          PoseFrame(timestamp: Duration.zero, points: points),
          BodySide.left,
        ),
        isNull,
      );
    });
  });

  group('lunge rules', () {
    test('a good lunge has no faults', () {
      for (final rule in lunge.rules) {
        expect(rule.check(_rep()), 0, reason: rule.code);
      }
    });

    test('depth: the back knee should be near the floor', () {
      expect(_severity('lunge_depth', _rep(backKnee: 0.45)), 0);
      expect(_severity('lunge_depth', _rep(backKnee: 0.6)), closeTo(0.5, 1e-9));
      expect(_severity('lunge_depth', _rep(backKnee: 1.0)), 1);
    });

    test('torso: upright within 25 degrees', () {
      expect(_severity('lunge_torso', _rep(torsoLean: 25)), 0);
      expect(_severity('lunge_torso', _rep(torsoLean: 35)), closeTo(0.5, 1e-9));
    });

    test('front knee: past the toes only counts beyond the limit', () {
      expect(_severity('lunge_knee_forward', _rep(kneeOverToe: 0.35)), 0);
      expect(
        _severity('lunge_knee_forward', _rep(kneeOverToe: 0.525)),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('coaching lunges', () {
    test('good lunges are all counted and judged excellent', () {
      final run = _run(lungeFrames(const LungeMotion(reps: 4)));

      expect(run.session.repCount, 4);
      expect(run.session.partialCount, 0);
      expect(_faultsOf(run.session), isEmpty);
      expect(run.session.setScore, greaterThanOrEqualTo(95));
    });

    test('works with the other leg forward and facing left', () {
      final run = _run(
        lungeFrames(const LungeMotion(frontIsLeft: false, facingRight: false)),
      );

      expect(run.session.repCount, 3);
      expect(_faultsOf(run.session), isEmpty);
    });

    test('keeps counting through detection jitter', () {
      final run = _run(lungeFrames(const LungeMotion(reps: 5, noise: 0.003)));

      expect(run.session.repCount, 5);
      expect(run.session.partialCount, 0);
    });

    test('leaning forward is picked up and mentioned', () {
      final run = _run(lungeFrames(const LungeMotion(torsoLeanAtBottom: 50)));

      expect(_faultsOf(run.session), contains('lunge_torso'));
      expect(_cueTexts(run.updates), contains('Stay upright'));
    });

    test('the front knee far past the toes is picked up', () {
      // A short step with short feet pushes the knee well past the toes.
      final run = _run(
        lungeFrames(const LungeMotion(stepLength: 0.12, toeLength: 0)),
      );

      expect(_faultsOf(run.session), contains('lunge_knee_forward'));
      expect(_cueTexts(run.updates), contains('Take a longer step'));
    });

    test('a very short step leaves the back knee high', () {
      final run = _run(lungeFrames(const LungeMotion(stepLength: 0.02)));

      expect(_faultsOf(run.session), contains('lunge_depth'));
      expect(_cueTexts(run.updates), contains('Lower your back knee'));
    });

    test('shallow lunges are partial reps', () {
      final run = _run(lungeFrames(const LungeMotion(bottomKnee: 125)));

      expect(run.session.repCount, 0);
      expect(run.session.partialCount, 3);
      expect(_cueTexts(run.updates), contains('Go lower'));
    });
  });
}
