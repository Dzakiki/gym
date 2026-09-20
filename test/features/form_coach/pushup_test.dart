import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/demo/pushup_synth.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/coach_session.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/exercises/pushup.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Feeds [frames] to a fresh push-up session and returns everything it said.
({CoachSession session, List<CoachUpdate> updates}) _run(
  List<PoseFrame> frames,
) {
  final session = CoachSession(definition: pushup);
  final updates = [for (final frame in frames) session.update(frame)];
  return (session: session, updates: updates);
}

Set<String> _faultsOf(CoachSession session) => {
  for (final rep in session.reps) ...rep.faultCodes,
};

Iterable<String?> _cueTexts(List<CoachUpdate> updates) =>
    updates.map((u) => u.cue?.text);

RepSummary _rep({double hipHeight = 0, double elbowMax = 170}) {
  MetricStats fixed(double min, double max) =>
      MetricStats(min: min, max: max, atBottom: min);
  return RepSummary(
    stats: {
      PushupMetric.hipHeight: fixed(hipHeight, hipHeight),
      PushupMetric.elbowAngle: fixed(75, elbowMax),
    },
    descent: const Duration(milliseconds: 1500),
    ascent: const Duration(milliseconds: 1500),
    startedAt: Duration.zero,
    endedAt: const Duration(seconds: 3),
  );
}

double _severity(String code, RepSummary rep) =>
    pushup.rules.singleWhere((r) => r.code == code).check(rep);

