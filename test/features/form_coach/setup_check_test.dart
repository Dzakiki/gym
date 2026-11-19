import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/demo/dip_synth.dart';
import 'package:formcoach/features/form_coach/demo/jumping_jack_synth.dart';
import 'package:formcoach/features/form_coach/demo/lunge_synth.dart';
import 'package:formcoach/features/form_coach/demo/plank_synth.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/demo/pullup_synth.dart';
import 'package:formcoach/features/form_coach/demo/pushup_synth.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/setup_check.dart';
import 'package:formcoach/features/form_coach/exercises/jumping_jack.dart';
import 'package:formcoach/features/form_coach/exercises/plank.dart';
import 'package:formcoach/features/form_coach/exercises/registry.dart';
import 'package:formcoach/features/form_coach/exercises/squat.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

Map<Landmark, LandmarkPoint> _standing({double likelihood = 1}) => squatPose(
  kneeAngle: 172,
  torsoLean: 5,
  shinLean: 3,
  likelihood: likelihood,
);

PoseFrame _frame(
  int milliseconds,
  Map<Landmark, LandmarkPoint> points, {
  double? width,
}) => PoseFrame(
  timestamp: Duration(milliseconds: milliseconds),
  points: points,
  width: width,
);

/// Moves and scales [points] about the ankle at (0.5, 0.9), to put the
/// person nearer or farther away.
Map<Landmark, LandmarkPoint> _scaled(
  Map<Landmark, LandmarkPoint> points,
  double factor,
) => {
  for (final MapEntry(key: landmark, value: point) in points.entries)
    landmark: LandmarkPoint(
      const Vec2(0.5, 0.95) + (point.position - const Vec2(0.5, 0.95)) * factor,
      likelihood: point.likelihood,
    ),
};

/// Feeds the same pose every 33 ms for [milliseconds] and returns the last
/// status.
SetupStatus _hold(
  SetupCheck check,
  Map<Landmark, LandmarkPoint> points, {
  int from = 0,
  required int milliseconds,
  double? width,
}) {
  late SetupStatus status;
  for (var t = from; t <= from + milliseconds; t += 33) {
    status = check.update(_frame(t, points, width: width));
  }
  return status;
}

