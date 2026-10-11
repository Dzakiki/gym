import 'dart:ui' show Size;

import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// How many degrees clockwise a camera image must be turned so the person in
/// it stands upright, as ML Kit expects it.
///
/// [deviceRotation] is how far the phone is turned from portrait (0, 90, 180
/// or 270 degrees). The front camera is mirrored, so its sensor turns the
/// other way.
int frameRotation({
  required int sensorOrientation,
  required bool frontCamera,
  required int deviceRotation,
}) => frontCamera
    ? (sensorOrientation + deviceRotation) % 360
    : (sensorOrientation - deviceRotation + 360) % 360;

/// The size of a camera image of [imageSize] after it is turned upright by
/// [rotation] degrees.
Size uprightSize(Size imageSize, int rotation) =>
    rotation == 90 || rotation == 270 ? imageSize.flipped : imageSize;

/// Converts what ML Kit found into the coach's [PoseFrame].
///
/// ML Kit gives pixel positions in the upright image of [uprightSize]. The
/// coach wants image-height units. With [mirror] (front camera) the picture
/// is flipped left to right, the way the camera preview shows it.
PoseFrame poseFrameFromMlKit(
  Pose pose, {
  required Size uprightSize,
  required bool mirror,
  required Duration timestamp,
}) {
  final height = uprightSize.height;
  final width = uprightSize.width;
  return PoseFrame(
    timestamp: timestamp,
    points: {
      for (final landmark in Landmark.values)
        if (pose.landmarks[_mlKitTypes[landmark]] case final point?)
          landmark: LandmarkPoint(
            Vec2(
              (mirror ? width - point.x : point.x) / height,
              point.y / height,
            ),
            likelihood: point.likelihood,
          ),
    },
  );
}

/// The coach's landmarks use the same names as ML Kit's.
final Map<Landmark, PoseLandmarkType> _mlKitTypes = {
  for (final landmark in Landmark.values)
    landmark: PoseLandmarkType.values.byName(landmark.name),
};
