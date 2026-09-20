import 'dart:math' as math;

import 'package:formcoach/features/form_coach/demo/kinematics.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

const _upperArm = 0.14;
const _forearm = 0.14;
const _torso = 0.30;

/// Builds a side-view skeleton of a dip on parallel bars or two chairs.
///
/// The hands stay on the supports. As the elbows bend the shoulders sink and
/// move forward of the hands while the elbows travel back. [torsoLean] tilts the upper body forward from
/// vertical, in degrees. The person faces right unless [facingRight] is false.
Map<Landmark, LandmarkPoint> dipPose({
  required double elbowAngle,
  double torsoLean = 10,
  bool facingRight = true,
  double likelihood = 1,
}) {
  const wrist = Vec2(0.55, 0.45);
  final reach = spanAcrossJoint(_upperArm, _forearm, elbowAngle);

  // The shoulder moves forward of the hands as the arms bend.
  final bend = ((180 - elbowAngle) / 90).clamp(0.0, 1.0);
  final forward = math.min(0.12 * bend, reach * 0.95);
  final shoulder =
      wrist + Vec2(forward, -math.sqrt(reach * reach - forward * forward));
  final elbow = leftIntersection(shoulder, _upperArm, wrist, _forearm);

  final lean = torsoLean * math.pi / 180;
  final hip = shoulder + Vec2(-math.sin(lean), math.cos(lean)) * _torso;
  final knee = hip + const Vec2(0.03, 0.20);
  final ankle = knee + const Vec2(-0.06, 0.20);

  Vec2 face(Vec2 point) => facingRight ? point : Vec2(1 - point.x, point.y);
  LandmarkPoint point(Vec2 position) =>
      LandmarkPoint(face(position), likelihood: likelihood);

  return {
    Landmark.nose: point(shoulder + const Vec2(0.03, -0.07)),
    for (final side in ['left', 'right']) ...{
      Landmark.values.byName('${side}Shoulder'): point(shoulder),
      Landmark.values.byName('${side}Elbow'): point(elbow),
      Landmark.values.byName('${side}Wrist'): point(wrist),
      Landmark.values.byName('${side}Hip'): point(hip),
      Landmark.values.byName('${side}Knee'): point(knee),
      Landmark.values.byName('${side}Ankle'): point(ankle),
      Landmark.values.byName('${side}Heel'): point(ankle + const Vec2(0.02, 0)),
      Landmark.values.byName('${side}FootIndex'): point(
        ankle + const Vec2(-0.04, 0),
      ),
    },
  };
}

/// Describes a set of dips to generate.
class DipMotion {
  const DipMotion({
    this.reps = 3,
    this.topElbow = 170,
    this.bottomElbow = 80,
    this.torsoLean = 10,
    this.down = const Duration(milliseconds: 1500),
    this.up = const Duration(milliseconds: 1500),
    this.rest = const Duration(milliseconds: 800),
    this.facingRight = true,
    this.noise = 0,
  });

  final int reps;
  final double topElbow;
  final double bottomElbow;
  final double torsoLean;
  final Duration down;
  final Duration up;
  final Duration rest;
  final bool facingRight;
  final double noise;
}

/// Generates the camera frames of a set of dips.
List<PoseFrame> dipFrames(
  DipMotion motion, {
  int fps = 30,
  Duration start = Duration.zero,
}) {
  return repetitionFrames(
    (depth) => dipPose(
      elbowAngle:
          motion.topElbow + (motion.bottomElbow - motion.topElbow) * depth,
      torsoLean: motion.torsoLean,
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
