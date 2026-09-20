/// Where the athlete is within a repetition.
enum RepPhase {
  /// Not yet standing at the top position, so nothing is counted.
  waiting,

  /// At the start position (e.g. standing up straight).
  top,

  /// Moving down towards the bottom position.
  descending,

  /// At the bottom position (e.g. deepest part of a squat).
  bottom,

  /// Moving back up.
  ascending,
}

/// Thresholds for one exercise's main signal.
///
/// The signal is high at the start position and low at the bottom, for
/// example a knee angle of about 170 when standing and 90 when squatting.
class RepMachineConfig {
  const RepMachineConfig({
    required this.downThreshold,
    required this.upThreshold,
    this.hysteresisFraction = 0.05,
    this.partialFraction = 0.25,
    this.minRepDuration = const Duration(milliseconds: 400),
    this.maxRepDuration = const Duration(seconds: 10),
  }) : assert(downThreshold < upThreshold, 'down must be below up');

  /// The signal is at the bottom when it is at or below this value.
  final double downThreshold;

  /// The signal is at the top when it is at or above this value.
  final double upThreshold;

  /// Fraction of the range the signal must move away from a threshold before
  /// the phase changes again. Prevents flicker from jitter at a threshold.
  final double hysteresisFraction;

  /// Fraction of the range the signal must drop to count as a partial rep
  /// (an attempt that did not reach the bottom).
  final double partialFraction;

  /// Movements shorter than this are treated as noise, not repetitions.
  final Duration minRepDuration;

  /// A repetition that takes longer is abandoned.
  final Duration maxRepDuration;

  double get range => upThreshold - downThreshold;
}

/// Something worth reporting that happened during a repetition.
sealed class RepEvent {
  const RepEvent({
    required this.startedAt,
    required this.endedAt,
    required this.bottomAt,
    required this.minSignal,
  });

  /// When the athlete left the top position.
  final Duration startedAt;

  /// When the athlete returned to the top position.
  final Duration endedAt;

  /// When the signal was lowest.
  final Duration bottomAt;

  /// The lowest value the signal reached.
  final double minSignal;

  /// Time from leaving the top zone to the lowest point.
  Duration get descentDuration => bottomAt - startedAt;

  /// Time from the lowest point to being back at the top.
  Duration get ascentDuration => endedAt - bottomAt;
}

/// A full repetition: down to the bottom and back up.
class RepCompleted extends RepEvent {
  const RepCompleted({
    required super.startedAt,
    required super.endedAt,
    required super.bottomAt,
    required super.minSignal,
  });
}

/// An attempt that went down noticeably but came back without reaching the
/// bottom. It is not counted.
class PartialRep extends RepEvent {
  const PartialRep({
    required super.startedAt,
    required super.endedAt,
    required super.bottomAt,
    required super.minSignal,
  });
}

/// Turns a stream of signal values into counted repetitions.
///
/// Feed every frame's value to [update]. A repetition is counted only after
/// the athlete has been at the top, gone down to the bottom and come back up.
class RepStateMachine {
  RepStateMachine(this.config);

  final RepMachineConfig config;

  RepPhase _phase = RepPhase.waiting;
  int _repCount = 0;
  int _partialCount = 0;

  Duration _lastTopAt = Duration.zero;
  Duration _startedAt = Duration.zero;
  Duration _bottomAt = Duration.zero;
  double _minSignal = double.infinity;

  RepPhase get phase => _phase;

  /// Completed repetitions so far.
  int get repCount => _repCount;

  /// Attempts that did not reach the bottom.
  int get partialCount => _partialCount;

  double get _hysteresis => config.range * config.hysteresisFraction;

  /// Processes one value seen at [time]. Returns an event when a repetition
  /// or partial repetition just ended.
  RepEvent? update(double signal, Duration time) {
    switch (_phase) {
      case RepPhase.waiting:
        if (signal >= config.upThreshold) _enterTop(time);
      case RepPhase.top:
        if (signal < config.upThreshold - _hysteresis) {
          _startedAt = _lastTopAt;
          _bottomAt = time;
          _minSignal = signal;
          _phase = RepPhase.descending;
        } else {
          _lastTopAt = time;
        }
      case RepPhase.descending:
        _track(signal, time);
        if (_isTooLong(time)) return _abandon();
        if (signal <= config.downThreshold) {
          _phase = RepPhase.bottom;
        } else if (signal >= config.upThreshold) {
          return _returnedWithoutBottom(time);
        }
      case RepPhase.bottom:
        _track(signal, time);
        if (_isTooLong(time)) return _abandon();
        if (signal > config.downThreshold + _hysteresis) {
          _phase = RepPhase.ascending;
        }
      case RepPhase.ascending:
        _track(signal, time);
        if (_isTooLong(time)) return _abandon();
        if (signal <= config.downThreshold) {
          _phase = RepPhase.bottom;
        } else if (signal >= config.upThreshold) {
          return _completeRep(time);
        }
    }
    return null;
  }

  /// Forgets everything, including the counts.
  void reset() {
    _phase = RepPhase.waiting;
    _repCount = 0;
    _partialCount = 0;
    _minSignal = double.infinity;
  }

  void _enterTop(Duration time) {
    _phase = RepPhase.top;
    _lastTopAt = time;
  }

  void _track(double signal, Duration time) {
    if (signal < _minSignal) {
      _minSignal = signal;
      _bottomAt = time;
    }
  }

  bool _isTooLong(Duration time) => time - _startedAt > config.maxRepDuration;

  RepEvent? _abandon() {
    _phase = RepPhase.waiting;
    return null;
  }

  RepEvent? _completeRep(Duration time) {
    _enterTop(time);
    if (time - _startedAt < config.minRepDuration) return null;
    _repCount++;
    return RepCompleted(
      startedAt: _startedAt,
      endedAt: time,
      bottomAt: _bottomAt,
      minSignal: _minSignal,
    );
  }

  RepEvent? _returnedWithoutBottom(Duration time) {
    _enterTop(time);
    final droppedEnough =
        _minSignal <=
        config.upThreshold - config.partialFraction * config.range;
    if (!droppedEnough || time - _startedAt < config.minRepDuration) {
      return null;
    }
    _partialCount++;
    return PartialRep(
      startedAt: _startedAt,
      endedAt: time,
      bottomAt: _bottomAt,
      minSignal: _minSignal,
    );
  }
}
