import 'dart:math' as math;

import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

/// What is stopping a coached set from starting.
enum SetupProblem {
  /// Nobody is seen.
  noPerson('Step into view'),

  /// Someone is seen, but not every body part the exercise needs.
  notInFrame('Show your whole body'),

  /// The body takes up too little of the picture.
  tooFar('Come closer'),

  /// The body takes up too much of the picture, so it would leave it while
  /// moving.
  tooClose('Step back'),

  /// A side-view exercise is filmed from the front.
  turnSideOn('Turn side-on to the camera'),

  /// A front-view exercise is filmed from the side.
  faceCamera('Face the camera');

  const SetupProblem(this.hint);

  /// What to tell the athlete.
  final String hint;
}

/// Limits used by the setup check. They are starting values to be tuned with
/// real recordings.
abstract final class SetupLimits {
  /// Body parts count as seen from this likelihood on.
  static const minLikelihood = 0.6;

  /// Fewer reliably seen landmarks than this means nobody is in view.
  static const minLandmarksForPerson = 3;

  /// The body must take up at least this share of the picture's height (or,
  /// lying down, of its width)...
  static const minBodyShare = 0.5;

  /// ...and at most this share.
  static const maxBodyShare = 0.9;

  /// Shoulder width over torso length above this means the athlete faces the
  /// camera; side-view exercises need less.
  static const maxSideOnShoulderRatio = 0.55;

  /// Shoulder width over torso length below this means the athlete is
  /// side-on; front-view exercises need more.
  static const minFrontOnShoulderRatio = 0.35;

  /// Landmarks used for the facing check may be less certain than this: in a
  /// side view the far shoulder is half hidden.
  static const minLikelihoodForFacing = 0.3;
}

/// The result of checking one frame.
class SetupStatus {
  const SetupStatus({
    required this.problem,
    required this.progress,
    required this.ready,
  });

  /// What to fix, once it has lasted long enough to be worth saying. Null
  /// while everything is right, and before anything has been decided.
  final SetupProblem? problem;

  /// How far through the steady time the athlete is, from 0 to 1.
  final double progress;

  /// True once everything has been right for long enough: the set can start.
  final bool ready;
}

/// Checks, frame by frame, that the athlete is placed so the coach can see
/// them: the whole body in view, at a good distance and facing the right
/// way. The set starts once all of that has held for [steadyFor].
class SetupCheck {
  SetupCheck({
    required this.definition,
    this.steadyFor = const Duration(seconds: 1),
    this.reportAfter = const Duration(milliseconds: 500),
  });

  final ExerciseDefinition definition;

  /// How long everything must be right before the set starts.
  final Duration steadyFor;

  /// How long a problem must last before it is reported, so detection
  /// jitter does not make the hint flicker.
  final Duration reportAfter;

  SetupProblem? _candidate;
  Duration? _candidateSince;
  SetupProblem? _reported;
  Duration? _rightSince;
  bool _ready = false;

  /// Checks one frame. Once ready, stays ready until [reset].
  SetupStatus update(PoseFrame frame) {
    if (_ready) {
      return const SetupStatus(problem: null, progress: 1, ready: true);
    }
    final time = frame.timestamp;
    final problem = problemIn(frame);

    if (problem != _candidate || _candidateSince == null) {
      _candidate = problem;
      _candidateSince = time;
    }
    if (time - _candidateSince! >= reportAfter || problem == null) {
      _reported = problem;
    }

    if (problem != null) {
      _rightSince = null;
      return SetupStatus(problem: _reported, progress: 0, ready: false);
    }
    final since = _rightSince ??= time;
    final steady = time - since;
    _ready = steady >= steadyFor;
    final progress = steadyFor == Duration.zero
        ? 1.0
        : math.min(1, steady.inMicroseconds / steadyFor.inMicroseconds);
    return SetupStatus(
      problem: null,
      progress: progress.toDouble(),
      ready: _ready,
    );
  }

  void reset() {
    _candidate = null;
    _candidateSince = null;
    _reported = null;
    _rightSince = null;
    _ready = false;
  }

  /// What is wrong in [frame] alone, or null if nothing is.
  SetupProblem? problemIn(PoseFrame frame) {
    final reliable = PoseFrame(
      timestamp: frame.timestamp,
      width: frame.width,
      points: {
        for (final MapEntry(key: landmark, value: point)
            in frame.points.entries)
          if (point.likelihood >= SetupLimits.minLikelihood) landmark: point,
      },
    );
    if (reliable.points.length < SetupLimits.minLandmarksForPerson) {
      return SetupProblem.noPerson;
    }
    // Facing first: a wrong angle can also hide the body parts the
    // exercise measures, and turning is the fix then.
    final ratio = shoulderRatio(frame);
    if (ratio != null) {
      switch (definition.view) {
        case CameraView.side when ratio > SetupLimits.maxSideOnShoulderRatio:
          return SetupProblem.turnSideOn;
        case CameraView.front when ratio < SetupLimits.minFrontOnShoulderRatio:
          return SetupProblem.faceCamera;
        case CameraView.side || CameraView.front:
          break;
      }
    }
    final measurable = BodySide.values.any(
      (side) => definition.measure(reliable, side) != null,
    );
    if (!measurable) return SetupProblem.notInFrame;

    final share = bodyShare(reliable);
    if (share < SetupLimits.minBodyShare) return SetupProblem.tooFar;
    if (share > SetupLimits.maxBodyShare) return SetupProblem.tooClose;

    return null;
  }

  /// How much of the picture the body fills: its height over the picture's
  /// height, or its width over the picture's width when that is larger (as
  /// for a plank). Without a known picture width only the height counts.
  static double bodyShare(PoseFrame frame) {
    final positions = frame.points.values.map((p) => p.position);
    if (positions.isEmpty) return 0;
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final p in positions) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final heightShare = maxY - minY;
    final width = frame.width;
    if (width == null || width <= 0) return heightShare;
    return math.max(heightShare, (maxX - minX) / width);
  }

  /// Shoulder width over torso length (shoulder midpoint to hip midpoint):
  /// small when the athlete is side-on, large when they face the camera.
  /// Null if the shoulders or hips are not seen well enough.
  static double? shoulderRatio(PoseFrame frame) {
    Vec2? seen(Landmark landmark) =>
        frame.isVisible(
          landmark,
          minLikelihood: SetupLimits.minLikelihoodForFacing,
        )
        ? frame.position(landmark)
        : null;
    final leftShoulder = seen(Landmark.leftShoulder);
    final rightShoulder = seen(Landmark.rightShoulder);
    final leftHip = seen(Landmark.leftHip);
    final rightHip = seen(Landmark.rightHip);
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return null;
    }
    final torso = leftShoulder
        .midpointTo(rightShoulder)
        .distanceTo(leftHip.midpointTo(rightHip));
    if (torso == 0) return null;
    return leftShoulder.distanceTo(rightShoulder) / torso;
  }
}

/// What to tell the athlete before a set, by the view the exercise needs.
String setupInstruction(CameraView view) => switch (view) {
  CameraView.side =>
    'Prop the phone up 2 to 3 m away and stand side-on to it, '
        'with your whole body in view.',
  CameraView.front =>
    'Prop the phone up 2 to 3 m away and face it, '
        'with your whole body in view.',
};
