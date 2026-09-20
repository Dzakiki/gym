import 'package:formcoach/features/form_coach/engine/rep_summary.dart';

/// One thing to check about a repetition, such as squat depth.
class FormRule {
  const FormRule({
    required this.code,
    required this.cue,
    required this.weight,
    required this.check,
    this.safety = false,
  });

  /// A stable id such as `squat_depth`, stored with results.
  final String code;

  /// What to say to the athlete, e.g. "Go deeper".
  final String cue;

  /// The most points this rule can take off a repetition's score of 100.
  final double weight;

  /// Safety problems are spoken about straight away, not after two reps.
  final bool safety;

  /// Returns how bad the problem was, from 0 (fine) to 1 (as bad as it gets).
  final double Function(RepSummary rep) check;

  /// Runs the check and returns a [Fault], or null if the form was fine.
  Fault? evaluate(RepSummary rep) {
    final severity = check(rep).clamp(0.0, 1.0);
    if (severity <= 0) return null;
    return Fault(
      code: code,
      cue: cue,
      severity: severity,
      weight: weight,
      safety: safety,
    );
  }
}

/// A problem found in one repetition.
class Fault {
  const Fault({
    required this.code,
    required this.cue,
    required this.severity,
    required this.weight,
    required this.safety,
  });

  final String code;
  final String cue;

  /// From 0 (barely) to 1 (worst).
  final double severity;
  final double weight;
  final bool safety;

  /// Points taken off the repetition's score.
  double get deduction => weight * severity;
}
