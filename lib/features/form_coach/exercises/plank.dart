import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Names of the measurements taken for the plank.
abstract final class PlankMetric {
  /// How far the hips are above (positive) or below (negative) the straight
  /// line from shoulders to ankles, as a fraction of that line's length.
  static const hipHeight = 'hip_height';

  /// How far the shoulder is in front of or behind the elbow, as a fraction
  /// of the shoulder-to-ankle length. Zero means directly above.
  static const shoulderOffset = 'shoulder_offset';
}

/// Limits used by the plank checks. Starting values, to be tuned with real
/// recordings.
abstract final class PlankLimits {
  static const sagTolerance = 0.05;
  static const pikeTolerance = 0.09;
  static const shoulderOffsetTolerance = 0.15;
}

/// Measures a side-view plank frame, or returns null if a needed landmark is
/// missing.
Metrics? measurePlank(PoseFrame frame, BodySide side) {
  final shoulder = frame.position(side.shoulder);
  final elbow = frame.position(side.elbow);
  final hip = frame.position(side.hip);
  final ankle = frame.position(side.ankle);
  if (shoulder == null || elbow == null || hip == null || ankle == null) {
    return null;
  }
  final length = shoulder.distanceTo(ankle);
  if (length == 0) return null;

  return {
    PlankMetric.hipHeight: heightAboveLine(hip, from: shoulder, to: ankle),
    PlankMetric.shoulderOffset: (shoulder.x - elbow.x).abs() / length,
  };
}

/// The forearm plank: side view, judged by how long good form is held.
final plank = ExerciseDefinition.hold(
  key: 'plank',
  name: 'Plank',
  view: CameraView.side,
  measure: measurePlank,
  hold: HoldSpec(
    checks: [
      HoldCheck(
        code: 'plank_hip_sag',
        cue: 'Hips up',
        safety: true,
        isViolated: (m) =>
            m[PlankMetric.hipHeight]! < -PlankLimits.sagTolerance,
      ),
      HoldCheck(
        code: 'plank_hip_pike',
        cue: 'Lower your hips',
        isViolated: (m) =>
            m[PlankMetric.hipHeight]! > PlankLimits.pikeTolerance,
      ),
      HoldCheck(
        code: 'plank_shoulders',
        cue: 'Shoulders over elbows',
        isViolated: (m) =>
            m[PlankMetric.shoulderOffset]! >
            PlankLimits.shoulderOffsetTolerance,
      ),
    ],
  ),
);
