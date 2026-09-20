import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/coach_controller.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/rep_scorer.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';
import 'package:formcoach/features/form_coach/ui/set_summary.dart';
import 'package:formcoach/features/form_coach/ui/skeleton_painter.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/controlled_pose_source.dart';

RepAnalysis _rep(int index, double score, [List<Fault> faults = const []]) {
  return RepAnalysis(
    index: index,
    score: score,
    faults: faults,
    summary: const RepSummary(
      stats: {},
      descent: Duration(seconds: 1),
      ascent: Duration(seconds: 1),
      startedAt: Duration.zero,
      endedAt: Duration(seconds: 2),
    ),
  );
}

Fault _fault(String code, String cue, {double deduction = 10}) =>
    Fault(code: code, cue: cue, severity: 1, weight: deduction, safety: false);

Future<ControlledPoseSource> _openSquatCoach(
  WidgetTester tester,
  ControlledPoseSource source,
) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Coach'),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Squat'));
  await settle(tester);
  return source;
}

Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.text('Start'));
  await settle(tester);
}

Future<void> _feed(
  WidgetTester tester,
  ControlledPoseSource source,
  SquatMotion motion,
) async {
  source.addAll(squatFrames(motion));
  // Stream events are delivered on a timed pump, not on a zero-length one.
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('skeleton painter', () {
    PoseFrame frame(Map<Landmark, LandmarkPoint> points) =>
        PoseFrame(timestamp: Duration.zero, points: points);

    test('draws nothing without a frame', () {
      expect(SkeletonPainter.boneSegments(null, const Size(100, 100)), isEmpty);
    });

    test('scales landmarks by the height of the area', () {
      final segments = SkeletonPainter.boneSegments(
        frame({
          Landmark.leftHip: const LandmarkPoint(Vec2(0.5, 0.5)),
          Landmark.leftKnee: const LandmarkPoint(Vec2(0.5, 0.75)),
        }),
        const Size(400, 200),
      );

      expect(segments, [(const Offset(100, 100), const Offset(100, 150))]);
    });

    test('skips bones with a missing landmark', () {
      final segments = SkeletonPainter.boneSegments(
        frame({
          Landmark.leftHip: const LandmarkPoint(Vec2(0.5, 0.5)),
          Landmark.leftKnee: const LandmarkPoint(Vec2(0.5, 0.75)),
          Landmark.leftAnkle: const LandmarkPoint(Vec2(0.5, 0.9)),
        }),
        const Size(100, 100),
      );

      // Hip-knee and knee-ankle, but nothing that needs an absent landmark.
      expect(segments, hasLength(2));
    });

    test('a full synthetic body gives many bones', () {
      final segments = SkeletonPainter.boneSegments(
        frame(squatPose(kneeAngle: 90, torsoLean: 20, shinLean: 20)),
        const Size(100, 100),
      );

      expect(segments.length, greaterThanOrEqualTo(10));
    });

    test('repaints only when the frame or colours change', () {
      final one = frame(const {});
      const size = Size(10, 10);
      SkeletonPainter painter(PoseFrame? f, {Color bone = Colors.red}) =>
          SkeletonPainter(frame: f, boneColor: bone, jointColor: Colors.white);

      expect(painter(one).shouldRepaint(painter(one)), isFalse);
      expect(painter(one).shouldRepaint(painter(frame(const {}))), isTrue);
      expect(
        painter(one).shouldRepaint(painter(one, bone: Colors.blue)),
        isTrue,
      );
      expect(size.height, 10);
    });
  });

  group('summariseFaults', () {
    test('counts repetitions per fault, most frequent first', () {
      final faults = summariseFaults([
        _rep(1, 80, [_fault('lean', 'Chest up'), _fault('depth', 'Go deeper')]),
        _rep(2, 80, [_fault('lean', 'Chest up')]),
        _rep(3, 100),
      ]);

      expect(faults.map((f) => f.code), ['lean', 'depth']);
      expect(faults.first.count, 2);
      expect(faults.first.cue, 'Chest up');
    });

    test('breaks ties by the points lost', () {
      final faults = summariseFaults([
        _rep(1, 70, [
          _fault('small', 'Small', deduction: 5),
          _fault('big', 'Big', deduction: 25),
        ]),
      ]);

      expect(faults.map((f) => f.code), ['big', 'small']);
    });

    test('is empty when there were no faults', () {
      expect(summariseFaults([_rep(1, 100)]), isEmpty);
    });
  });

  group('coach screens', () {
    /// Runs [body] with a pose source it can push frames into.
    void coachTest(
      String description,
      Future<void> Function(WidgetTester tester, ControlledPoseSource source)
      body,
    ) {
      final source = ControlledPoseSource();
      appTest(description, (tester, db) async {
        addTearDown(source.close);
        await body(tester, source);
      }, overrides: [poseSourceProvider.overrideWithValue(source)]);
    }

    coachTest('the Coach tab lists the supported exercises', (
      tester,
      source,
    ) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Coach'),
        ),
      );
      await settle(tester);

      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Push-up'), findsOneWidget);
      expect(find.text('Film yourself from the side'), findsWidgets);
    });

    coachTest('opens ready to start, in demo mode', (tester, source) async {
      await _openSquatCoach(tester, source);

      expect(find.text('Start'), findsOneWidget);
      expect(find.textContaining('Demo mode'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    coachTest('counts reps live and shows the last score', (
      tester,
      source,
    ) async {
      await _openSquatCoach(tester, source);
      await _start(tester);

      await _feed(tester, source, const SquatMotion(reps: 3));

      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('Rep 3:'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });

    coachTest('shows a cue when the form needs work', (tester, source) async {
      await _openSquatCoach(tester, source);
      await _start(tester);

      await _feed(tester, source, const SquatMotion(bottomKnee: 115));

      expect(find.text('Go deeper'), findsOneWidget);
    });

    coachTest('stopping shows the set summary', (tester, source) async {
      await _openSquatCoach(tester, source);
      await _start(tester);
      await _feed(
        tester,
        source,
        const SquatMotion(reps: 3, torsoLeanAtBottom: 60),
      );

      await tester.tap(find.text('Stop'));
      await settle(tester);

      expect(find.textContaining('3 reps'), findsWidgets);
      expect(find.text('To work on'), findsOneWidget);
      expect(find.textContaining('Chest up: 3 of 3 reps'), findsOneWidget);
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    coachTest('a clean set says there is nothing to fix', (
      tester,
      source,
    ) async {
      await _openSquatCoach(tester, source);
      await _start(tester);
      await _feed(tester, source, const SquatMotion(reps: 3));

      await tester.tap(find.text('Stop'));
      await settle(tester);

      expect(find.text('No form problems found.'), findsOneWidget);
      expect(find.textContaining('Excellent'), findsWidgets);
    });

    coachTest('Again starts a fresh set and Done goes back', (
      tester,
      source,
    ) async {
      await _openSquatCoach(tester, source);
      await _start(tester);
      await _feed(tester, source, const SquatMotion(reps: 2));
      await tester.tap(find.text('Stop'));
      await settle(tester);

      await tester.tap(find.text('Again'));
      await settle(tester);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      await tester.tap(find.text('Stop'));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(
        find.text('Pick an exercise to get live feedback on your form.'),
        findsOneWidget,
      );
    });
  });
}
