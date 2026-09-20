import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/cue_manager.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/hold_timer.dart';
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
    this.holdTime,
    this.formValid,
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

  /// For hold exercises: how long good form has been held so far.
  final Duration? holdTime;

  /// For hold exercises: whether the form in this frame was good.
  final bool? formValid;
}

/// Coaches one set of one exercise: feed it camera frames in order and it
/// counts repetitions, judges each one and decides what to tell the athlete.
class CoachSession {
  /// About a third of a second of frames at 30 fps.
  static const _leadInFrames = 10;

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

  // Hold mode (e.g. plank).
  final _holdTimer = HoldTimer();
  final _violationSince = <String, Duration>{};

  /// The last few frames spent at the top, so a repetition's statistics also
  /// cover how the athlete started (e.g. arms fully locked out).
  final _leadIn = <Metrics>[];

  /// Analyses of the completed repetitions, in order.
  List<RepAnalysis> get reps => List.unmodifiable(_reps);

  int get repCount => _machine.repCount;

  /// Attempts that did not reach the bottom.
  int get partialCount => _machine.partialCount;

  /// The side of the body being measured, once known.
  BodySide? get side => _side;

  /// How long good form was held (hold exercises only).
  Duration get holdTime => _holdTimer.held;

  /// The share of the time in position that had good form, from 0 to 100, or
  /// null before any time has been measured (hold exercises only).
  double? get holdScore {
    final total = _holdTimer.held + _holdTimer.brokenForm;
    if (total == Duration.zero) return null;
    return _holdTimer.held.inMicroseconds / total.inMicroseconds * 100;
  }

  /// The score of the set: the average of the completed repetitions, or the
  /// share of good form for a hold. Null if nothing was measured.
  double? get setScore {
    if (definition.isHold) return holdScore;
    if (_reps.isEmpty) return null;
    return _reps.fold<double>(0, (sum, r) => sum + r.score) / _reps.length;
  }

  /// Processes one camera frame.
  CoachUpdate update(PoseFrame rawFrame) {
    final frame = _smoother.smooth(rawFrame);
    final time = frame.timestamp;
    final metrics = _measure(frame);

    if (metrics == null) return _notTracking(frame, time);
    _lastTracked = time;
    if (definition.isHold) return _updateHold(frame, metrics, time);

    final event = _machine.update(metrics[definition.primaryMetric]!, time);
    _collect(metrics);

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
    _leadIn.clear();
    _holdTimer.reset();
    _violationSince.clear();
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

  CoachUpdate _updateHold(PoseFrame frame, Metrics metrics, Duration time) {
    final spec = definition.hold!;
    final violated = [
      for (final check in spec.checks)
        if (check.isViolated(metrics)) check,
    ];
    final valid = violated.isEmpty;
    final before = _holdTimer.held;
    _holdTimer.update(valid: valid, time: time);

    final violatedCodes = {for (final check in violated) check.code};
    _violationSince.removeWhere((code, _) => !violatedCodes.contains(code));
    for (final check in violated) {
      _violationSince.putIfAbsent(check.code, () => time);
    }

    Cue? cue;
    for (final check in violated) {
      if (time - _violationSince[check.code]! < spec.violationDelay) continue;
      cue = _cues.request(
        check.code,
        check.cue,
        check.safety ? CueKind.safety : CueKind.correction,
        time,
      );
      if (cue != null) break;
    }
    final held = _holdTimer.held;
    final every = spec.milestoneEvery.inMilliseconds;
    if (cue == null &&
        held.inMilliseconds ~/ every > before.inMilliseconds ~/ every) {
      final seconds = held.inSeconds;
      cue = _cues.request(
        'milestone_$seconds',
        '$seconds seconds, keep going',
        CueKind.encouragement,
        time,
      );
    }

    return CoachUpdate(
      frame: frame,
      tracking: true,
      phase: _machine.phase,
      metrics: metrics,
      cue: cue,
      holdTime: held,
      formValid: valid,
    );
  }

  CoachUpdate _notTracking(PoseFrame frame, Duration time) {
    final lastTracked = _lastTracked ?? Duration.zero;
    final lost = time - lastTracked > lostAfter;
    return CoachUpdate(
      frame: frame,
      tracking: !lost,
      phase: _machine.phase,
      cue: lost ? _cues.onPoseLost(time) : null,
      holdTime: definition.isHold ? _holdTimer.held : null,
    );
  }

  void _collect(Metrics metrics) {
    if (_isAtRest) {
      _leadIn.add(metrics);
      if (_leadIn.length > _leadInFrames) _leadIn.removeAt(0);
      return;
    }
    var collector = _collector;
    if (collector == null) {
      collector = _collector = _RepCollector(definition.primaryMetric);
      _leadIn.forEach(collector.add);
      _leadIn.clear();
    }
    collector.add(metrics);
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
