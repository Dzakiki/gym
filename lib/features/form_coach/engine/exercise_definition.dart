import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// One thing that must stay true while holding a position, such as the hips
/// not sagging in a plank.
class HoldCheck {
  const HoldCheck({
    required this.code,
    required this.cue,
    required this.isViolated,
    this.safety = false,
  });

  final String code;

  /// What to say when the check has failed for a while.
  final String cue;

  /// True when the form is bad in this frame.
  final bool Function(Metrics metrics) isViolated;

  final bool safety;
}

/// How a time-based exercise (such as the plank) is judged.
class HoldSpec {
  const HoldSpec({
    required this.checks,
    this.violationDelay = const Duration(seconds: 1),
    this.milestoneEvery = const Duration(seconds: 15),
  });

  /// The checks. Time only counts as held while none is violated.
  final List<HoldCheck> checks;

  /// A problem must last this long before the athlete is told, so a moment of
  /// detection jitter does not trigger a cue.
  final Duration violationDelay;

  /// The coach encourages the athlete after each multiple of this much time
  /// held with good form.
  final Duration milestoneEvery;
}

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
  }) : hold = null;

  /// A time-based exercise judged by [hold] instead of by repetitions.
  const ExerciseDefinition.hold({
    required this.key,
    required this.name,
    required this.view,
    required this.measure,
    required HoldSpec this.hold,
  }) : primaryMetric = '',
       repConfig = const RepMachineConfig(downThreshold: 0, upThreshold: 1),
       rules = const [],
       partialRepCue = '';

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

  /// Set for time-based exercises. Such an exercise has no repetitions: the
  /// coach measures how long good form is held instead.
  final HoldSpec? hold;

  bool get isHold => hold != null;
}
