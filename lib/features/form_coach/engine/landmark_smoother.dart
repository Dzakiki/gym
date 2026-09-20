import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/one_euro_filter.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Cleans up raw pose detections before they are analysed.
///
/// - Landmarks the detector is unsure about (below [minLikelihood]) are
///   dropped instead of trusted.
/// - Each coordinate is smoothed with a [OneEuroFilter].
/// - A landmark that was missing for longer than [maxGap] starts fresh, so an
///   old position never drags the new one.
class LandmarkSmoother {
  LandmarkSmoother({
    this.minLikelihood = 0.5,
    this.maxGap = const Duration(milliseconds: 500),
  });

  final double minLikelihood;
  final Duration maxGap;

  final _filters = <Landmark, _PointFilter>{};
  final _lastSeen = <Landmark, Duration>{};

  /// Returns [frame] with unreliable landmarks removed and the rest smoothed.
  PoseFrame smooth(PoseFrame frame) {
    final seconds =
        frame.timestamp.inMicroseconds / Duration.microsecondsPerSecond;
    final smoothed = <Landmark, LandmarkPoint>{};

    for (final MapEntry(key: landmark, value: point) in frame.points.entries) {
      if (point.likelihood < minLikelihood) continue;

      final filter = _filters.putIfAbsent(landmark, _PointFilter.new);
      final lastSeen = _lastSeen[landmark];
      if (lastSeen != null && frame.timestamp - lastSeen > maxGap) {
        filter.reset();
      }
      _lastSeen[landmark] = frame.timestamp;

      smoothed[landmark] = LandmarkPoint(
        Vec2(
          filter.x.filter(point.position.x, seconds),
          filter.y.filter(point.position.y, seconds),
        ),
        likelihood: point.likelihood,
      );
    }
    return PoseFrame(timestamp: frame.timestamp, points: smoothed);
  }

  /// Forgets all history, e.g. when a new set starts.
  void reset() {
    _filters.clear();
    _lastSeen.clear();
  }
}

class _PointFilter {
  final x = OneEuroFilter();
  final y = OneEuroFilter();

  void reset() {
    x.reset();
    y.reset();
  }
}
