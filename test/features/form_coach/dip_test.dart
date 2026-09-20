import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/demo/dip_synth.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/coach_session.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/exercises/dip.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

({CoachSession session, List<CoachUpdate> updates}) _run(
  List<PoseFrame> frames,
) {
  final session = CoachSession(definition: dip);
  final updates = [for (final frame in frames) session.update(frame)];
  return (session: session, updates: updates);
}

Set<String> _faultsOf(CoachSession session) => {
  for (final rep in session.reps) ...rep.faultCodes,
};

Iterable<String?> _cueTexts(List<CoachUpdate> updates) =>
    updates.map((u) => u.cue?.text);

RepSummary _rep({
  double depth = 0,
  double elbowMax = 170,
  Duration descent = const Duration(milliseconds: 1500),
}) {
  return RepSummary(
    stats: {
      DipMetric.shoulderBelowElbow: MetricStats(
        min: -0.4,
        max: depth,
        atBottom: depth,
      ),
      DipMetric.elbowAngle: MetricStats(min: 80, max: elbowMax, atBottom: 80),
    },
    descent: descent,
    ascent: const Duration(milliseconds: 1500),
    startedAt: Duration.zero,
    endedAt: const Duration(seconds: 3),
  );
}

double _severity(String code, RepSummary rep) =>
    dip.rules.singleWhere((r) => r.code == code).check(rep);

void main() {
  group('measureDip', () {
    PoseFrame frame({double elbow = 90, bool facingRight = true}) => PoseFrame(
      timestamp: Duration.zero,
      points: dipPose(elbowAngle: elbow, facingRight: facingRight),
    );

    test('reads the elbow angle from the pose', () {
      for (final angle in [170.0, 120.0, 90.0, 70.0]) {
        final metrics = measureDip(frame(elbow: angle), BodySide.left)!;

        expect(metrics[DipMetric.elbowAngle], closeTo(angle, 1e-6));
      }
    });

    test('the shoulder sinks towards elbow height as the arms bend', () {
      double depth(double elbow) => measureDip(
        frame(elbow: elbow),
        BodySide.left,
      )![DipMetric.shoulderBelowElbow]!;

      expect(depth(170), lessThan(depth(120)));
      expect(depth(120), lessThan(depth(90)));
      expect(depth(90), lessThan(depth(70)));
      expect(depth(80), closeTo(0, 0.08));
    });

    test('gives the same numbers whichever way the person faces', () {
      final right = measureDip(frame(elbow: 85), BodySide.left)!;
      final left = measureDip(
        frame(elbow: 85, facingRight: false),
        BodySide.left,
      )!;

      for (final metric in right.keys) {
        expect(left[metric], closeTo(right[metric]!, 1e-9), reason: metric);
      }
    });

    test('returns null when a needed landmark is missing', () {
      final points = dipPose(elbowAngle: 90)..remove(Landmark.leftElbow);

      expect(
        measureDip(
          PoseFrame(timestamp: Duration.zero, points: points),
          BodySide.left,
        ),
        isNull,
      );
    });
  });

  group('dip rules', () {
    test('a good dip has no faults', () {
      for (final rule in dip.rules) {
        expect(rule.check(_rep()), 0, reason: rule.code);
      }
      expect(_severity('dip_depth', _rep()), 0);
    });

    test('depth: the shoulder must get to about elbow height', () {
      expect(_severity('dip_depth', _rep(depth: 0.05)), 0);
      expect(_severity('dip_depth', _rep(depth: -0.05)), 0);
      expect(_severity('dip_depth', _rep(depth: -0.2)), closeTo(0.5, 1e-9));
      expect(_severity('dip_depth', _rep(depth: -0.5)), 1);
    });

    test('too deep is a safety fault beyond the limit', () {
      expect(_severity('dip_too_deep', _rep(depth: 0.22)), 0);
      expect(_severity('dip_too_deep', _rep(depth: 0.295)), closeTo(0.5, 1e-9));
      expect(
        dip.rules.singleWhere((r) => r.code == 'dip_too_deep').safety,
        isTrue,
      );
    });

    test('lockout: arms should be nearly straight at the top', () {
      expect(_severity('dip_lockout', _rep(elbowMax: 168)), 0);
      expect(
        _severity('dip_lockout', _rep(elbowMax: 152.5)),
        closeTo(0.5, 1e-9),
      );
    });

    test('tempo: going down in under 0.8 s is too fast', () {
      const ms = Duration(milliseconds: 1);
      expect(_severity('dip_tempo', _rep(descent: ms * 800)), 0);
      expect(
        _severity('dip_tempo', _rep(descent: ms * 550)),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('coaching dips', () {
    test('good dips are all counted and judged excellent', () {
      final run = _run(dipFrames(const DipMotion(reps: 4)));

      expect(run.session.repCount, 4);
      expect(run.session.partialCount, 0);
      expect(_faultsOf(run.session), isEmpty);
      expect(run.session.setScore, greaterThanOrEqualTo(95));
    });

    test('works the same when facing left', () {
      final run = _run(dipFrames(const DipMotion(facingRight: false)));

      expect(run.session.repCount, 3);
      expect(_faultsOf(run.session), isEmpty);
    });

    test('keeps counting through detection jitter', () {
      final run = _run(dipFrames(const DipMotion(reps: 5, noise: 0.003)));

      expect(run.session.repCount, 5);
      expect(run.session.partialCount, 0);
    });

    test('dips that stop short of elbow height are told to go lower', () {
      // Elbow reaches 95 degrees: counted, but the upper arm is not level.
      final run = _run(dipFrames(const DipMotion(bottomElbow: 95)));

      expect(run.session.repCount, 3);
      expect(_faultsOf(run.session), contains('dip_depth'));
      expect(_cueTexts(run.updates), contains('Go lower'));
    });

    test('very shallow dips are partial reps', () {
      final run = _run(dipFrames(const DipMotion(bottomElbow: 125)));

      expect(run.session.repCount, 0);
      expect(run.session.partialCount, 3);
      expect(_cueTexts(run.updates), contains('Go lower'));
    });

    test('going far too deep is a safety fault, mentioned at once', () {
      final run = _run(dipFrames(const DipMotion(bottomElbow: 45)));

      expect(_faultsOf(run.session), contains('dip_too_deep'));
      final firstCue = run.updates.firstWhere((u) => u.cue != null);
      expect(firstCue.cue?.text, 'Not so deep');
      expect(firstCue.completedRep?.index, 1);
    });

    test('not locking out at the top is flagged', () {
      final run = _run(dipFrames(const DipMotion(topElbow: 155)));

      expect(_faultsOf(run.session), contains('dip_lockout'));
    });

    test('dropping down too fast is flagged', () {
      final run = _run(
        dipFrames(const DipMotion(down: Duration(milliseconds: 500))),
      );

      expect(_faultsOf(run.session), contains('dip_tempo'));
      expect(_cueTexts(run.updates), contains('Control the way down'));
    });
  });
}
