import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Names of the measurements taken for the jumping jack.
abstract final class JumpingJackMetric {
  /// How closed the body is: 1 with arms down and feet together, 0 with arms
  /// overhead and feet wide. The rep counter follows this.
  static const closedness = 'closedness';

  /// How high the wrists are above the shoulders, in torso lengths, averaged
  /// over both arms. About -1 with arms down and about +1 straight overhead.
  static const armElevation = 'arm_elevation';

  /// The distance between the ankles in shoulder widths.
  static const footSpread = 'foot_spread';

  /// The difference in wrist height between the two arms, in torso lengths.
  static const armAsymmetry = 'arm_asymmetry';
}

/// Limits used by the jumping jack rules. Starting values, to be tuned with
/// real recordings.
abstract final class JumpingJackLimits {
  /// The wrists should get at least this far above the shoulders.
  static const minArmElevation = 0.4;

  /// The feet should get at least this wide apart (shoulder widths).
  static const minFootSpread = 1.6;

  /// The arms may differ this much in height (torso lengths).
  static const maxAsymmetry = 0.25;
}

// How arm elevation and foot spread map onto "how open" the body is (0..1).
const _armsDown = -0.9;
const _armRange = 1.7;
const _feetTogether = 1.0;
const _footRange = 1.2;

double _unit(double value) => value.clamp(0.0, 1.0);

/// Measures a front-view jumping jack frame, or returns null if a needed
/// landmark is missing. Both sides are used, so [side] is ignored.
Metrics? measureJumpingJack(PoseFrame frame, BodySide side) {
  final leftShoulder = frame.position(Landmark.leftShoulder);
  final rightShoulder = frame.position(Landmark.rightShoulder);
  final leftWrist = frame.position(Landmark.leftWrist);
  final rightWrist = frame.position(Landmark.rightWrist);
  final leftHip = frame.position(Landmark.leftHip);
  final rightHip = frame.position(Landmark.rightHip);
  final leftAnkle = frame.position(Landmark.leftAnkle);
  final rightAnkle = frame.position(Landmark.rightAnkle);
  if (leftShoulder == null ||
      rightShoulder == null ||
      leftWrist == null ||
      rightWrist == null ||
      leftHip == null ||
      rightHip == null ||
      leftAnkle == null ||
      rightAnkle == null) {
    return null;
  }

  final torsoLength = leftShoulder
      .midpointTo(rightShoulder)
      .distanceTo(leftHip.midpointTo(rightHip));
  final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
  if (torsoLength == 0 || shoulderWidth == 0) return null;

  final leftElevation = (leftShoulder.y - leftWrist.y) / torsoLength;
  final rightElevation = (rightShoulder.y - rightWrist.y) / torsoLength;
  final armElevation = (leftElevation + rightElevation) / 2;
  final footSpread = (leftAnkle.x - rightAnkle.x).abs() / shoulderWidth;

  final armsOpen = _unit((armElevation - _armsDown) / _armRange);
  final feetOpen = _unit((footSpread - _feetTogether) / _footRange);
  return {
    JumpingJackMetric.closedness: 1 - (armsOpen + feetOpen) / 2,
    JumpingJackMetric.armElevation: armElevation,
    JumpingJackMetric.footSpread: footSpread,
    JumpingJackMetric.armAsymmetry: (leftElevation - rightElevation).abs(),
  };
}

double _scale(double value, {required double from, required double range}) =>
    ((value - from) / range).clamp(0.0, 1.0);

/// The jumping jack: front view, counted each time the body opens (arms up,
/// feet out) and closes again.
final jumpingJack = ExerciseDefinition(
  key: 'jumping_jack',
  name: 'Jumping jack',
  view: CameraView.front,
  primaryMetric: JumpingJackMetric.closedness,
  // A jumping jack is quick, so shorter movements than for other exercises
  // still count as a repetition (or a partial one).
  repConfig: const RepMachineConfig(
    downThreshold: 0.35,
    upThreshold: 0.8,
    minRepDuration: Duration(milliseconds: 250),
  ),
  partialRepCue: 'Open up more',
  measure: measureJumpingJack,
  rules: [
    FormRule(
      code: 'jj_arms',
      cue: 'Arms all the way up',
      weight: 20,
      check: (rep) => _scale(
        JumpingJackLimits.minArmElevation -
            rep.stat(JumpingJackMetric.armElevation).max,
        from: 0,
        range: 0.5,
      ),
    ),
    FormRule(
      code: 'jj_feet',
      cue: 'Jump wider',
      weight: 15,
      check: (rep) => _scale(
        JumpingJackLimits.minFootSpread -
            rep.stat(JumpingJackMetric.footSpread).max,
        from: 0,
        range: 0.6,
      ),
    ),
    FormRule(
      code: 'jj_symmetry',
      cue: 'Even on both sides',
      weight: 10,
      check: (rep) => _scale(
        rep.stat(JumpingJackMetric.armAsymmetry).max,
        from: JumpingJackLimits.maxAsymmetry,
        range: 0.4,
      ),
    ),
  ],
);