void main() {
  group('problemIn', () {
    final check = SetupCheck(definition: squat);

    test('a well-placed side-on squatter passes', () {
      expect(check.problemIn(_frame(0, _standing())), isNull);
    });

    test('an empty frame means nobody is in view', () {
      expect(check.problemIn(_frame(0, const {})), SetupProblem.noPerson);
    });

    test('unreliable landmarks do not count as a person', () {
      expect(
        check.problemIn(_frame(0, _standing(likelihood: 0.4))),
        SetupProblem.noPerson,
      );
    });

    test('missing feet means the body is not in the frame', () {
      final points = Map.of(_standing())
        ..removeWhere(
          (landmark, _) =>
              landmark.name.contains('Ankle') ||
              landmark.name.contains('Heel') ||
              landmark.name.contains('Foot'),
        );
      expect(check.problemIn(_frame(0, points)), SetupProblem.notInFrame);
    });

    test('a small body is too far away', () {
      expect(
        check.problemIn(_frame(0, _scaled(_standing(), 0.5))),
        SetupProblem.tooFar,
      );
    });

    test('a body filling the picture is too close', () {
      expect(
        check.problemIn(_frame(0, _scaled(_standing(), 1.25))),
        SetupProblem.tooClose,
      );
    });

    test('a side-view exercise filmed from the front asks to turn', () {
      expect(
        check.problemIn(_frame(0, jumpingJackPose(openness: 0))),
        SetupProblem.turnSideOn,
      );
    });

    test('a front-view exercise filmed side-on asks to face the camera', () {
      final jacks = SetupCheck(definition: jumpingJack);
      expect(jacks.problemIn(_frame(0, jumpingJackPose(openness: 0))), isNull);
      // A side-on body: both shoulders and both hips in the same place.
      final sideOn = {
        ...jumpingJackPose(openness: 0),
        Landmark.rightShoulder: jumpingJackPose(
          openness: 0,
        )[Landmark.leftShoulder]!,
        Landmark.rightHip: jumpingJackPose(openness: 0)[Landmark.leftHip]!,
      };
      expect(jacks.problemIn(_frame(0, sideOn)), SetupProblem.faceCamera);
    });

    test('a half-hidden far shoulder skips the facing check', () {
      final points = {
        ..._standing(),
        Landmark.rightShoulder: const LandmarkPoint(
          Vec2(0.9, 0.2),
          likelihood: 0.1,
        ),
      };
      expect(check.problemIn(_frame(0, points)), isNull);
    });

    test('a plank lying across the picture is judged by its width', () {
      final planks = SetupCheck(definition: plank);
      // Only 16% of the height, but most of a square picture's width.
      expect(planks.problemIn(_frame(0, plankPose(), width: 1)), isNull);
      // Lying across a wide landscape picture, it is too small.
      expect(
        planks.problemIn(_frame(0, plankPose(), width: 1.8)),
        SetupProblem.tooFar,
      );
    });
  });

  group('update', () {
    test('becomes ready after holding still for the steady time', () {
      final check = SetupCheck(definition: squat);
      final early = _hold(check, _standing(), milliseconds: 500);
      expect(early.ready, isFalse);
      expect(early.problem, isNull);
      expect(early.progress, closeTo(0.5, 0.05));

      final later = _hold(check, _standing(), from: 533, milliseconds: 500);
      expect(later.ready, isTrue);
      expect(later.progress, 1);
    });

    test('a problem restarts the steady time', () {
      final check = SetupCheck(definition: squat);
      _hold(check, _standing(), milliseconds: 800);
      check.update(_frame(833, const {}));
      final after = _hold(check, _standing(), from: 866, milliseconds: 500);
      expect(after.ready, isFalse);
    });

    test('a problem is reported only once it has lasted a while', () {
      final check = SetupCheck(definition: squat);
      final far = _scaled(_standing(), 0.5);
      expect(check.update(_frame(0, far)).problem, isNull);
      expect(check.update(_frame(300, far)).problem, isNull);
      expect(check.update(_frame(500, far)).problem, SetupProblem.tooFar);
    });

    test('a brief new problem keeps the previous hint', () {
      final check = SetupCheck(definition: squat);
      final far = _scaled(_standing(), 0.5);
      _hold(check, far, milliseconds: 600);
      final blip = check.update(_frame(633, const {}));
      expect(blip.problem, SetupProblem.tooFar);
    });

    test('stays ready once ready, until reset', () {
      final check = SetupCheck(definition: squat);
      _hold(check, _standing(), milliseconds: 1100);
      expect(check.update(_frame(1200, const {})).ready, isTrue);
      check.reset();
      expect(check.update(_frame(1300, const {})).ready, isFalse);
    });
  });

  test('every coached exercise passes from its starting position', () {
    // Square pictures, as the synthetic poses are drawn in.
    final starts = <String, PoseFrame>{
      'squat': squatFrames(const SquatMotion()).first,
      'pushup': pushupFrames(const PushupMotion()).first,
      'plank': plankFrames(length: const Duration(seconds: 1)).first,
      'dip': dipFrames(const DipMotion()).first,
      'pullup': pullupFrames(const PullupMotion()).first,
      'lunge': lungeFrames(const LungeMotion()).first,
      'jumping_jack': jumpingJackFrames(const JumpingJackMotion()).first,
    };
    expect(starts.keys, unorderedEquals(coachExercises.keys));
    for (final MapEntry(key: key, value: start) in starts.entries) {
      final ExerciseDefinition definition = coachExercises[key]!;
      final frame = _frame(0, start.points, width: 1);
      expect(
        SetupCheck(definition: definition).problemIn(frame),
        isNull,
        reason: key,
      );
    }
  });

  test('the instruction names the view the exercise needs', () {
    expect(setupInstruction(squat.view), contains('side-on'));
    expect(setupInstruction(jumpingJack.view), contains('face it'));
  });
}
