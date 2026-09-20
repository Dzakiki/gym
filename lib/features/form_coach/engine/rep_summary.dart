/// Named measurements taken from one frame, e.g. `knee_angle` in degrees.
typedef Metrics = Map<String, double>;

/// How one measurement behaved over a whole repetition.
class MetricStats {
  const MetricStats({
    required this.min,
    required this.max,
    required this.atBottom,
  });

  final double min;
  final double max;

  /// The value at the lowest point of the repetition.
  final double atBottom;
}

/// Everything measured during one repetition, ready for the form rules.
class RepSummary {
  const RepSummary({
    required this.stats,
    required this.descent,
    required this.ascent,
    required this.startedAt,
    required this.endedAt,
  });

  final Map<String, MetricStats> stats;

  /// Time from leaving the top to the lowest point.
  final Duration descent;

  /// Time from the lowest point back to the top.
  final Duration ascent;

  final Duration startedAt;
  final Duration endedAt;

  /// The statistics for [metric]. Throws [StateError] if it was not measured,
  /// which means the exercise definition and its rules disagree.
  MetricStats stat(String metric) =>
      stats[metric] ?? (throw StateError('Metric "$metric" was not measured.'));
}
