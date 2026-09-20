import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Names of the measurements taken for the dip.
abstract final class DipMetric {
  /// Angle at the elbow in degrees. 180 is a straight arm.
  static const elbowAngle = 'elbow_angle';

  /// How far the shoulder is below the elbow, in torso lengths. Zero means
  /// the upper arm is level; negative means the shoulder is still above the
  /// elbow.
  static const shoulderBelowElbow = 'shoulder_below_elbow';
}

/// Limits used by the dip rules. Starting values, to be tuned with real
/// recordings.
abstract final class DipLimits {
  /// The shoulder should get to (about) elbow height at the bottom.
  static const depthTolerance = 0.05;

  /// Going further than this puts a lot of strain on the shoulders.
  static const maxDepth = 0.22;

  /// At the top the elbows should be at least this straight.
  static const lockoutAngle = 165.0;

  /// Going down faster than this is too fast to stay in control.
  static const minDescent = Duration(milliseconds: 800);
}

/// Measures a side-view dip frame (on parallel bars or between two chairs), or
/// returns null if a needed landmark is missing.
Metrics? measureDip(PoseFrame frame, BodySide side) {
  final shoulder = frame.position(side.shoulder);
  final elbow = frame.position(side.elbow);
  final wrist = frame.position(side.wrist);
  final hip = frame.position(side.hip);
  if (shoulder == null || elbow == null || wrist == null || hip == null) {
    return null;
  }
  final torsoLength = shoulder.distanceTo(hip);
  if (torsoLength == 0) return null;

  return {
    DipMetric.elbowAngle: angleAt(shoulder, elbow, wrist),
    DipMetric.shoulderBelowElbow: (shoulder.y - elbow.y) / torsoLength,
  };
}

double _scale(double value, {required double from, required double range}) =>
    ((value - from) / range).clamp(0.0, 1.0);

/// The dip: side view, counted when the elbow bends to 100 degrees or less
/// and the arms straighten again to 150 degrees or more.
final dip = ExerciseDefinition(
  key: 'dip',
  name: 'Dip',
  view: CameraView.side,
  primaryMetric: DipMetric.elbowAngle,
  repConfig: const RepMachineConfig(downThreshold: 100, upThreshold: 150),
  partialRepCue: 'Go lower',
  measure: measureDip,
  rules: [
    FormRule(
      code: 'dip_depth',
      cue: 'Go lower',
      weight: 30,
      check: (rep) => _scale(
        -DipLimits.depthTolerance - rep.stat(DipMetric.shoulderBelowElbow).max,
        from: 0,
        range: 0.3,
      ),
    ),
    FormRule(
      code: 'dip_too_deep',
      cue: 'Not so deep',
      weight: 15,
      safety: true,
      check: (rep) => _scale(
        rep.stat(DipMetric.shoulderBelowElbow).max,
        from: DipLimits.maxDepth,
        range: 0.15,
      ),
    ),
    FormRule(
      code: 'dip_lockout',
      cue: 'Push all the way up',
      weight: 10,
      check: (rep) => _scale(
        DipLimits.lockoutAngle - rep.stat(DipMetric.elbowAngle).max,
        from: 0,
        range: 25,
      ),
    ),
    FormRule(
      code: 'dip_tempo',
      cue: 'Control the way down',
      weight: 10,
      check: (rep) => _scale(
        (DipLimits.minDescent - rep.descent).inMilliseconds / 1000,
        from: 0,
        range: 0.5,
      ),
    ),
  ],
);
