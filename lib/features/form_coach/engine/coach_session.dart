import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/cue_manager.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/landmark_smoother.dart';
import 'package:formcoach/features/form_coach/engine/rep_scorer.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// What the coach concluded from one camera frame.
class CoachUpdate {
  const CoachUpdate({
    required this.frame,
    required this.tracking,
    required this.phase,
    this.metrics,
    this.completedRep,
    this.partialRep = false,
    this.cue,
  });

  /// The frame after smoothing and dropping unreliable landmarks.
  final PoseFrame frame;

  /// False while the person is out of view or the needed body parts are not
  /// visible.
  final bool tracking;

  final RepPhase phase;

  /// The measurements of this frame, if it could be measured.
  final Metrics? metrics;

  /// Set when a repetition was just completed and judged.
  final RepAnalysis? completedRep;

  /// True when an attempt just ended without reaching the bottom.
  final bool partialRep;

  /// Something to say or show right now, if anything.
  final Cue? cue;
}

/// Coaches one set of one exercise: feed it camera frames in order and it
/// counts repetitions, judges each one and decides what to tell the athlete.
class CoachSession {
  CoachSession({
    required this.definition,
    LandmarkSmoother? smoother,
    CueManager? cues,
    this.lostAfter = const Duration(milliseconds: 500),
  }) : _smoother = smoother ?? LandmarkSmoother(),
       _cues = cues ?? CueManager(),
       _machine = RepStateMachine(definition.repConfig),
       _scorer = RepScorer(definition.rules);

  final ExerciseDefinition definition;

  /// How long the person may be unmeasurable before the coach says so.
  final Duration lostAfter;

  final LandmarkSmoother _smoother;
  final CueManager _cues;
  final RepStateMachine _machine;
  final RepScorer _scorer;

  final _reps = <RepAnalysis>[];
  BodySide? _side;
  Duration? _lastTracked;
  _RepCollector? _collector;

  /// Analyses of the completed repetitions, in order.
  List<RepAnalysis> get reps => List.unmodifiable(_reps);

  int get repCount => _machine.repCount;

  /// Attempts that did not reach the bottom.
  int get partialCount => _machine.partialCount;

  /// The side of the body being measured, once known.
  BodySide? get side => _side;

  /// The average score of the completed repetitions, or null if there are none.
  double? get setScore => _reps.isEmpty
      ? null
      : _reps.fold<double>(0, (sum, r) => sum + r.score) / _reps.length;

  /// Processes one camera frame.
  CoachUpdate update(PoseFrame rawFrame) {
    final frame = _smoother.smooth(rawFrame);
    final time = frame.timestamp;
    final metrics = _measure(frame);

    if (metrics == null) return _notTracking(frame, time);
    _lastTracked = time;

    final event = _machine.update(metrics[definition.primaryMetric]!, time);
    _collect(metrics, time);

    RepAnalysis? completed;
    var partial = false;
    Cue? cue;
    switch (event) {
      case RepCompleted():
        completed = _scorer.score(_machine.repCount, _summarise(event));
        _reps.add(completed);
        cue = _cues.onRep(completed, time);
      case PartialRep():
        partial = true;
        cue = _cues.onPartialRep(definition.partialRepCue, time);
      case null:
        break;
    }
    if (event != null || _isAtRest) _collector = null;

    return CoachUpdate(
      frame: frame,
      tracking: true,
      phase: _machine.phase,
      metrics: metrics,
      completedRep: completed,
      partialRep: partial,
      cue: cue,
    );
  }

  /// Starts a fresh set.
  void reset() {
    _smoother.reset();
    _cues.reset();
    _machine.reset();
    _reps.clear();
    _side = null;
    _lastTracked = null;
    _collector = null;
  }

  bool get _isAtRest =>
      _machine.phase == RepPhase.top || _machine.phase == RepPhase.waiting;

  /// Measures [frame], choosing (and then keeping) the better-seen side.
  Metrics? _measure(PoseFrame frame) {
    final locked = _side;
    if (locked != null) return definition.measure(frame, locked);

    final sides = [...BodySide.values]
      ..sort((a, b) => b.visibility(frame).compareTo(a.visibility(frame)));
    for (final side in sides) {
      final metrics = definition.measure(frame, side);
      if (metrics != null) {
        _side = side;
        return metrics;
      }
    }
    return null;
  }

  CoachUpdate _notTracking(PoseFrame frame, Duration time) {
    final lastTracked = _lastTracked ?? Duration.zero;
    final lost = time - lastTracked > lostAfter;
    return CoachUpdate(
      frame: frame,
      tracking: !lost,
      phase: _machine.phase,
      cue: lost ? _cues.onPoseLost(time) : null,
    );
  }

  void _collect(Metrics metrics, Duration time) {
    if (_isAtRest) return;
    (_collector ??= _RepCollector(definition.primaryMetric)).add(metrics);
  }

  RepSummary _summarise(RepCompleted event) {
    final collector = _collector;
    if (collector == null) {
      throw StateError('A repetition ended without any measured frames.');
    }
    return collector.build(event);
  }
}

/// Gathers the measurements of one repetition frame by frame.
class _RepCollector {
  _RepCollector(this._primary);

  final String _primary;
  final _min = <String, double>{};
  final _max = <String, double>{};
  Metrics _atBottom = const {};
  double _lowestPrimary = double.infinity;

  void add(Metrics metrics) {
    for (final MapEntry(key: name, value: value) in metrics.entries) {
      final low = _min[name];
      final high = _max[name];
      if (low == null || value < low) _min[name] = value;
      if (high == null || value > high) _max[name] = value;
    }
    final primary = metrics[_primary]!;
    if (primary < _lowestPrimary) {
      _lowestPrimary = primary;
      _atBottom = Map.of(metrics);
    }
  }

  RepSummary build(RepEvent event) {
    return RepSummary(
      stats: {
        for (final name in _min.keys)
          name: MetricStats(
            min: _min[name]!,
            max: _max[name]!,
            atBottom: _atBottom[name] ?? _min[name]!,
          ),
      },
      descent: event.descentDuration,
      ascent: event.ascentDuration,
      startedAt: event.startedAt,
      endedAt: event.endedAt,
    );
  }
}
