import 'dart:math' as math;

import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

const _centerX = 0.5;
const _shoulderY = 0.35;
const _hipY = 0.62;
const _ankleY = 0.92;
const _shoulderWidth = 0.16;
const _armLength = 0.28;

/// Builds a front-view skeleton of a jumping jack.
///
/// [openness] runs from 0 (standing with arms by the sides and feet together)
/// to 1 (arms overhead and feet wide apart). [armsOverhead] is how far the
/// arms are raised at full openness, in degrees from hanging down (about 165
/// is straight up). [feetSpread] is the ankle distance at full openness in
/// shoulder widths. [asymmetry] lowers the second arm by that many degrees.
Map<Landmark, LandmarkPoint> jumpingJackPose({
  required double openness,
  double armsOverhead = 165,
  double feetSpread = 2.3,
  double asymmetry = 0,
  double likelihood = 1,
}) {
  final spread = 0.9 + (feetSpread - 0.9) * openness;
  final halfFeet = spread * _shoulderWidth / 2;

  Vec2 wristFor(double side, double armAngle) {
    final angle = armAngle * math.pi / 180;
    final shoulderX = _centerX + side * _shoulderWidth / 2;
    return Vec2(
      shoulderX + side * _armLength * math.sin(angle),
      _shoulderY + _armLength * math.cos(angle),
    );
  }

  final armAngle = 15 + (armsOverhead - 15) * openness;
  LandmarkPoint point(Vec2 position) =>
      LandmarkPoint(position, likelihood: likelihood);
  Vec2 shoulder(double side) =>
      Vec2(_centerX + side * _shoulderWidth / 2, _shoulderY);
  Vec2 elbow(double side, double angle) =>
      shoulder(side) + (wristFor(side, angle) - shoulder(side)) * 0.5;

  final leftAngle = armAngle;
  final rightAngle = armAngle - asymmetry * openness;
  return {
    Landmark.nose: point(const Vec2(_centerX, _shoulderY - 0.08)),
    Landmark.leftShoulder: point(shoulder(-1)),
    Landmark.rightShoulder: point(shoulder(1)),
    Landmark.leftElbow: point(elbow(-1, leftAngle)),
    Landmark.rightElbow: point(elbow(1, rightAngle)),
    Landmark.leftWrist: point(wristFor(-1, leftAngle)),
    Landmark.rightWrist: point(wristFor(1, rightAngle)),
    Landmark.leftHip: point(const Vec2(_centerX - 0.05, _hipY)),
    Landmark.rightHip: point(const Vec2(_centerX + 0.05, _hipY)),
    Landmark.leftKnee: point(Vec2(_centerX - halfFeet * 0.55, 0.77)),
    Landmark.rightKnee: point(Vec2(_centerX + halfFeet * 0.55, 0.77)),
    Landmark.leftAnkle: point(Vec2(_centerX - halfFeet, _ankleY)),
    Landmark.rightAnkle: point(Vec2(_centerX + halfFeet, _ankleY)),
    Landmark.leftHeel: point(Vec2(_centerX - halfFeet, _ankleY + 0.01)),
    Landmark.rightHeel: point(Vec2(_centerX + halfFeet, _ankleY + 0.01)),
    Landmark.leftFootIndex: point(Vec2(_centerX - halfFeet, _ankleY + 0.02)),
    Landmark.rightFootIndex: point(Vec2(_centerX + halfFeet, _ankleY + 0.02)),
  };
}

/// Describes a set of jumping jacks to generate.
class JumpingJackMotion {
  const JumpingJackMotion({
    this.reps = 6,
    this.armsOverhead = 165,
    this.feetSpread = 2.3,
    this.asymmetry = 0,
    this.open = const Duration(milliseconds: 450),
    this.close = const Duration(milliseconds: 450),
    this.rest = const Duration(milliseconds: 300),
    this.noise = 0,
  });

  final int reps;
  final double armsOverhead;
  final double feetSpread;
  final double asymmetry;

  /// Time to open (arms up, feet out) and to close again.
  final Duration open;
  final Duration close;
  final Duration rest;
  final double noise;
}

/// Generates the camera frames of a set of jumping jacks.
List<PoseFrame> jumpingJackFrames(
  JumpingJackMotion motion, {
  int fps = 30,
  Duration start = Duration.zero,
}) {
  return repetitionFrames(
    (depth) => jumpingJackPose(
      openness: depth,
      armsOverhead: motion.armsOverhead,
      feetSpread: motion.feetSpread,
      asymmetry: motion.asymmetry,
    ),
    reps: motion.reps,
    down: motion.open,
    up: motion.close,
    rest: motion.rest,
    noise: motion.noise,
    fps: fps,
    start: start,
  );
}
