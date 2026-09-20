import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/demo/plank_synth.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/coach_session.dart';
import 'package:formcoach/features/form_coach/exercises/plank.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

Duration _s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

/// Feeds [frames] to a fresh plank session and returns everything it said.
({CoachSession session, List<CoachUpdate> updates}) _run(
  List<PoseFrame> frames,
) {
  final session = CoachSession(definition: plank);
  final updates = [for (final frame in frames) session.update(frame)];
  return (session: session, updates: updates);
}

List<String> _cueTexts(List<CoachUpdate> updates) => [
  for (final u in updates)
    if (u.cue != null) u.cue!.text,
];

void main() {
  group('measurePlank', () {
    PoseFrame frame({
      double hipOffset = 0,
      double shoulderShift = 0,
      bool facingRight = true,
    }) => PoseFrame(
      timestamp: Duration.zero,
      points: plankPose(
        hipOffset: hipOffset,
        shoulderShift: shoulderShift,
        facingRight: facingRight,
      ),
    );

    test(
      'a straight plank has the hips on the line and shoulders over elbows',
      () {
        final metrics = measurePlank(frame(), BodySide.left)!;

        expect(metrics[PlankMetric.hipHeight], closeTo(0, 1e-6));
        expect(metrics[PlankMetric.shoulderOffset], closeTo(0, 1e-6));
      },
    );

    test('sagging hips are negative and piked hips positive', () {
      final sag = measurePlank(frame(hipOffset: -0.1), BodySide.left)!;
      final pike = measurePlank(frame(hipOffset: 0.2), BodySide.left)!;

      expect(sag[PlankMetric.hipHeight], closeTo(-0.1, 1e-6));
      expect(pike[PlankMetric.hipHeight], closeTo(0.2, 1e-6));
    });

    test('measures how far the shoulders are from the elbows', () {
      final metrics = measurePlank(frame(shoulderShift: 0.25), BodySide.left)!;

      expect(metrics[PlankMetric.shoulderOffset], closeTo(0.25, 1e-6));
    });

    test('gives the same numbers whichever way the person faces', () {
      final right = measurePlank(frame(hipOffset: -0.1), BodySide.left)!;
      final left = measurePlank(
        frame(hipOffset: -0.1, facingRight: false),
        BodySide.left,
      )!;

      for (final metric in right.keys) {
        expect(left[metric], closeTo(right[metric]!, 1e-9), reason: metric);
      }
    });

    test('returns null when a needed landmark is missing', () {
      final points = plankPose()..remove(Landmark.leftElbow);

      expect(
        measurePlank(
          PoseFrame(timestamp: Duration.zero, points: points),
          BodySide.left,
        ),
        isNull,
      );
    });
  });

  group('coaching a plank', () {
    test('is a hold exercise without repetitions', () {
      expect(plank.isHold, isTrue);
      final run = _run(plankFrames(length: _s(5)));

      expect(run.session.repCount, 0);
      expect(run.session.reps, isEmpty);
    });

    test('a clean plank counts all the time and scores 100', () {
      final run = _run(plankFrames(length: _s(20)));

      expect(run.session.holdTime.inMilliseconds, closeTo(20000, 100));
      expect(run.session.holdScore, 100);
      expect(run.session.setScore, 100);
      expect(run.updates.every((u) => u.formValid ?? false), isTrue);
    });

    test('the coach encourages every 15 seconds and otherwise stays quiet', () {
      final run = _run(plankFrames(length: _s(35)));

      expect(_cueTexts(run.updates), [
        '15 seconds, keep going',
        '30 seconds, keep going',
      ]);
    });

    test('the live hold time grows as the plank goes on', () {
      final run = _run(plankFrames(length: _s(10)));

      final times = [for (final u in run.updates) u.holdTime!];
      expect(times.first, Duration.zero);
      expect(times.last.inSeconds, greaterThanOrEqualTo(9));
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThanOrEqualTo(times[i - 1]));
      }
    });

    test('sagging hips stop the clock and are mentioned after a moment', () {
      final run = _run(
        plankFrames(
          length: _s(20),
          deviations: [
            PlankDeviation(from: _s(5), to: _s(10), hipOffset: -0.12),
          ],
        ),
      );

      expect(_cueTexts(run.updates), contains('Hips up'));
      expect(run.session.holdTime.inMilliseconds, closeTo(15000, 300));
      expect(run.session.holdScore!, closeTo(75, 2));
      final cue = run.updates.firstWhere((u) => u.cue?.text == 'Hips up');
      // Not instantly: the sag must last about a second first.
      expect(cue.holdTime!.inMilliseconds, closeTo(5000, 300));
      expect(cue.formValid, isFalse);
    });

    test('a brief wobble costs time but is not mentioned', () {
      final run = _run(
        plankFrames(
          length: _s(10),
          deviations: [
            PlankDeviation(from: _s(4), to: _s(4.5), hipOffset: -0.12),
          ],
        ),
      );

      expect(_cueTexts(run.updates), isNot(contains('Hips up')));
      expect(run.session.holdTime.inMilliseconds, closeTo(9500, 200));
    });

    test('piked hips are mentioned', () {
      final run = _run(
        plankFrames(
          length: _s(10),
          deviations: [PlankDeviation(from: _s(2), to: _s(8), hipOffset: 0.2)],
        ),
      );

      expect(_cueTexts(run.updates), contains('Lower your hips'));
      expect(run.session.holdScore!, lessThan(80));
    });

    test('shoulders not over the elbows are mentioned', () {
      final run = _run(
        plankFrames(
          length: _s(10),
          deviations: [
            PlankDeviation(from: _s(2), to: _s(8), shoulderShift: 0.3),
          ],
        ),
      );

      expect(_cueTexts(run.updates), contains('Shoulders over elbows'));
    });

    test('a problem that is not fixed is not repeated every second', () {
      final run = _run(
        plankFrames(
          length: _s(20),
          deviations: [
            PlankDeviation(from: _s(2), to: _s(20), hipOffset: -0.12),
          ],
        ),
      );

      final repeats = _cueTexts(run.updates).where((t) => t == 'Hips up');
      // A 6 second cooldown: about one cue every 6 seconds, never every second.
      expect(repeats.length, inInclusiveRange(2, 4));
    });

    test('works the same when facing left', () {
      final run = _run(plankFrames(length: _s(10), facingRight: false));

      expect(run.session.holdTime.inMilliseconds, closeTo(10000, 100));
      expect(run.session.holdScore, 100);
    });

    test('time out of view is not counted as held', () {
      final first = plankFrames(length: _s(5));
      final gap = [
        for (var i = 0; i < 90; i++)
          PoseFrame(
            timestamp:
                first.last.timestamp + Duration(milliseconds: 33 * (i + 1)),
            points: const {},
          ),
      ];
      final second = plankFrames(
        length: _s(5),
        start: gap.last.timestamp + const Duration(milliseconds: 33),
      );

      final run = _run([...first, ...gap, ...second]);

      expect(run.session.holdTime.inMilliseconds, closeTo(10000, 400));
      expect(_cueTexts(run.updates), contains('Step back into view'));
    });

    test('reset clears the hold', () {
      final run = _run(plankFrames(length: _s(5)));

      run.session.reset();

      expect(run.session.holdTime, Duration.zero);
      expect(run.session.holdScore, isNull);
    });
  });
}
