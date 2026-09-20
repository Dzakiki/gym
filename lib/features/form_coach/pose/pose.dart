import 'package:formcoach/features/form_coach/engine/geometry.dart';

/// The body landmarks the coach uses (a subset of the 33 that pose detection
/// provides).
enum Landmark {
  nose,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// Where one landmark was found and how sure the detector is (0 to 1).
class LandmarkPoint {
  const LandmarkPoint(this.position, {this.likelihood = 1});

  final Vec2 position;
  final double likelihood;
}

/// All landmarks found in one camera frame.
class PoseFrame {
  const PoseFrame({required this.timestamp, required this.points});

  /// Time since the start of the set.
  final Duration timestamp;
  final Map<Landmark, LandmarkPoint> points;

  /// Where [landmark] is, or null if it was not found.
  Vec2? position(Landmark landmark) => points[landmark]?.position;

  /// True if [landmark] was found with at least [minLikelihood] confidence.
  bool isVisible(Landmark landmark, {double minLikelihood = 0.5}) {
    final point = points[landmark];
    return point != null && point.likelihood >= minLikelihood;
  }
}
