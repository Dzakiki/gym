import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Everything the coach needs to know about one exercise. Adding an exercise
/// means writing one of these, not changing the engine.
class ExerciseDefinition {
  const ExerciseDefinition({
    required this.key,
    required this.name,
    required this.view,
    required this.primaryMetric,
    required this.repConfig,
    required this.rules,
    required this.partialRepCue,
    required this.measure,
  });

  /// Matches `exercises.coach_key` in the exercise library, e.g. `squat`.
  final String key;
  final String name;
  final CameraView view;

  /// The measurement that drives rep counting. It is high at the start
  /// position and low at the bottom.
  final String primaryMetric;

  final RepMachineConfig repConfig;
  final List<FormRule> rules;

  /// What to say when an attempt does not go low enough to count.
  final String partialRepCue;

  /// Measures one frame for [side]. Returns null if a landmark the exercise
  /// needs is missing, so the frame is skipped.
  final Metrics? Function(PoseFrame frame, BodySide side) measure;
}
