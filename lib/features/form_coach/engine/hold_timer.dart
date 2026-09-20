/// Measures how long a position (such as a plank) is held with good form.
///
/// Time only counts as held while [update] is told the form is valid.
/// Long gaps between updates (for example when the person left the frame)
/// are not counted either way.
class HoldTimer {
  HoldTimer({this.maxStep = const Duration(milliseconds: 500)});

  /// The longest gap between two updates that still counts as continuous.
  final Duration maxStep;

  Duration? _lastTime;
  Duration _held = Duration.zero;
  Duration _broken = Duration.zero;

  /// Time spent holding with valid form.
  Duration get held => _held;

  /// Time spent in the position with invalid form.
  Duration get brokenForm => _broken;

  /// Records whether the form was [valid] at [time].
  void update({required bool valid, required Duration time}) {
    final last = _lastTime;
    _lastTime = time;
    if (last == null) return;

    final step = time - last;
    if (step <= Duration.zero || step > maxStep) return;
    if (valid) {
      _held += step;
    } else {
      _broken += step;
    }
  }

  void reset() {
    _lastTime = null;
    _held = Duration.zero;
    _broken = Duration.zero;
  }
}
