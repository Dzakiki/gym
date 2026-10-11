import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/camera/mlkit_pose_mapping.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

PoseLandmark _point(PoseLandmarkType type, double x, double y, double p) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: p);

void main() {
  group('frameRotation', () {
    test('a portrait phone turns the image by the sensor orientation', () {
      expect(
        frameRotation(
          sensorOrientation: 90,
          frontCamera: false,
          deviceRotation: 0,
        ),
        90,
      );
      expect(
        frameRotation(
          sensorOrientation: 270,
          frontCamera: true,
          deviceRotation: 0,
        ),
        270,
      );
    });

    test(
      'turning the phone turns the back and front cameras opposite ways',
      () {
        expect(
          frameRotation(
            sensorOrientation: 90,
            frontCamera: false,
            deviceRotation: 90,
          ),
          0,
        );
        expect(
          frameRotation(
            sensorOrientation: 270,
            frontCamera: true,
            deviceRotation: 90,
          ),
          0,
        );
        expect(
          frameRotation(
            sensorOrientation: 90,
            frontCamera: false,
            deviceRotation: 270,
          ),
          180,
        );
      },
    );
  });

  test('uprightSize swaps the sides for quarter turns only', () {
    const image = Size(640, 480);
    expect(uprightSize(image, 0), image);
    expect(uprightSize(image, 90), const Size(480, 640));
    expect(uprightSize(image, 180), image);
    expect(uprightSize(image, 270), const Size(480, 640));
  });

  group('poseFrameFromMlKit', () {
    final pose = Pose(
      landmarks: {
        PoseLandmarkType.leftKnee: _point(
          PoseLandmarkType.leftKnee,
          120,
          320,
          0.9,
        ),
        PoseLandmarkType.rightKnee: _point(
          PoseLandmarkType.rightKnee,
          360,
          640,
          0.4,
        ),
        // Not used by the coach.
        PoseLandmarkType.leftEar: _point(PoseLandmarkType.leftEar, 1, 1, 1),
      },
    );
    const size = Size(480, 640);

    test('scales pixels to image-height units', () {
      final frame = poseFrameFromMlKit(
        pose,
        uprightSize: size,
        mirror: false,
        timestamp: const Duration(milliseconds: 40),
      );
      expect(frame.timestamp, const Duration(milliseconds: 40));
      expect(frame.points.keys, {Landmark.leftKnee, Landmark.rightKnee});
      expect(frame.position(Landmark.leftKnee), const Vec2(120 / 640, 0.5));
      expect(frame.position(Landmark.rightKnee), const Vec2(360 / 640, 1));
      expect(frame.points[Landmark.rightKnee]!.likelihood, 0.4);
    });

    test('mirroring flips left and right but keeps the landmark names', () {
      final frame = poseFrameFromMlKit(
        pose,
        uprightSize: size,
        mirror: true,
        timestamp: Duration.zero,
      );
      expect(frame.position(Landmark.leftKnee), const Vec2(360 / 640, 0.5));
      expect(frame.position(Landmark.rightKnee), const Vec2(120 / 640, 1));
    });
  });

  test('every coach landmark has an ML Kit counterpart', () {
    for (final landmark in Landmark.values) {
      expect(
        () => PoseLandmarkType.values.byName(landmark.name),
        returnsNormally,
        reason: landmark.name,
      );
    }
  });
}