void main() {
  group('measurePushup', () {
    PoseFrame frame({
      double elbow = 90,
      double hipOffset = 0,
      bool facingRight = true,
    }) => PoseFrame(
      timestamp: Duration.zero,
      points: pushupPose(
        elbowAngle: elbow,
        hipOffset: hipOffset,
        facingRight: facingRight,
      ),
    );

    test('reads the elbow angle from the pose', () {
      for (final angle in [170.0, 120.0, 90.0, 70.0]) {
        final metrics = measurePushup(frame(elbow: angle), BodySide.left)!;

        expect(metrics[PushupMetric.elbowAngle], closeTo(angle, 1e-6));
      }
    });

    test('a straight body has the hips on the line', () {
      final metrics = measurePushup(frame(), BodySide.left)!;

      expect(metrics[PushupMetric.hipHeight], closeTo(0, 1e-6));
    });

    test('sagging hips are negative and piked hips positive', () {
      final sag = measurePushup(frame(hipOffset: -0.1), BodySide.left)!;
      final pike = measurePushup(frame(hipOffset: 0.15), BodySide.left)!;

      expect(sag[PushupMetric.hipHeight], closeTo(-0.1, 1e-6));
      expect(pike[PushupMetric.hipHeight], closeTo(0.15, 1e-6));
    });

    test('gives the same numbers whichever way the person faces', () {
      final right = measurePushup(frame(hipOffset: -0.1), BodySide.left)!;
      final left = measurePushup(
        frame(hipOffset: -0.1, facingRight: false),
        BodySide.left,
      )!;

      for (final metric in right.keys) {
        expect(left[metric], closeTo(right[metric]!, 1e-9), reason: metric);
      }
    });

    test('returns null when a needed landmark is missing', () {
      final points = pushupPose(elbowAngle: 90)..remove(Landmark.leftWrist);

      expect(
        measurePushup(
          PoseFrame(timestamp: Duration.zero, points: points),
          BodySide.left,
        ),
        isNull,
      );
    });
  });

  group('push-up rules', () {
    test('a good push-up has no faults', () {
      for (final rule in pushup.rules) {
        expect(rule.check(_rep()), 0, reason: rule.code);
      }
    });

    test('sag: small dips are tolerated, big ones are not', () {
      expect(_severity('pushup_hip_sag', _rep(hipHeight: -0.04)), 0);
      expect(
        _severity('pushup_hip_sag', _rep(hipHeight: -0.10)),
        closeTo(0.5, 1e-9),
      );
      expect(_severity('pushup_hip_sag', _rep(hipHeight: -0.3)), 1);
      expect(_severity('pushup_hip_sag', _rep(hipHeight: 0.1)), 0);
    });

    test('pike: hips above the line by more than 0.08 are a fault', () {
      expect(_severity('pushup_hip_pike', _rep(hipHeight: 0.08)), 0);
      expect(
        _severity('pushup_hip_pike', _rep(hipHeight: 0.14)),
        closeTo(0.5, 1e-9),
      );
      expect(_severity('pushup_hip_pike', _rep(hipHeight: -0.2)), 0);
    });

    test('lockout: arms should be nearly straight at the top', () {
      expect(_severity('pushup_lockout', _rep(elbowMax: 170)), 0);
      expect(_severity('pushup_lockout', _rep(elbowMax: 165)), 0);
      expect(
        _severity('pushup_lockout', _rep(elbowMax: 152.5)),
        closeTo(0.5, 1e-9),
      );
    });

    test('only the sag rule is a safety rule', () {
      expect(
        {for (final r in pushup.rules) r.code: r.safety},
        {
          'pushup_hip_sag': true,
          'pushup_hip_pike': false,
          'pushup_lockout': false,
        },
      );
    });
  });

  group('coaching push-ups', () {
    test('good push-ups are all counted and judged excellent', () {
      final run = _run(pushupFrames(const PushupMotion(reps: 4)));

      expect(run.session.repCount, 4);
      expect(run.session.partialCount, 0);
      expect(_faultsOf(run.session), isEmpty);
      expect(run.session.setScore, greaterThanOrEqualTo(95));
    });

    test('works the same when facing left', () {
      final run = _run(
        pushupFrames(const PushupMotion(reps: 3, facingRight: false)),
      );

      expect(run.session.repCount, 3);
      expect(_faultsOf(run.session), isEmpty);
    });

    test('keeps counting through detection jitter', () {
      final run = _run(pushupFrames(const PushupMotion(reps: 5, noise: 0.003)));

      expect(run.session.repCount, 5);
      expect(run.session.partialCount, 0);
    });

    test('sagging hips are flagged and mentioned right away', () {
      final run = _run(pushupFrames(const PushupMotion(hipOffset: -0.12)));

      expect(_faultsOf(run.session), contains('pushup_hip_sag'));
      expect(run.updates.first.cue, isNull);
      expect(_cueTexts(run.updates), contains('Tighten your core, hips up'));
      // A safety cue comes after the first repetition, not the second.
      final firstCue = run.updates.firstWhere((u) => u.cue != null);
      expect(firstCue.completedRep?.index, 1);
    });

    test('piked hips are flagged and mentioned once repeated', () {
      final run = _run(pushupFrames(const PushupMotion(hipOffset: 0.2)));

      expect(_faultsOf(run.session), contains('pushup_hip_pike'));
      expect(_cueTexts(run.updates), contains('Lower your hips'));
    });

    test('half push-ups are partial reps and are told to go lower', () {
      final run = _run(pushupFrames(const PushupMotion(bottomElbow: 115)));

      expect(run.session.repCount, 0);
      expect(run.session.partialCount, 3);
      expect(_cueTexts(run.updates), contains('Go lower'));
    });

    test('not locking out at the top is flagged', () {
      final run = _run(pushupFrames(const PushupMotion(topElbow: 155)));

      expect(run.session.repCount, 3);
      expect(_faultsOf(run.session), contains('pushup_lockout'));
      expect(_cueTexts(run.updates), contains('Push all the way up'));
    });

    test('faults cost points', () {
      final good = _run(pushupFrames(const PushupMotion(reps: 2)));
      final sagging = _run(
        pushupFrames(const PushupMotion(reps: 2, hipOffset: -0.12)),
      );

      expect(sagging.session.setScore!, lessThan(good.session.setScore!));
    });
  });
}
