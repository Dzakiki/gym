import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Names of the measurements taken for the push-up.
abstract final class PushupMetric {
  /// Angle at the elbow in degrees. 180 is a straight arm.
  static const elbowAngle = 'elbow_angle';

  /// How far the hips are above (positive) or below (negative) the straight
  /// line from shoulders to ankles, as a fraction of that line's length.
  static const hipHeight = 'hip_height';
}

/// Limits used by the push-up rules. Starting values, to be tuned with real
/// recordings.
abstract final class PushupLimits {
  /// Hips may sag this far below the body line before it counts as a fault.
  static const sagTolerance = 0.04;

  /// Hips may rise this far above the body line before it counts as piking.
  static const pikeTolerance = 0.08;

  /// At the top the elbows should be at least this straight.
  static const lockoutAngle = 165.0;
}

/// Measures a side-view push-up frame, or returns null if a needed landmark
/// is missing.
Metrics? measurePushup(PoseFrame frame, BodySide side) {
  final shoulder = frame.position(side.shoulder);
  final elbow = frame.position(side.elbow);
  final wrist = frame.position(side.wrist);
  final hip = frame.position(side.hip);
  final ankle = frame.position(side.ankle);
  if (shoulder == null ||
      elbow == null ||
      wrist == null ||
      hip == null ||
      ankle == null) {
    return null;
  }

  if (shoulder == ankle) return null;

  return {
    PushupMetric.elbowAngle: angleAt(shoulder, elbow, wrist),
    PushupMetric.hipHeight: heightAboveLine(hip, from: shoulder, to: ankle),
  };
}

double _scale(double value, {required double from, required double range}) =>
    ((value - from) / range).clamp(0.0, 1.0);

/// The push-up: side view, counted when the elbow bends to 90 degrees or
/// less and the arms come back up to about 150 degrees or more.
final pushup = ExerciseDefinition(
  key: 'pushup',
  name: 'Push-up',
  view: CameraView.side,
  primaryMetric: PushupMetric.elbowAngle,
  repConfig: const RepMachineConfig(downThreshold: 90, upThreshold: 150),
  partialRepCue: 'Go lower',
  measure: measurePushup,
  rules: [
    FormRule(
      code: 'pushup_hip_sag',
      cue: 'Tighten your core, hips up',
      weight: 25,
      safety: true,
      check: (rep) => _scale(
        -rep.stat(PushupMetric.hipHeight).min,
        from: PushupLimits.sagTolerance,
        range: 0.12,
      ),
    ),
    FormRule(
      code: 'pushup_hip_pike',
      cue: 'Lower your hips',
      weight: 15,
      check: (rep) => _scale(
        rep.stat(PushupMetric.hipHeight).max,
        from: PushupLimits.pikeTolerance,
        range: 0.12,
      ),
    ),
    FormRule(
      code: 'pushup_lockout',
      cue: 'Push all the way up',
      weight: 10,
      check: (rep) => _scale(
        PushupLimits.lockoutAngle - rep.stat(PushupMetric.elbowAngle).max,
        from: 0,
        range: 25,
      ),
    ),
  ],
);
