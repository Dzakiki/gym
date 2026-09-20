import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/coach_controller.dart';
import 'package:formcoach/features/form_coach/cue_player.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';
import 'package:formcoach/features/form_coach/pose/pose_source.dart';

import '../../helpers/controlled_pose_source.dart';

class _RecordingPlayer implements CuePlayer {
  final spoken = <String>[];
  var stopped = 0;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopped++;
}

void main() {
  late ControlledPoseSource source;
  late _RecordingPlayer player;
  late ProviderContainer container;

  CoachController controller() =>
      container.read(coachControllerProvider('squat').notifier);
  CoachState state() => container.read(coachControllerProvider('squat'));

  setUp(() {
    source = ControlledPoseSource();
    player = _RecordingPlayer();
    container = ProviderContainer(
      overrides: [
        poseSourceProvider.overrideWithValue(source),
        cuePlayerProvider.overrideWithValue(player),
      ],
    );
    // Keep the auto-disposing provider alive for the test.
    container.listen(coachControllerProvider('squat'), (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await source.close();
  });

  Future<void> feed(List<PoseFrame> frames) async {
    for (final frame in frames) {
      source.controller.add(frame);
    }
    await pumpEventQueue();
  }

  test('starts ready with nothing recorded', () {
    expect(state().status, CoachStatus.ready);
    expect(state().repCount, 0);
    expect(state().latest, isNull);
    expect(state().setScore, isNull);
  });

  test('counts and scores repetitions while running', () async {
    controller().start();
    await feed(squatFrames(const SquatMotion(reps: 3)));

    expect(state().status, CoachStatus.running);
    expect(state().repCount, 3);
    expect(state().lastRep?.index, 3);
    expect(state().setScore, greaterThan(90));
    expect(state().latest?.tracking, isTrue);
  });

  test('stopping keeps the results and ignores later frames', () async {
    controller().start();
    await feed(squatFrames(const SquatMotion(reps: 2)));

    controller().stop();
    await feed(squatFrames(const SquatMotion()));

    expect(state().status, CoachStatus.finished);
    expect(state().repCount, 2);
    expect(player.stopped, 1);
  });

  test('the set ends when the source ends', () async {
    controller().start();
    await feed(squatFrames(const SquatMotion(reps: 1)));

    await source.controller.close();
    await pumpEventQueue();

    expect(state().status, CoachStatus.finished);
    expect(state().repCount, 1);
  });

  test('starting again while running does nothing', () async {
    controller().start();
    await feed(squatFrames(const SquatMotion(reps: 1)));

    controller().start();

    expect(state().status, CoachStatus.running);
    expect(state().repCount, 1);
  });

  test('a new set after a finished one starts from zero', () async {
    controller().start();
    await feed(squatFrames(const SquatMotion(reps: 2)));
    controller().stop();

    controller().start();

    expect(state().status, CoachStatus.running);
    expect(state().repCount, 0);
    expect(state().latest, isNull);
  });

  test('an exercise without a coach cannot be started', () {
    final unknown = container.read(coachControllerProvider('bench').notifier);

    expect(unknown.start, throwsStateError);
  });

  test('cues are shown, spoken, then cleared after a moment', () {
    fakeAsync((async) {
      controller().start();
      for (final frame in squatFrames(const SquatMotion(bottomKnee: 115))) {
        source.controller.add(frame);
      }
      async.flushMicrotasks();

      expect(state().cue?.text, 'Go deeper');
      expect(player.spoken, isNotEmpty);
      expect(player.spoken.first, 'Go deeper');

      async.elapse(CoachController.cueDisplayTime + const Duration(seconds: 1));
      expect(state().cue, isNull);
    });
  });

  test('frames after the container is disposed are ignored', () async {
    controller().start();
    container.dispose();

    source.controller.add(squatFrames(const SquatMotion(reps: 1)).first);

    await pumpEventQueue();
  });

  group('ReplayPoseSource', () {
    List<PoseFrame> frames() => [
      for (final ms in [0, 100, 300])
        PoseFrame(
          timestamp: Duration(milliseconds: ms),
          points: const {},
        ),
    ];

    test('delivers frames with their original spacing', () {
      fakeAsync((async) {
        final arrivals = <int>[];
        ReplayPoseSource(frames())
            .frames()
            .listen((_) => arrivals.add(async.elapsed.inMilliseconds));

        async.elapse(const Duration(seconds: 1));

        expect(arrivals, [0, 100, 300]);
      });
    });

    test('can play faster than real time', () {
      fakeAsync((async) {
        final arrivals = <int>[];
        ReplayPoseSource(
          frames(),
          speed: 2,
        ).frames().listen((_) => arrivals.add(async.elapsed.inMilliseconds));

        async.elapse(const Duration(seconds: 1));

        expect(arrivals, [0, 50, 150]);
      });
    });
  });
}
