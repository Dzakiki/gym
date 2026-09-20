import 'dart:math' as math;

import 'package:formcoach/features/form_coach/demo/kinematics.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

const _upperArm = 0.14;
const _forearm = 0.14;
const _torso = 0.22;
const _thigh = 0.16;
const _shin = 0.16;

/// Builds a side-view skeleton of a person on a pull-up bar.
///
/// The hands stay on the bar. As the elbows bend the shoulders rise towards
/// it. [swing] tilts the whole lower body forward from hanging straight down,
/// in degrees (a kipping swing). The person faces right unless [facingRight]
/// is false.
Map<Landmark, LandmarkPoint> pullupPose({
  required double elbowAngle,
  double swing = 0,
  bool facingRight = true,
  double likelihood = 1,
}) {
  const wrist = Vec2(0.5, 0.10); // the bar
  final reach = spanAcrossJoint(_upperArm, _forearm, elbowAngle);

  const forward = 0.02;
  final shoulder =
      wrist + Vec2(forward, math.sqrt(reach * reach - forward * forward));
  final elbow = leftIntersection(shoulder, _upperArm, wrist, _forearm);

  final tilt = swing * math.pi / 180;
  final down = Vec2(math.sin(tilt), math.cos(tilt));
  final hip = shoulder + down * _torso;
  final knee = hip + down * _thigh;
  final ankle = knee + down * _shin;

  Vec2 face(Vec2 point) => facingRight ? point : Vec2(1 - point.x, point.y);
  LandmarkPoint point(Vec2 position) =>
      LandmarkPoint(face(position), likelihood: likelihood);

  return {
    Landmark.nose: point(shoulder + const Vec2(0.02, -0.09)),
    for (final side in ['left', 'right']) ...{
      Landmark.values.byName('${side}Shoulder'): point(shoulder),
      Landmark.values.byName('${side}Elbow'): point(elbow),
      Landmark.values.byName('${side}Wrist'): point(wrist),
      Landmark.values.byName('${side}Hip'): point(hip),
      Landmark.values.byName('${side}Knee'): point(knee),
      Landmark.values.byName('${side}Ankle'): point(ankle),
      Landmark.values.byName('${side}Heel'): point(ankle + const Vec2(0.02, 0)),
      Landmark.values.byName('${side}FootIndex'): point(
        ankle + const Vec2(0.05, 0),
      ),
    },
  };
}

/// Describes a set of pull-ups to generate.
class PullupMotion {
  const PullupMotion({
    this.reps = 3,
    this.hangElbow = 170,
    this.topElbow = 35,
    this.swingAtTop = 0,
    this.pull = const Duration(milliseconds: 1500),
    this.lower = const Duration(milliseconds: 1500),
    this.rest = const Duration(milliseconds: 800),
    this.facingRight = true,
    this.noise = 0,
  });

  final int reps;

  /// Elbow angle when hanging with straight arms.
  final double hangElbow;

  /// Elbow angle at the top of the pull. Around 35 puts the chin over the bar.
  final double topElbow;

  /// Forward tilt of the legs at the top of the pull, in degrees.
  final double swingAtTop;

  /// Time pulling up and lowering down.
  final Duration pull;
  final Duration lower;
  final Duration rest;
  final bool facingRight;
  final double noise;
}

/// Generates the camera frames of a set of pull-ups.
List<PoseFrame> pullupFrames(
  PullupMotion motion, {
  int fps = 30,
  Duration start = Duration.zero,
}) {
  return repetitionFrames(
    (depth) => pullupPose(
      elbowAngle:
          motion.hangElbow + (motion.topElbow - motion.hangElbow) * depth,
      swing: motion.swingAtTop * depth,
      facingRight: motion.facingRight,
    ),
    reps: motion.reps,
    down: motion.pull,
    up: motion.lower,
    rest: motion.rest,
    noise: motion.noise,
    fps: fps,
    start: start,
  );
}
