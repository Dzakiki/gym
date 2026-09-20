import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/rep_scorer.dart';

/// Why a cue is being given.
enum CueKind {
  /// A safety problem. Always spoken first.
  safety,

  /// A form fault to fix.
  correction,

  /// Praise after several good repetitions.
  encouragement,

  /// Something about the setup, e.g. stepping back into view.
  info,
}

/// Something to say (and show) to the athlete.
class Cue {
  const Cue({required this.code, required this.text, required this.kind});

  final String code;
  final String text;
  final CueKind kind;
}

/// Decides when to speak, so the coach helps without nagging.
///
/// - A fault is only mentioned if it showed up in at least two of the last
///   three repetitions (safety faults are mentioned straight away).
/// - The same cue is not repeated within [sameCueCooldown] or [sameCueReps].
/// - Any two cues are at least [minGap] apart, except safety cues.
/// - Only one cue is given at a time: safety first, then the costliest fault.
class CueManager {
  CueManager({
    this.sameCueCooldown = const Duration(seconds: 6),
    this.sameCueReps = 3,
    this.minGap = const Duration(seconds: 2),
    this.window = 3,
    this.goodRepsForPraise = 3,
  });

  static const partialRepCode = 'partial_rep';
  static const poseLostCode = 'pose_lost';
  static const praiseCode = 'praise';

  final Duration sameCueCooldown;
  final int sameCueReps;
  final Duration minGap;

  /// How many recent repetitions are looked at for repeated faults.
  final int window;

  final int goodRepsForPraise;

  final _recentFaults = <Set<String>>[];
  final _lastCued = <String, ({Duration time, int rep})>{};
  Duration? _lastAnyCue;
  int _goodStreak = 0;
  int _repIndex = 0;

  /// Call after each scored repetition. Returns the cue to give, if any.
  Cue? onRep(RepAnalysis analysis, Duration time) {
    _repIndex = analysis.index;
    _recentFaults.add(analysis.faultCodes);
    if (_recentFaults.length > window) _recentFaults.removeAt(0);

    final candidates = [
      for (final fault in analysis.faults)
        if (fault.safety || _repeatedRecently(fault.code)) fault,
    ]..sort(_byImportance);

    for (final fault in candidates) {
      if (_allowed(fault.code, time, safety: fault.safety, byReps: true)) {
        _goodStreak = 0;
        return _give(
          fault.code,
          fault.cue,
          fault.safety ? CueKind.safety : CueKind.correction,
          time,
        );
      }
    }

    if (analysis.faults.isNotEmpty) {
      _goodStreak = 0;
      return null;
    }
    if (analysis.quality == RepQuality.excellent) _goodStreak++;
    if (_goodStreak >= goodRepsForPraise &&
        _allowed(praiseCode, time, safety: false)) {
      _goodStreak = 0;
      return _give(praiseCode, 'Nice form!', CueKind.encouragement, time);
    }
    return null;
  }

  /// Asks to give a cue that is not tied to a completed repetition (for
  /// example while holding a plank). It is given only if the same cue and any
  /// cue at all are not too recent. Safety cues ignore the gap between cues.
  Cue? request(String code, String text, CueKind kind, Duration time) {
    if (!_allowed(code, time, safety: kind == CueKind.safety)) return null;
    return _give(code, text, kind, time);
  }

  /// Call when an attempt went down but did not reach the bottom.
  Cue? onPartialRep(String text, Duration time) {
    final cue = request(partialRepCode, text, CueKind.correction, time);
    if (cue != null) _goodStreak = 0;
    return cue;
  }

  /// Call when the athlete is out of view or too far away.
  Cue? onPoseLost(Duration time) =>
      request(poseLostCode, 'Step back into view', CueKind.info, time);

  /// Forgets everything, e.g. when a new set starts.
  void reset() {
    _recentFaults.clear();
    _lastCued.clear();
    _lastAnyCue = null;
    _goodStreak = 0;
    _repIndex = 0;
  }

  bool _repeatedRecently(String code) =>
      _recentFaults.where((codes) => codes.contains(code)).length >= 2;

  /// Whether [code] may be given now. The repetition gap only applies to
  /// cues about repetitions ([byReps]); a repeated "step back into view" is
  /// limited by time alone.
  bool _allowed(
    String code,
    Duration time, {
    required bool safety,
    bool byReps = false,
  }) {
    final last = _lastCued[code];
    if (last != null) {
      if (time - last.time < sameCueCooldown) return false;
      if (byReps && _repIndex - last.rep < sameCueReps) return false;
    }
    final lastAny = _lastAnyCue;
    if (!safety && lastAny != null && time - lastAny < minGap) return false;
    return true;
  }

  Cue _give(String code, String text, CueKind kind, Duration time) {
    _lastCued[code] = (time: time, rep: _repIndex);
    _lastAnyCue = time;
    return Cue(code: code, text: text, kind: kind);
  }

  /// Safety first, then the fault that cost the most points.
  static int _byImportance(Fault a, Fault b) {
    if (a.safety != b.safety) return a.safety ? -1 : 1;
    return b.deduction.compareTo(a.deduction);
  }
}
