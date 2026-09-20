import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/demo/pullup_synth.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/coach_session.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/exercises/pullup.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

({CoachSession session, List<CoachUpdate> updates}) _run(
  List<PoseFrame> frames,
) {
  final session = CoachSession(definition: pullup);
  final updates = [for (final frame in frames) session.update(frame)];
  return (session: session, updates: updates);
}

Set<String> _faultsOf(CoachSession session) => {
  for (final rep in session.reps) ...rep.faultCodes,
};

Iterable<String?> _cueTexts(List<CoachUpdate> updates) =>
    updates.map((u) => u.cue?.text);

RepSummary _rep({
  double head = 0.1,
  double elbowMax = 170,
  double swing = 0,
  Duration lowering = const Duration(milliseconds: 1500),
}) {
  MetricStats stat(double min, double max) =>
      MetricStats(min: min, max: max, atBottom: min);
  return RepSummary(
    stats: {
      PullupMetric.headAboveBar: stat(-0.8, head),
      PullupMetric.elbowAngle: stat(35, elbowMax),
      PullupMetric.swing: stat(0, swing),
    },
    descent: const Duration(milliseconds: 1500),
    ascent: lowering,
    startedAt: Duration.zero,
    endedAt: const Duration(seconds: 3),
  );
}

double _severity(String code, RepSummary rep) =>
    pullup.rules.singleWhere((r) => r.code == code).check(rep);

void main() {
  group('measurePullup', () {
    PoseFrame frame({
      double elbow = 100,
      double swing = 0,
      bool facingRight = true,
    }) => PoseFrame(
      timestamp: Duration.zero,
      points: pullupPose(
        elbowAngle: elbow,
        swing: swing,
        facingRight: facingRight,
      ),
    );

    test('reads the elbow angle from the pose', () {
      for (final angle in [170.0, 120.0, 80.0, 35.0]) {
        final metrics = measurePullup(frame(elbow: angle), BodySide.left)!;

        expect(metrics[PullupMetric.elbowAngle], closeTo(angle, 1e-6));
      }
    });

    test('the head rises above the bar as the arms bend', () {
      double head(double elbow) => measurePullup(
        frame(elbow: elbow),
        BodySide.left,
      )![PullupMetric.headAboveBar]!;

      expect(head(170), lessThan(head(100)));
      expect(head(100), lessThan(head(50)));
      expect(head(50), lessThan(-0.05));
      expect(head(35), greaterThan(-0.05));
    });

    test('measures the swing of the body', () {
      final hanging = measurePullup(frame(), BodySide.left)!;
      final swinging = measurePullup(frame(swing: 30), BodySide.left)!;

      expect(hanging[PullupMetric.swing], closeTo(0, 1e-6));
      expect(swinging[PullupMetric.swing], closeTo(30, 1e-6));
    });

    test('gives the same numbers whichever way the person faces', () {
      final right = measurePullup(frame(swing: 20), BodySide.left)!;
      final left = measurePullup(
        frame(swing: 20, facingRight: false),
        BodySide.left,
      )!;

      for (final metric in right.keys) {
        expect(left[metric], closeTo(right[metric]!, 1e-9), reason: metric);
      }
    });

    test('returns null without the nose or another needed landmark', () {
      for (final missing in [Landmark.nose, Landmark.leftWrist]) {
        final points = pullupPose(elbowAngle: 100)..remove(missing);

        expect(
          measurePullup(
            PoseFrame(timestamp: Duration.zero, points: points),
            BodySide.left,
          ),
          isNull,
          reason: missing.name,
        );
      }
    });
  });

  group('pull-up rules', () {
    test('a good pull-up has no faults', () {
      for (final rule in pullup.rules) {
        expect(rule.check(_rep()), 0, reason: rule.code);
      }
    });

    test('height: the head must get to about bar level', () {
      expect(_severity('pullup_height', _rep(head: -0.05)), 0);
      expect(_severity('pullup_height', _rep(head: -0.2)), closeTo(0.5, 1e-9));
      expect(_severity('pullup_height', _rep(head: -0.6)), 1);
    });

    test('lockout: arms should be nearly straight at the bottom', () {
      expect(_severity('pullup_lockout', _rep(elbowMax: 168)), 0);
      expect(
        _severity('pullup_lockout', _rep(elbowMax: 152.5)),
        closeTo(0.5, 1e-9),
      );
    });

    test('swing: a little sway is fine, kipping is not', () {
      expect(_severity('pullup_swing', _rep(swing: 20)), 0);
      expect(_severity('pullup_swing', _rep(swing: 30)), closeTo(0.5, 1e-9));
      expect(_severity('pullup_swing', _rep(swing: 60)), 1);
    });

    test('tempo: lowering in under 0.8 s is a drop', () {
      const ms = Duration(milliseconds: 1);
      expect(_severity('pullup_tempo', _rep(lowering: ms * 800)), 0);
      expect(
        _severity('pullup_tempo', _rep(lowering: ms * 550)),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('coaching pull-ups', () {
    test('good pull-ups are all counted and judged excellent', () {
      final run = _run(pullupFrames(const PullupMotion(reps: 4)));

      expect(run.session.repCount, 4);
      expect(run.session.partialCount, 0);
      expect(_faultsOf(run.session), isEmpty);
      expect(run.session.setScore, greaterThanOrEqualTo(95));
    });

    test('works the same when facing left', () {
      final run = _run(pullupFrames(const PullupMotion(facingRight: false)));

      expect(run.session.repCount, 3);
      expect(_faultsOf(run.session), isEmpty);
    });

    test('keeps counting through detection jitter', () {
      final run = _run(pullupFrames(const PullupMotion(reps: 5, noise: 0.003)));

      expect(run.session.repCount, 5);
      expect(run.session.partialCount, 0);
    });

    test(
      'pulls that do not get the head to the bar are told to pull higher',
      () {
        // The elbow bends to 70, so the rep counts, but the head stays low.
        final run = _run(pullupFrames(const PullupMotion(topElbow: 70)));

        expect(run.session.repCount, 3);
        expect(_faultsOf(run.session), contains('pullup_height'));
        expect(_cueTexts(run.updates), contains('Pull higher'));
      },
    );

    test('very short pulls are partial reps', () {
      final run = _run(pullupFrames(const PullupMotion(topElbow: 110)));

      expect(run.session.repCount, 0);
      expect(run.session.partialCount, 3);
      expect(_cueTexts(run.updates), contains('Pull higher'));
    });

    test('not hanging with straight arms is flagged', () {
      final run = _run(pullupFrames(const PullupMotion(hangElbow: 155)));

      expect(run.session.repCount, 3);
      expect(_faultsOf(run.session), contains('pullup_lockout'));
      expect(_cueTexts(run.updates), contains('Lower all the way down'));
    });

    test('kipping is flagged', () {
      final run = _run(pullupFrames(const PullupMotion(swingAtTop: 35)));

      expect(_faultsOf(run.session), contains('pullup_swing'));
      expect(_cueTexts(run.updates), contains('Keep your body still'));
    });

    test('dropping down instead of lowering is flagged', () {
      final run = _run(
        pullupFrames(const PullupMotion(lower: Duration(milliseconds: 500))),
      );

      expect(_faultsOf(run.session), contains('pullup_tempo'));
      expect(_cueTexts(run.updates), contains('Lower with control'));
    });
  });
}
