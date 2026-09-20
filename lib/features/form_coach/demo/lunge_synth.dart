import 'dart:math' as math;

import 'package:formcoach/features/form_coach/demo/kinematics.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

const _thigh = 0.22;
const _shin = 0.22;
const _torso = 0.30;
const _floorY = 0.90;
const _frontFootX = 0.55;

/// Builds a side-view skeleton of a lunge (a split squat: the feet stay put).
///
/// [frontKneeAngle] is the angle at the front knee (180 is straight). The hips
/// sit midway between the feet, so bending the front knee lowers them and
/// bends the back knee too. [stepLength] is the distance between the feet as
/// a fraction of the image height, [torsoLean] tilts the torso forward in
/// degrees. [toeLength] is how far the toes stick out past the ankle; a
/// small value makes it easy for the knee to end up past the toes. The front
/// leg is the person's [frontIsLeft] leg, and they face right unless
/// [facingRight] is false.
Map<Landmark, LandmarkPoint> lungePose({
  required double frontKneeAngle,
  double stepLength = 0.25,
  double torsoLean = 8,
  double toeLength = 0.07,
  bool frontIsLeft = true,
  bool facingRight = true,
  double likelihood = 1,
}) {
  const frontAnkle = Vec2(_frontFootX, _floorY);
  final backAnkle = Vec2(_frontFootX - stepLength, _floorY);
  final hipX = (frontAnkle.x + backAnkle.x) / 2;

  // Hip height from the front leg: distance hip to ankle for this knee angle.
  final reach = spanAcrossJoint(_thigh, _shin, frontKneeAngle);
  final across = frontAnkle.x - hipX;
  final hip = Vec2(
    hipX,
    _floorY - math.sqrt(math.max(0, reach * reach - across * across)),
  );

  // The front knee points forward, the back knee points down.
  final frontKnee = circleIntersections(
    hip,
    _thigh,
    frontAnkle,
    _shin,
  ).reduce((p, q) => p.x > q.x ? p : q);
  final backKnee = circleIntersections(
    hip,
    _thigh,
    backAnkle,
    _shin,
  ).reduce((p, q) => p.y > q.y ? p : q);

  final lean = torsoLean * math.pi / 180;
  final shoulder = hip + Vec2(math.sin(lean), -math.cos(lean)) * _torso;

  Vec2 face(Vec2 point) => facingRight ? point : Vec2(1 - point.x, point.y);
  LandmarkPoint point(Vec2 position) =>
      LandmarkPoint(face(position), likelihood: likelihood);

  final left = frontIsLeft
      ? (knee: frontKnee, ankle: frontAnkle)
      : (knee: backKnee, ankle: backAnkle);
  final right = frontIsLeft
      ? (knee: backKnee, ankle: backAnkle)
      : (knee: frontKnee, ankle: frontAnkle);

  return {
    Landmark.nose: point(shoulder + const Vec2(0.03, -0.08)),
    Landmark.leftShoulder: point(shoulder),
    Landmark.rightShoulder: point(shoulder),
    Landmark.leftElbow: point(shoulder + const Vec2(0.02, 0.12)),
    Landmark.rightElbow: point(shoulder + const Vec2(0.02, 0.12)),
    Landmark.leftWrist: point(shoulder + const Vec2(0.04, 0.24)),
    Landmark.rightWrist: point(shoulder + const Vec2(0.04, 0.24)),
    Landmark.leftHip: point(hip),
    Landmark.rightHip: point(hip),
    Landmark.leftKnee: point(left.knee),
    Landmark.rightKnee: point(right.knee),
    Landmark.leftAnkle: point(left.ankle),
    Landmark.rightAnkle: point(right.ankle),
    Landmark.leftHeel: point(left.ankle + const Vec2(-0.02, 0)),
    Landmark.rightHeel: point(right.ankle + const Vec2(-0.02, 0)),
    Landmark.leftFootIndex: point(left.ankle + Vec2(toeLength, 0)),
    Landmark.rightFootIndex: point(right.ankle + Vec2(toeLength, 0)),
  };
}

/// Describes a set of lunges to generate.
class LungeMotion {
  const LungeMotion({
    this.reps = 3,
    this.topKnee = 170,
    this.bottomKnee = 90,
    this.stepLength = 0.25,
    this.torsoLeanAtBottom = 8,
    this.toeLength = 0.07,
    this.down = const Duration(milliseconds: 1500),
    this.up = const Duration(milliseconds: 1500),
    this.rest = const Duration(milliseconds: 800),
    this.frontIsLeft = true,
    this.facingRight = true,
    this.noise = 0,
  });

  final int reps;
  final double topKnee;
  final double bottomKnee;
  final double stepLength;
  final double torsoLeanAtBottom;
  final double toeLength;
  final Duration down;
  final Duration up;
  final Duration rest;
  final bool frontIsLeft;
  final bool facingRight;
  final double noise;
}

/// Generates the camera frames of a set of lunges.
List<PoseFrame> lungeFrames(
  LungeMotion motion, {
  int fps = 30,
  Duration start = Duration.zero,
}) {
  return repetitionFrames(
    (depth) => lungePose(
      frontKneeAngle:
          motion.topKnee + (motion.bottomKnee - motion.topKnee) * depth,
      stepLength: motion.stepLength,
      torsoLean: 5 + (motion.torsoLeanAtBottom - 5) * depth,
      toeLength: motion.toeLength,
      frontIsLeft: motion.frontIsLeft,
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
