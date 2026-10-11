/// How the camera pipeline is keeping up, shown on the camera test screen.
class FrameStats {
  const FrameStats({
    this.analyzedFps = 0,
    this.droppedFps = 0,
    this.detectionTime = Duration.zero,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.rotation = 0,
  });

  /// Frames per second that went through pose detection.
  final double analyzedFps;

  /// Frames per second skipped because detection was still busy.
  final double droppedFps;

  /// How long the last pose detection took.
  final Duration detectionTime;

  /// The size of the camera image, before it is turned upright.
  final int imageWidth;
  final int imageHeight;

  /// Degrees the image is turned for detection.
  final int rotation;
}

/// Counts events over a sliding window to give a rate per second.
class RateMeter {
  RateMeter({this.window = const Duration(seconds: 1)});

  final Duration window;
  final List<Duration> _times = [];

  /// Records an event at [time] (any steadily increasing clock).
  void add(Duration time) {
    _times.add(time);
    _drop(time);
  }

  /// Events per second in the window ending at [now].
  double rate(Duration now) {
    _drop(now);
    return _times.length /
        (window.inMicroseconds / Duration.microsecondsPerSecond);
  }

  void _drop(Duration now) {
    final start = now - window;
    _times.removeWhere((t) => t <= start);
  }
}
