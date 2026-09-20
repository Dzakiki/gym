import 'package:formcoach/features/form_coach/pose/pose.dart';

/// Which camera angle an exercise needs.
enum CameraView {
  /// The camera sees the person from the side (squat, push-up, lunge, plank).
  side,

  /// The camera sees the person from the front (jumping jack).
  front,
}

/// The left or right half of the body, for side-view exercises where only the
/// side facing the camera is measured.
enum BodySide {
  left(
    shoulder: Landmark.leftShoulder,
    elbow: Landmark.leftElbow,
    wrist: Landmark.leftWrist,
    hip: Landmark.leftHip,
    knee: Landmark.leftKnee,
    ankle: Landmark.leftAnkle,
    heel: Landmark.leftHeel,
    toe: Landmark.leftFootIndex,
  ),
  right(
    shoulder: Landmark.rightShoulder,
    elbow: Landmark.rightElbow,
    wrist: Landmark.rightWrist,
    hip: Landmark.rightHip,
    knee: Landmark.rightKnee,
    ankle: Landmark.rightAnkle,
    heel: Landmark.rightHeel,
    toe: Landmark.rightFootIndex,
  );

  const BodySide({
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.hip,
    required this.knee,
    required this.ankle,
    required this.heel,
    required this.toe,
  });

  final Landmark shoulder;
  final Landmark elbow;
  final Landmark wrist;
  final Landmark hip;
  final Landmark knee;
  final Landmark ankle;
  final Landmark heel;
  final Landmark toe;

  /// How well this side is seen in [frame]: the sum of the likelihoods of the
  /// main landmarks (missing ones count as 0).
  double visibility(PoseFrame frame) {
    var total = 0.0;
    for (final landmark in [shoulder, hip, knee, ankle]) {
      total += frame.points[landmark]?.likelihood ?? 0;
    }
    return total;
  }
}
