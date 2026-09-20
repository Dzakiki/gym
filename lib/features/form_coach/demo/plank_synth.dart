import 'dart:math' as math;

import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

const _bodyLength = 0.58; // ankle to shoulder
const _shoulderHeight = 0.16; // shoulders above the floor

/// Builds a side-view forearm plank skeleton.
///
/// [hipOffset] moves the hips off the straight shoulder-ankle line as a
/// fraction of the body length (positive up, negative down). [shoulderShift]
/// moves the elbows behind (positive) or in front of (negative) the shoulders
/// by that fraction of the body length.
Map<Landmark, LandmarkPoint> plankPose({
  double hipOffset = 0,
  double shoulderShift = 0,
  bool facingRight = true,
  double likelihood = 1,
}) {
  const ankle = Vec2(0.12, 0.80);
  final shoulder = Vec2(
    ankle.x +
        math.sqrt(
          _bodyLength * _bodyLength - _shoulderHeight * _shoulderHeight,
        ),
    ankle.y - _shoulderHeight,
  );
  final elbow = Vec2(shoulder.x - shoulderShift * _bodyLength, ankle.y);
  final wrist = elbow + const Vec2(0.13, 0);

  final along = (shoulder - ankle) * (1 / (shoulder - ankle).length);
  final up = Vec2(along.y, -along.x);
  Vec2 onBody(double fraction, [double lift = 0]) =>
      ankle + (shoulder - ankle) * fraction + up * (lift * _bodyLength);

  Vec2 face(Vec2 point) => facingRight ? point : Vec2(1 - point.x, point.y);
  LandmarkPoint point(Vec2 position) =>
      LandmarkPoint(face(position), likelihood: likelihood);

  final hip = onBody(0.55, hipOffset);
  final knee = onBody(0.28, hipOffset * 0.5);
  return {
    Landmark.nose: point(shoulder + along * 0.08),
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

/// A stretch of a plank where the form is off.
class PlankDeviation {
  const PlankDeviation({
    required this.from,
    required this.to,
    this.hipOffset = 0,
    this.shoulderShift = 0,
  });

  final Duration from;
  final Duration to;
  final double hipOffset;
  final double shoulderShift;

  bool covers(Duration time) => time >= from && time < to;
}

/// Generates the camera frames of a plank held for [length], with stretches
/// of bad form given by [deviations].
List<PoseFrame> plankFrames({
  required Duration length,
  List<PlankDeviation> deviations = const [],
  bool facingRight = true,
  int fps = 30,
  Duration start = Duration.zero,
}) {
  final step = Duration(microseconds: Duration.microsecondsPerSecond ~/ fps);
  final frames = <PoseFrame>[];
  for (var time = Duration.zero; time < length; time += step) {
    final active = deviations.where((d) => d.covers(time)).toList();
    frames.add(
      PoseFrame(
        timestamp: start + time,
        points: plankPose(
          hipOffset: active.fold(0, (sum, d) => sum + d.hipOffset),
          shoulderShift: active.fold(0, (sum, d) => sum + d.shoulderShift),
          facingRight: facingRight,
        ),
      ),
    );
  }
  return frames;
}
