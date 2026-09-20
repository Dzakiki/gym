import 'dart:math' as math;

import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Segment lengths of the synthetic push-up body, in image-height units.
const _upperArm = 0.14;
const _forearm = 0.14;
const _bodyLength = 0.58; // ankle to shoulder
const _handsFromFeet = 0.51;

/// Builds a side-view push-up skeleton.
///
/// The feet and hands stay on the floor. [elbowAngle] is the angle at the
/// elbow (180 is straight). The shoulder is wherever the fixed body length
/// and the arm length allow. [hipOffset] moves the hips off the straight
/// line from shoulders to ankles, as a fraction of the body length: positive
/// is up (piked), negative is down (sagging).
Map<Landmark, LandmarkPoint> pushupPose({
  required double elbowAngle,
  double hipOffset = 0,
  bool facingRight = true,
  double likelihood = 1,
}) {
  const ankle = Vec2(0.12, 0.80);
  const wrist = Vec2(0.12 + _handsFromFeet, 0.80);

  // Distance from wrist to shoulder for this elbow angle (law of cosines).
  final elbowRad = elbowAngle * math.pi / 180;
  final reach = math.sqrt(
    _upperArm * _upperArm +
        _forearm * _forearm -
        2 * _upperArm * _forearm * math.cos(elbowRad),
  );
  final shoulder = _upperIntersection(ankle, _bodyLength, wrist, reach);

  // The elbow points back towards the feet.
  final elbow = _backIntersection(shoulder, _upperArm, wrist, _forearm);

  final along = (shoulder - ankle) * (1 / (shoulder - ankle).length);
  final up = Vec2(along.y, -along.x);
  Vec2 onBody(double fraction, [double lift = 0]) =>
      ankle + (shoulder - ankle) * fraction + up * (lift * _bodyLength);

  final hip = onBody(0.55, hipOffset);
  final knee = onBody(0.28, hipOffset * 0.5);
  final nose = shoulder + along * 0.08;
  final toe = ankle + const Vec2(-0.04, 0);
  final heel = ankle + const Vec2(0.02, 0);

  Vec2 face(Vec2 point) => facingRight ? point : Vec2(1 - point.x, point.y);
  LandmarkPoint point(Vec2 position) =>
      LandmarkPoint(face(position), likelihood: likelihood);

  return {
    Landmark.nose: point(nose),
    for (final side in ['left', 'right']) ...{
      Landmark.values.byName('${side}Shoulder'): point(shoulder),
      Landmark.values.byName('${side}Elbow'): point(elbow),
      Landmark.values.byName('${side}Wrist'): point(wrist),
      Landmark.values.byName('${side}Hip'): point(hip),
      Landmark.values.byName('${side}Knee'): point(knee),
      Landmark.values.byName('${side}Ankle'): point(ankle),
      Landmark.values.byName('${side}Heel'): point(heel),
      Landmark.values.byName('${side}FootIndex'): point(toe),
    },
  };
}

/// The point [rA] from [a] and [rB] from [b] that lies above the line a-b.
Vec2 _upperIntersection(Vec2 a, double rA, Vec2 b, double rB) {
  final candidates = _circleIntersections(a, rA, b, rB);
  return candidates.reduce((p, q) => p.y < q.y ? p : q);
}

/// The point [rA] from [a] and [rB] from [b] that lies closer to the feet.
Vec2 _backIntersection(Vec2 a, double rA, Vec2 b, double rB) {
  final candidates = _circleIntersections(a, rA, b, rB);
  return candidates.reduce((p, q) => p.x < q.x ? p : q);
}

List<Vec2> _circleIntersections(Vec2 a, double rA, Vec2 b, double rB) {
  final between = b - a;
  final distance = between.length;
  final alongA = (rA * rA - rB * rB + distance * distance) / (2 * distance);
  final height = math.sqrt(math.max(0, rA * rA - alongA * alongA));
  final direction = between * (1 / distance);
  final middle = a + direction * alongA;
  final side = Vec2(-direction.y, direction.x) * height;
  return [middle + side, middle - side];
}

/// Describes a set of push-ups to generate.
class PushupMotion {
  const PushupMotion({
    this.reps = 3,
    this.topElbow = 170,
    this.bottomElbow = 75,
    this.hipOffset = 0,
    this.down = const Duration(milliseconds: 1500),
    this.up = const Duration(milliseconds: 1500),
    this.rest = const Duration(milliseconds: 800),
    this.facingRight = true,
    this.noise = 0,
  });

  final int reps;
  final double topElbow;
  final double bottomElbow;

  /// Hips off the shoulder-ankle line, as a fraction of the body length.
  final double hipOffset;
  final Duration down;
  final Duration up;
  final Duration rest;
  final bool facingRight;
  final double noise;
}

/// Generates the camera frames of a set of push-ups.
List<PoseFrame> pushupFrames(
  PushupMotion motion, {
  int fps = 30,
  Duration start = Duration.zero,
}) {
  return repetitionFrames(
    (depth) => pushupPose(
      elbowAngle:
          motion.topElbow + (motion.bottomElbow - motion.topElbow) * depth,
      hipOffset: motion.hipOffset,
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
