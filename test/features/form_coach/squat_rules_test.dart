import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/exercises/squat.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// A repetition summary with the given measurements at the bottom.
RepSummary _rep({
  double hipDrop = 0,
  double torsoLean = 20,
  double kneeOverToe = 0.05,
  Duration descent = const Duration(milliseconds: 1500),
}) {
  MetricStats fixed(double value) =>
      MetricStats(min: value, max: value, atBottom: value);
  return RepSummary(
    stats: {
      SquatMetric.hipDrop: fixed(hipDrop),
      SquatMetric.torsoLean: fixed(torsoLean),
      SquatMetric.kneeOverToe: fixed(kneeOverToe),
      SquatMetric.kneeAngle: fixed(70),
    },
    descent: descent,
    ascent: const Duration(milliseconds: 1500),
    startedAt: Duration.zero,
    endedAt: const Duration(seconds: 3),
  );
}

double _severity(String code, RepSummary rep) =>
    squat.rules.singleWhere((r) => r.code == code).check(rep);

void main() {
  group('measureSquat', () {
    PoseFrame frame({
      double knee = 70,
      double torso = 25,
      double shin = 25,
      bool facingRight = true,
    }) => PoseFrame(
      timestamp: Duration.zero,
      points: squatPose(
        kneeAngle: knee,
        torsoLean: torso,
        shinLean: shin,
        facingRight: facingRight,
      ),
    );

    test('reads the joint angles from the pose', () {
      final metrics = measureSquat(frame(knee: 90, torso: 30), BodySide.left)!;

      expect(metrics[SquatMetric.kneeAngle], closeTo(90, 1e-6));
      expect(metrics[SquatMetric.torsoLean], closeTo(30, 1e-6));
    });

    test(
      'the hip is level with the knee at parallel and above before that',
      () {
        final parallel = measureSquat(frame(knee: 65), BodySide.left)!;
        final high = measureSquat(frame(knee: 100), BodySide.left)!;

        expect(parallel[SquatMetric.hipDrop]!, closeTo(0, 0.05));
        expect(high[SquatMetric.hipDrop]!, lessThan(-0.3));
      },
    );

    test('gives the same numbers whichever way the person faces', () {
      final right = measureSquat(frame(), BodySide.left)!;
      final left = measureSquat(frame(facingRight: false), BodySide.left)!;

      for (final metric in right.keys) {
        expect(left[metric], closeTo(right[metric]!, 1e-9), reason: metric);
      }
    });

    test('measures the knee past the toes when the shin leans far forward', () {
      final upright = measureSquat(frame(shin: 10), BodySide.left)!;
      final forward = measureSquat(frame(shin: 75), BodySide.left)!;

      expect(upright[SquatMetric.kneeOverToe]!, lessThan(0.35));
      expect(forward[SquatMetric.kneeOverToe]!, greaterThan(0.35));
    });

    test('returns null when a needed landmark is missing', () {
      final points = squatPose(kneeAngle: 90, torsoLean: 20, shinLean: 20)
        ..remove(Landmark.leftKnee);

      final metrics = measureSquat(
        PoseFrame(timestamp: Duration.zero, points: points),
        BodySide.left,
      );

      expect(metrics, isNull);
    });
  });

  group('squat rules', () {
    test('a good squat has no faults', () {
      for (final rule in squat.rules) {
        expect(rule.check(_rep()), 0, reason: rule.code);
      }
    });

    test('depth: hips level with the knees is fine, well above is not', () {
      expect(_severity('squat_depth', _rep(hipDrop: 0.1)), 0);
      expect(_severity('squat_depth', _rep(hipDrop: -0.1)), 0);
      expect(
        _severity('squat_depth', _rep(hipDrop: -0.35)),
        closeTo(0.5, 1e-9),
      );
      expect(_severity('squat_depth', _rep(hipDrop: -0.8)), 1);
    });

    test('torso lean: up to 45 degrees is fine, then it gets worse', () {
      expect(_severity('squat_torso_lean', _rep(torsoLean: 45)), 0);
      expect(
        _severity('squat_torso_lean', _rep(torsoLean: 60)),
        closeTo(0.5, 1e-9),
      );
      expect(_severity('squat_torso_lean', _rep(torsoLean: 90)), 1);
    });

    test('knees past the toes only count beyond the limit', () {
      expect(_severity('squat_knee_forward', _rep(kneeOverToe: 0.35)), 0);
      expect(
        _severity('squat_knee_forward', _rep(kneeOverToe: 0.525)),
        closeTo(0.5, 1e-9),
      );
    });

    test('tempo: going down in under 0.8 s is too fast', () {
      const ms = Duration(milliseconds: 1);
      expect(_severity('squat_tempo', _rep(descent: ms * 800)), 0);
      expect(
        _severity('squat_tempo', _rep(descent: ms * 550)),
        closeTo(0.5, 1e-9),
      );
      expect(_severity('squat_tempo', _rep(descent: ms * 100)), 1);
    });

    test('the rules have the cues from the plan', () {
      expect(
        {for (final r in squat.rules) r.code: r.cue},
        {
          'squat_depth': 'Go deeper',
          'squat_torso_lean': 'Chest up',
          'squat_knee_forward': 'Sit back into your hips',
          'squat_tempo': 'Slow down on the way down',
        },
      );
    });
  });
}
