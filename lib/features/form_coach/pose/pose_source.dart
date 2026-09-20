import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Something that produces pose frames: the camera, a recording or a demo.
///
/// Frames carry timestamps counted from the start of the set.
abstract interface class PoseSource {
  /// A stream of frames. Listening starts the source, cancelling stops it.
  Stream<PoseFrame> frames();
}

/// Replays prepared frames in real time (optionally faster), for demos and
/// tests when no camera is available.
class ReplayPoseSource implements PoseSource {
  const ReplayPoseSource(this._frames, {this.speed = 1});

  final List<PoseFrame> _frames;

  /// 2 plays twice as fast as real time.
  final double speed;

  @override
  Stream<PoseFrame> frames() async* {
    Duration? previous;
    for (final frame in _frames) {
      if (previous != null) {
        final gap = frame.timestamp - previous;
        await Future<void>.delayed(gap * (1 / speed));
      }
      previous = frame.timestamp;
      yield frame;
    }
  }
}
