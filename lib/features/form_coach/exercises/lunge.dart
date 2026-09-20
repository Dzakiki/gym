import 'dart:math' as math;

import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Names of the measurements taken for the lunge.
abstract final class LungeMetric {
  /// Angle at the front knee in degrees. 180 is a straight leg.
  static const frontKneeAngle = 'front_knee_angle';

  /// How high the back knee is above the floor, in torso lengths. Small
  /// means the knee is close to the floor.
  static const backKneeHeight = 'back_knee_height';

  /// How far the torso leans away from upright, in degrees.
  static const torsoLean = 'torso_lean';

  /// How far the front knee is past the toes, in torso lengths.
  static const kneeOverToe = 'knee_over_toe';
}

/// Limits used by the lunge rules. Starting values, to be tuned with real
/// recordings.
abstract final class LungeLimits {
  /// The back knee should get within this height of the floor (torso lengths).
  static const maxBackKneeHeight = 0.45;

  /// The torso may lean this far forward at the bottom.
  static const maxTorsoLean = 25.0;

  /// The front knee may go this far past the toes (torso lengths).
  static const maxKneeOverToe = 0.35;
}

/// Measures a side-view lunge frame, or returns null if a needed landmark is
/// missing. Both legs are used: the one whose foot is further forward is the
/// front leg. [side] only picks which shoulder and hip give the torso.
Metrics? measureLunge(PoseFrame frame, BodySide side) {
  final shoulder = frame.position(side.shoulder);
  final hip = frame.position(side.hip);
  final leftKnee = frame.position(BodySide.left.knee);
  final leftAnkle = frame.position(BodySide.left.ankle);
  final leftToe = frame.position(BodySide.left.toe);
  final rightKnee = frame.position(BodySide.right.knee);
  final rightAnkle = frame.position(BodySide.right.ankle);
  final rightToe = frame.position(BodySide.right.toe);
  if (shoulder == null ||
      hip == null ||
      leftKnee == null ||
      leftAnkle == null ||
      leftToe == null ||
      rightKnee == null ||
      rightAnkle == null ||
      rightToe == null) {
    return null;
  }
  final torsoLength = shoulder.distanceTo(hip);
  if (torsoLength == 0) return null;

  // The toes point the way the person faces.
  final facing = ((leftToe.x - leftAnkle.x) + (rightToe.x - rightAnkle.x)) >= 0
      ? 1.0
      : -1.0;
  final leftIsFront = leftAnkle.x * facing >= rightAnkle.x * facing;
  final frontKnee = leftIsFront ? leftKnee : rightKnee;
  final frontAnkle = leftIsFront ? leftAnkle : rightAnkle;
  final frontToe = leftIsFront ? leftToe : rightToe;
  final backKnee = leftIsFront ? rightKnee : leftKnee;
  final floorY = math.max(leftAnkle.y, rightAnkle.y);

  return {
    LungeMetric.frontKneeAngle: angleAt(hip, frontKnee, frontAnkle),
    LungeMetric.backKneeHeight: (floorY - backKnee.y) / torsoLength,
    LungeMetric.torsoLean: leanFromVertical(hip, shoulder),
    LungeMetric.kneeOverToe: (frontKnee.x - frontToe.x) * facing / torsoLength,
  };
}

double _scale(double value, {required double from, required double range}) =>
    ((value - from) / range).clamp(0.0, 1.0);

/// The lunge (or split squat): side view, counted when the front knee bends
/// to 105 degrees or less and straightens again to about 155 degrees.
final lunge = ExerciseDefinition(
  key: 'lunge',
  name: 'Lunge',
  view: CameraView.side,
  primaryMetric: LungeMetric.frontKneeAngle,
  repConfig: const RepMachineConfig(downThreshold: 105, upThreshold: 155),
  partialRepCue: 'Go lower',
  measure: measureLunge,
  rules: [
    FormRule(
      code: 'lunge_depth',
      cue: 'Lower your back knee',
      weight: 25,
      check: (rep) => _scale(
        rep.stat(LungeMetric.backKneeHeight).atBottom,
        from: LungeLimits.maxBackKneeHeight,
        range: 0.3,
      ),
    ),
    FormRule(
      code: 'lunge_torso',
      cue: 'Stay upright',
      weight: 20,
      check: (rep) => _scale(
        rep.stat(LungeMetric.torsoLean).atBottom,
        from: LungeLimits.maxTorsoLean,
        range: 20,
      ),
    ),
    FormRule(
      code: 'lunge_knee_forward',
      cue: 'Take a longer step',
      weight: 15,
      check: (rep) => _scale(
        rep.stat(LungeMetric.kneeOverToe).max,
        from: LungeLimits.maxKneeOverToe,
        range: 0.35,
      ),
    ),
  ],
);
