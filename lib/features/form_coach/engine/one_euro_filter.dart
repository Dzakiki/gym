import 'dart:math' as math;

/// A One Euro filter: smooths a noisy signal with little lag.
///
/// It removes jitter while the value is nearly still, and follows quickly
/// when it moves fast. Raise [minCutoff] for less lag at rest, raise [beta]
/// for less lag during fast movement. The defaults are tuned for coordinates
/// in image-height units and should be adjusted with real recordings.
class OneEuroFilter {
  OneEuroFilter({
    this.minCutoff = 1.5,
    this.beta = 8,
    this.derivativeCutoff = 1,
  });

  final double minCutoff;
  final double beta;
  final double derivativeCutoff;

  double? _value;
  double _derivative = 0;
  double? _lastSeconds;

  /// Filters [value] measured at [seconds]. Time must not go backwards.
  double filter(double value, double seconds) {
    final previous = _value;
    final lastSeconds = _lastSeconds;
    if (previous == null || lastSeconds == null || seconds <= lastSeconds) {
      _value = value;
      _lastSeconds = seconds;
      return value;
    }

    final elapsed = seconds - lastSeconds;
    final rawDerivative = (value - previous) / elapsed;
    _derivative +=
        _alpha(derivativeCutoff, elapsed) * (rawDerivative - _derivative);

    final cutoff = minCutoff + beta * _derivative.abs();
    final smoothed = previous + _alpha(cutoff, elapsed) * (value - previous);
    _value = smoothed;
    _lastSeconds = seconds;
    return smoothed;
  }

  /// Forgets the history, so the next value passes through unchanged.
  void reset() {
    _value = null;
    _derivative = 0;
    _lastSeconds = null;
  }

  static double _alpha(double cutoff, double elapsed) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / elapsed);
  }
}
