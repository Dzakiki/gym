import 'package:flutter/material.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Pairs of landmarks joined by a line to draw the body.
final List<(Landmark, Landmark)> skeletonBones = [
  for (final side in BodySide.values) ...[
    (side.shoulder, side.elbow),
    (side.elbow, side.wrist),
    (side.shoulder, side.hip),
    (side.hip, side.knee),
    (side.knee, side.ankle),
    (side.ankle, side.heel),
    (side.ankle, side.toe),
    (side.heel, side.toe),
  ],
  (Landmark.leftShoulder, Landmark.rightShoulder),
  (Landmark.leftHip, Landmark.rightHip),
];

/// Draws the detected body as lines and joints.
///
/// Landmark coordinates are in image-height units, so the picture is scaled
/// by the height of the area it is drawn in. Give the painter an area with
/// the same aspect ratio as the camera image.
class SkeletonPainter extends CustomPainter {
  const SkeletonPainter({
    required this.frame,
    required this.boneColor,
    required this.jointColor,
  });

  final PoseFrame? frame;
  final Color boneColor;
  final Color jointColor;

  /// The lines to draw for [frame] inside an area of [size]. A bone is only
  /// included when both of its landmarks were found.
  static List<(Offset, Offset)> boneSegments(PoseFrame? frame, Size size) {
    if (frame == null) return const [];
    Offset? place(Landmark landmark) {
      final position = frame.position(landmark);
      return position == null
          ? null
          : Offset(position.x * size.height, position.y * size.height);
    }

    return [
      for (final (from, to) in skeletonBones)
        if (place(from) case final start?)
          if (place(to) case final end?) (start, end),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final segments = boneSegments(frame, size);
    if (segments.isEmpty) return;

    final bonePaint = Paint()
      ..color = boneColor
      ..strokeWidth = size.height * 0.012
      ..strokeCap = StrokeCap.round;
    final jointPaint = Paint()..color = jointColor;
    final jointRadius = size.height * 0.011;

    for (final (start, end) in segments) {
      canvas.drawLine(start, end, bonePaint);
    }
    for (final (start, end) in segments) {
      canvas.drawCircle(start, jointRadius, jointPaint);
      canvas.drawCircle(end, jointRadius, jointPaint);
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.boneColor != boneColor ||
      oldDelegate.jointColor != jointColor;
}
