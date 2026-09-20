import 'package:flutter/material.dart';
import 'package:formcoach/features/form_coach/engine/rep_scorer.dart';

/// How often one kind of fault showed up in a set.
class FaultSummary {
  const FaultSummary({
    required this.code,
    required this.cue,
    required this.count,
  });

  final String code;

  /// The advice for this fault, e.g. "Chest up".
  final String cue;

  /// The number of repetitions that had it.
  final int count;
}

/// Counts the faults over [reps], most frequent first (ties: costliest first).
List<FaultSummary> summariseFaults(List<RepAnalysis> reps) {
  final counts = <String, int>{};
  final cues = <String, String>{};
  final deductions = <String, double>{};
  for (final rep in reps) {
    for (final fault in rep.faults) {
      counts.update(fault.code, (n) => n + 1, ifAbsent: () => 1);
      cues[fault.code] = fault.cue;
      deductions.update(
        fault.code,
        (d) => d + fault.deduction,
        ifAbsent: () => fault.deduction,
      );
    }
  }
  final codes = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : deductions[b]!.compareTo(deductions[a]!);
    });
  return [
    for (final code in codes)
      FaultSummary(code: code, cue: cues[code]!, count: counts[code]!),
  ];
}

/// The colour used for a repetition of the given quality.
Color qualityColor(RepQuality quality, ColorScheme scheme) => switch (quality) {
  RepQuality.excellent => scheme.primary,
  RepQuality.good => scheme.secondary,
  RepQuality.needsWork => scheme.tertiary,
  RepQuality.poor => scheme.error,
};

/// The results of a finished set: score, a bar per repetition and the most
/// common form problems.
class SetSummary extends StatelessWidget {
  const SetSummary({
    required this.reps,
    required this.partialCount,
    this.maxFaults = 3,
    super.key,
  });

  final List<RepAnalysis> reps;
  final int partialCount;
  final int maxFaults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (reps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          partialCount == 0
              ? 'No repetitions were counted.'
              : 'No full repetitions were counted. $partialCount attempts '
                    'did not go low enough.',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    final score = reps.fold<double>(0, (sum, r) => sum + r.score) / reps.length;
    final quality = RepQuality.fromScore(score);
    final faults = summariseFaults(reps).take(maxFaults).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.round().toString(),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: qualityColor(quality, theme.colorScheme),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${quality.label}, ${reps.length} reps',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (partialCount > 0)
            Text(
              '$partialCount attempts did not go low enough.',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 16),
          Text('Each repetition', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (final rep in reps) _Bar(rep: rep)],
            ),
          ),
          const SizedBox(height: 16),
          Text('To work on', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (faults.isEmpty)
            Text('No form problems found.', style: theme.textTheme.bodyLarge)
          else
            for (final fault in faults)
              Text(
                '${fault.cue}: ${fault.count} of ${reps.length} reps',
                style: theme.textTheme.bodyLarge,
              ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.rep});

  final RepAnalysis rep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        label: 'Rep ${rep.index}: ${rep.score.round()}, ${rep.quality.label}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FractionallySizedBox(
            heightFactor: (rep.score / 100).clamp(0.05, 1.0),
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: qualityColor(rep.quality, scheme),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The results of a finished hold (such as a plank): time held with good form
/// and the share of the time the form was good.
class HoldSummary extends StatelessWidget {
  const HoldSummary({required this.holdTime, required this.score, super.key});

  final Duration holdTime;

  /// From 0 to 100, or null if nothing was measured.
  final double? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = this.score;
    if (score == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No time was measured.', style: theme.textTheme.bodyLarge),
      );
    }
    final quality = RepQuality.fromScore(score);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${holdTime.inSeconds} s',
            style: theme.textTheme.displayMedium?.copyWith(
              color: qualityColor(quality, theme.colorScheme),
            ),
          ),
          Text('held with good form', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '${score.round()}% of the time in position had good form '
            '(${quality.label}).',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
