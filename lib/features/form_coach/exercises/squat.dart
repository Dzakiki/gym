import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Names of the measurements taken for the squat.
abstract final class SquatMetric {
  /// Angle at the knee in degrees. 180 is a straight leg.
  static const kneeAngle = 'knee_angle';

  /// How far the torso leans away from upright, in degrees.
  static const torsoLean = 'torso_lean';

  /// How far the hip is below the knee, in torso lengths. Zero means the hip
  /// is level with the knee (thighs parallel); negative means above.
  static const hipDrop = 'hip_drop';

  /// How far the knee is past the toes, in torso lengths. Negative means the
  /// knee is behind the toes.
  static const kneeOverToe = 'knee_over_toe';
}

/// Limits used by the squat rules. They are starting values to be tuned with
/// real recordings.
abstract final class SquatLimits {
  /// Hips may be this far above the knees (in torso lengths) and still count
  /// as deep enough, to allow for detection noise.
  static const depthTolerance = 0.1;

  /// The torso may lean this far forward at the bottom.
  static const maxTorsoLean = 45.0;

  /// The knees may go this far past the toes (in torso lengths).
  static const maxKneeOverToe = 0.35;

  /// Going down faster than this is too fast to stay in control.
  static const minDescent = Duration(milliseconds: 800);
}

/// Measures a side-view squat frame, or returns null if a needed landmark is
/// missing.
Metrics? measureSquat(PoseFrame frame, BodySide side) {
  final shoulder = frame.position(side.shoulder);
  final hip = frame.position(side.hip);
  final knee = frame.position(side.knee);
  final ankle = frame.position(side.ankle);
  final toe = frame.position(side.toe);
  if (shoulder == null ||
      hip == null ||
      knee == null ||
      ankle == null ||
      toe == null) {
    return null;
  }

  final torsoLength = shoulder.distanceTo(hip);
  if (torsoLength == 0) return null;

  // The toes point the way the person faces.
  final facing = (toe.x - ankle.x) >= 0 ? 1.0 : -1.0;
  return {
    SquatMetric.kneeAngle: angleAt(hip, knee, ankle),
    SquatMetric.torsoLean: leanFromVertical(hip, shoulder),
    SquatMetric.hipDrop: (hip.y - knee.y) / torsoLength,
    SquatMetric.kneeOverToe: (knee.x - toe.x) * facing / torsoLength,
  };
}

double _scale(double value, {required double from, required double range}) =>
    ((value - from) / range).clamp(0.0, 1.0);

/// The squat: side view, counted when the knee bends past 100 degrees.
final squat = ExerciseDefinition(
  key: 'squat',
  name: 'Squat',
  view: CameraView.side,
  primaryMetric: SquatMetric.kneeAngle,
  repConfig: const RepMachineConfig(downThreshold: 100, upThreshold: 160),
  partialRepCue: 'Go deeper',
  measure: measureSquat,
  rules: [
    FormRule(
      code: 'squat_depth',
      cue: 'Go deeper',
      weight: 30,
      check: (rep) => _scale(
        -SquatLimits.depthTolerance - rep.stat(SquatMetric.hipDrop).max,
        from: 0,
        range: 0.5,
      ),
    ),
    FormRule(
      code: 'squat_torso_lean',
      cue: 'Chest up',
      weight: 20,
      check: (rep) => _scale(
        rep.stat(SquatMetric.torsoLean).atBottom,
        from: SquatLimits.maxTorsoLean,
        range: 30,
      ),
    ),
    FormRule(
      code: 'squat_knee_forward',
      cue: 'Sit back into your hips',
      weight: 15,
      check: (rep) => _scale(
        rep.stat(SquatMetric.kneeOverToe).max,
        from: SquatLimits.maxKneeOverToe,
        range: 0.35,
      ),
    ),
    FormRule(
      code: 'squat_tempo',
      cue: 'Slow down on the way down',
      weight: 10,
      check: (rep) => _scale(
        (SquatLimits.minDescent - rep.descent).inMilliseconds / 1000,
        from: 0,
        range: 0.5,
      ),
    ),
  ],
);
