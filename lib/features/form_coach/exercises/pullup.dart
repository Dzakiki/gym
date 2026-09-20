import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Names of the measurements taken for the pull-up.
abstract final class PullupMetric {
  /// Angle at the elbow in degrees. 180 is a straight arm (hanging).
  static const elbowAngle = 'elbow_angle';

  /// How far the nose is above the wrists (which are on the bar), in torso
  /// lengths. Positive means the head is above the bar; the chin is a little
  /// lower than the nose.
  static const headAboveBar = 'head_above_bar';

  /// How far the body swings away from hanging straight down, in degrees.
  static const swing = 'swing';
}

/// Limits used by the pull-up rules. Starting values, to be tuned with real
/// recordings.
abstract final class PullupLimits {
  /// The nose may be this far below the bar (in torso lengths) and still count
  /// as chin over the bar.
  static const headTolerance = 0.05;

  /// At the bottom the elbows should be at least this straight.
  static const lockoutAngle = 165.0;

  /// The body may swing this many degrees before it counts as kipping.
  static const maxSwing = 20.0;

  /// Lowering faster than this is a drop rather than a controlled descent.
  static const minLowering = Duration(milliseconds: 800);
}

/// Measures a side-view pull-up frame, or returns null if a needed landmark
/// is missing.
Metrics? measurePullup(PoseFrame frame, BodySide side) {
  final nose = frame.position(Landmark.nose);
  final shoulder = frame.position(side.shoulder);
  final elbow = frame.position(side.elbow);
  final wrist = frame.position(side.wrist);
  final hip = frame.position(side.hip);
  final ankle = frame.position(side.ankle);
  if (nose == null ||
      shoulder == null ||
      elbow == null ||
      wrist == null ||
      hip == null ||
      ankle == null) {
    return null;
  }
  final torsoLength = shoulder.distanceTo(hip);
  if (torsoLength == 0) return null;

  return {
    PullupMetric.elbowAngle: angleAt(shoulder, elbow, wrist),
    PullupMetric.headAboveBar: (wrist.y - nose.y) / torsoLength,
    PullupMetric.swing: leanFromVertical(ankle, shoulder),
  };
}

double _scale(double value, {required double from, required double range}) =>
    ((value - from) / range).clamp(0.0, 1.0);

/// The pull-up: side view with the hands on a bar, counted when the elbow
/// bends to 80 degrees or less and the arms come back to about 150 degrees.
///
/// The main signal is high while hanging and low at the top of the pull, so
/// the "descent" the engine measures is the pull up and the "ascent" is the
/// lowering.
final pullup = ExerciseDefinition(
  key: 'pullup',
  name: 'Pull-up',
  view: CameraView.side,
  primaryMetric: PullupMetric.elbowAngle,
  repConfig: const RepMachineConfig(downThreshold: 80, upThreshold: 150),
  partialRepCue: 'Pull higher',
  measure: measurePullup,
  rules: [
    FormRule(
      code: 'pullup_height',
      cue: 'Pull higher',
      weight: 30,
      check: (rep) => _scale(
        -PullupLimits.headTolerance - rep.stat(PullupMetric.headAboveBar).max,
        from: 0,
        range: 0.3,
      ),
    ),
    FormRule(
      code: 'pullup_lockout',
      cue: 'Lower all the way down',
      weight: 15,
      check: (rep) => _scale(
        PullupLimits.lockoutAngle - rep.stat(PullupMetric.elbowAngle).max,
        from: 0,
        range: 25,
      ),
    ),
    FormRule(
      code: 'pullup_swing',
      cue: 'Keep your body still',
      weight: 15,
      check: (rep) => _scale(
        rep.stat(PullupMetric.swing).max,
        from: PullupLimits.maxSwing,
        range: 20,
      ),
    ),
    FormRule(
      code: 'pullup_tempo',
      cue: 'Lower with control',
      weight: 10,
      check: (rep) => _scale(
        (PullupLimits.minLowering - rep.ascent).inMilliseconds / 1000,
        from: 0,
        range: 0.5,
      ),
    ),
  ],
);
