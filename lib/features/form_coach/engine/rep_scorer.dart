import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';

/// A plain-language grade for a repetition.
enum RepQuality {
  excellent('Excellent'),
  good('Good'),
  needsWork('Needs work'),
  poor('Poor');

  const RepQuality(this.label);

  final String label;

  static RepQuality fromScore(double score) {
    if (score >= 90) return excellent;
    if (score >= 75) return good;
    if (score >= 50) return needsWork;
    return poor;
  }
}

/// The result of judging one repetition.
class RepAnalysis {
  const RepAnalysis({
    required this.index,
    required this.score,
    required this.faults,
    required this.summary,
  });

  /// 1 for the first repetition of the set.
  final int index;

  /// From 0 to 100.
  final double score;
  final List<Fault> faults;
  final RepSummary summary;

  RepQuality get quality => RepQuality.fromScore(score);

  Set<String> get faultCodes => {for (final fault in faults) fault.code};
}

/// Scores repetitions against an exercise's rules.
class RepScorer {
  const RepScorer(this.rules);

  static const perfectScore = 100.0;

  final List<FormRule> rules;

  /// Judges [summary]: every rule that finds a problem takes points off 100.
  RepAnalysis score(int index, RepSummary summary) {
    final faults = <Fault>[for (final rule in rules) ?rule.evaluate(summary)];
    final deducted = faults.fold<double>(0, (sum, f) => sum + f.deduction);
    return RepAnalysis(
      index: index,
      score: (perfectScore - deducted).clamp(0.0, perfectScore),
      faults: faults,
      summary: summary,
    );
  }
}
