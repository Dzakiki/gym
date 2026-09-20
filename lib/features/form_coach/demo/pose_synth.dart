import 'dart:math' as math;

import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

const _degToRad = math.pi / 180;

/// Segment lengths of the synthetic body, in image-height units.
const _shin = 0.22;
const _thigh = 0.22;
const _torso = 0.30;

/// Builds a side-view skeleton from joint angles.
///
/// The ankle is fixed to the floor. [kneeAngle] is the angle between shin and
/// thigh (180 is straight), [shinLean] is how far the shin tilts forward from
/// vertical and [torsoLean] how far the torso tilts forward from vertical. The
/// person faces right unless [facingRight] is false. [heelLift] raises the
/// heel off the floor (image-height units). Both body sides get the
/// same landmarks.
Map<Landmark, LandmarkPoint> squatPose({
  required double kneeAngle,
  required double torsoLean,
  required double shinLean,
  double heelLift = 0,
  bool facingRight = true,
  double likelihood = 1,
}) {
  final direction = facingRight ? 1.0 : -1.0;
  const ankle = Vec2(0.5, 0.9);
  final toe = Vec2(ankle.x + 0.08 * direction, ankle.y);
  final heel = Vec2(ankle.x - 0.03 * direction, ankle.y + 0.01 - heelLift);

  final shinRad = shinLean * _degToRad;
  final knee = Vec2(
    ankle.x + direction * _shin * math.sin(shinRad),
    ankle.y - _shin * math.cos(shinRad),
  );

  // Direction from the knee to the ankle, rotated by the knee angle either
  // way; the hip is the option that ends up behind the knee.
  final toAnkle = Vec2(-direction * math.sin(shinRad), math.cos(shinRad));
  final kneeRad = kneeAngle * _degToRad;
  Vec2 rotate(double angle) => Vec2(
    toAnkle.x * math.cos(angle) - toAnkle.y * math.sin(angle),
    toAnkle.x * math.sin(angle) + toAnkle.y * math.cos(angle),
  );
  final options = [rotate(kneeRad), rotate(-kneeRad)];
  final thighDirection = options.reduce(
    (a, b) => a.x * direction < b.x * direction ? a : b,
  );
  final hip = knee + thighDirection * _thigh;

  final torsoRad = torsoLean * _degToRad;
  final shoulder =
      hip + Vec2(direction * math.sin(torsoRad), -math.cos(torsoRad)) * _torso;

  LandmarkPoint point(Vec2 position) =>
      LandmarkPoint(position, likelihood: likelihood);
  return {
    for (final side in ['left', 'right']) ...{
      _landmark(side, 'Shoulder'): point(shoulder),
      _landmark(side, 'Hip'): point(hip),
      _landmark(side, 'Knee'): point(knee),
      _landmark(side, 'Ankle'): point(ankle),
      _landmark(side, 'Heel'): point(heel),
      _landmark(side, 'FootIndex'): point(toe),
    },
  };
}

Landmark _landmark(String side, String part) =>
    Landmark.values.byName('$side$part');

/// Describes a set of squats to generate.
class SquatMotion {
  const SquatMotion({
    this.reps = 3,
    this.topKnee = 172,
    this.bottomKnee = 70,
    this.torsoLeanAtBottom = 25,
    this.shinLeanAtBottom = 25,
    this.heelLiftAtBottom = 0,
    this.down = const Duration(milliseconds: 1500),
    this.up = const Duration(milliseconds: 1500),
    this.rest = const Duration(milliseconds: 800),
    this.facingRight = true,
    this.noise = 0,
  });

  final int reps;
  final double topKnee;
  final double bottomKnee;
  final double torsoLeanAtBottom;
  final double shinLeanAtBottom;

  /// How far the heel is lifted off the floor at the bottom.
  final double heelLiftAtBottom;

  /// Time going down and coming up.
  final Duration down;
  final Duration up;

  /// Time standing still before the first rep and after each rep.
  final Duration rest;
  final bool facingRight;

  /// Amplitude of repeatable jitter added to every coordinate.
  final double noise;
}

/// Builds the skeleton for a movement [depth]: 0 at the start position, 1 at
/// the bottom (or the top of a pull), with values in between while moving.
typedef PoseBuilder = Map<Landmark, LandmarkPoint> Function(double depth);

/// Generates the camera frames of a set of repetitions at [fps] frames per
/// second: a rest, then [reps] times a move to depth 1 and back, each followed
/// by a rest. Movement is eased so speed is zero at both ends.
List<PoseFrame> repetitionFrames(
  PoseBuilder poseAt, {
  required int reps,
  required Duration down,
  required Duration up,
  required Duration rest,
  double noise = 0,
  int fps = 30,
  Duration start = Duration.zero,
}) {
  final frames = <PoseFrame>[];
  var time = Duration.zero;
  final step = Duration(microseconds: Duration.microsecondsPerSecond ~/ fps);

  void add(double depth) {
    final points = poseAt(depth);
    frames.add(
      PoseFrame(
        timestamp: start + time,
        points: noise == 0 ? points : _jitter(points, frames.length, noise),
      ),
    );
    time += step;
  }

  void hold(Duration length) {
    for (var elapsed = Duration.zero; elapsed < length; elapsed += step) {
      add(0);
    }
  }

  void move(Duration length, {required bool downwards}) {
    final frameCount = math.max(
      1,
      length.inMicroseconds ~/ step.inMicroseconds,
    );
    for (var i = 1; i <= frameCount; i++) {
      final progress = i / frameCount;
      final eased = 0.5 - 0.5 * math.cos(progress * math.pi);
      add(downwards ? eased : 1 - eased);
    }
  }

  hold(rest);
  for (var rep = 0; rep < reps; rep++) {
    move(down, downwards: true);
    move(up, downwards: false);
    hold(rest);
  }
  return frames;
}

/// Generates the camera frames of a set of squats at [fps] frames per second.
List<PoseFrame> squatFrames(
  SquatMotion motion, {
  int fps = 30,
  Duration start = Duration.zero,
}) {
  return repetitionFrames(
    (depth) => squatPose(
      kneeAngle: motion.topKnee + (motion.bottomKnee - motion.topKnee) * depth,
      torsoLean: 5 + (motion.torsoLeanAtBottom - 5) * depth,
      shinLean: 5 + (motion.shinLeanAtBottom - 5) * depth,
      heelLift: motion.heelLiftAtBottom * depth,
      facingRight: motion.facingRight,
    ),
    reps: motion.reps,
    down: motion.down,
    up: motion.up,
    rest: motion.rest,
    noise: motion.noise,
    fps: fps,
    start: start,
  );
}

Map<Landmark, LandmarkPoint> _jitter(
  Map<Landmark, LandmarkPoint> points,
  int frameIndex,
  double amplitude,
) {
  return {
    for (final MapEntry(key: landmark, value: point) in points.entries)
      landmark: LandmarkPoint(
        Vec2(
          point.position.x +
              math.sin(frameIndex * 12.9898 + landmark.index) * amplitude,
          point.position.y +
              math.sin(frameIndex * 78.233 + landmark.index) * amplitude,
        ),
        likelihood: point.likelihood,
      ),
  };
}
