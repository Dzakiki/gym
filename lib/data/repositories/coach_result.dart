/// Which version of the Form Coach's scoring rules produced a result. Bump it
/// whenever rules or thresholds change in a way that alters scores.
const coachEngineVersion = 1;

/// One repetition's outcome, as stored.
class RepResult {
  const RepResult({
    required this.score,
    required this.faults,
    required this.descentMs,
    required this.ascentMs,
  });

  final double score;
  final List<String> faults;
  final int descentMs;
  final int ascentMs;

  Map<String, Object> toJson() => {
    'score': score,
    'faults': faults,
    'descentMs': descentMs,
    'ascentMs': ascentMs,
  };
}

/// What the Form Coach concluded about one set, in a form that can be saved.
class CoachResult {
  const CoachResult({
    required this.repsCounted,
    required this.partialReps,
    required this.reps,
    this.holdSeconds,
    this.setScore,
  });

  final int repsCounted;
  final int partialReps;
  final List<RepResult> reps;

  /// Seconds of good form held. Only set for hold exercises such as a plank.
  final double? holdSeconds;

  /// 0 to 100, or null if nothing was measured.
  final double? setScore;

  bool get isHold => holdSeconds != null;

  /// How many repetitions had each fault, by fault code.
  Map<String, int> get faultCounts {
    final counts = <String, int>{};
    for (final rep in reps) {
      for (final code in rep.faults) {
        counts.update(code, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }
}
