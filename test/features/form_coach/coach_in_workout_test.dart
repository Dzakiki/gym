import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/features/form_coach/coach_controller.dart';
import 'package:formcoach/features/form_coach/demo/plank_synth.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/controlled_pose_source.dart';

void coachInWorkoutTest(
  String description,
  Future<void> Function(
    WidgetTester tester,
    AppDatabase db,
    ControlledPoseSource source,
  )
  body,
) {
  final source = ControlledPoseSource();
  appTest(description, (tester, db) async {
    addTearDown(source.close);
    await body(tester, db, source);
  }, overrides: [poseSourceProvider.overrideWithValue(source)]);
}

Future<void> _startHomeBodyweight(WidgetTester tester) async {
  await openWorkoutsTab(tester);
  await tester.tap(find.text('Home bodyweight'));
  await settle(tester);
  await tester.tap(find.text('Start workout'));
  await settle(tester);
}

Future<void> _coachFirstExercise(
  WidgetTester tester,
  ControlledPoseSource source,
  SquatMotion motion,
) async {
  await tester.tap(find.text('Start with AI Coach').first);
  await settle(tester);
  await tester.tap(find.text('Start'));
  await settle(tester);
  source.addAll(squatFrames(motion));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(find.text('Stop'));
  await settle(tester);
}

void main() {
  coachInWorkoutTest('coach-supported exercises offer the coach', (
    tester,
    db,
    source,
  ) async {
    await _startHomeBodyweight(tester);

    expect(find.text('Start with AI Coach'), findsWidgets);
  });

  coachInWorkoutTest('a coached set can be saved into the workout', (
    tester,
    db,
    source,
  ) async {
    await _startHomeBodyweight(tester);
    await _coachFirstExercise(tester, source, const SquatMotion(reps: 3));

    expect(find.text('Save to workout'), findsOneWidget);
    await tester.tap(find.text('Save to workout'));
    await settle(tester);

    expect(find.text('Saved to your workout'), findsOneWidget);
    expect(find.text('Squat'), findsWidgets); // back in the workout
    final sets = (await tester.runAsync(() => db.select(db.setLogs).get()))!;
    final coached = sets.where((s) => s.coached).single;
    expect(coached.reps, 3);
    expect(coached.completedAt, isNotNull);
    final analyses = (await tester.runAsync(
      () => db.select(db.coachAnalyses).get(),
    ))!;
    expect(analyses.single.setLogId, coached.id);
    expect(analyses.single.repsCounted, 3);
    expect(analyses.single.setScore, greaterThan(90));
  });

  coachInWorkoutTest('the coached set shows as done and can be finished', (
    tester,
    db,
    source,
  ) async {
    await _startHomeBodyweight(tester);
    await _coachFirstExercise(tester, source, const SquatMotion(reps: 2));
    await tester.tap(find.text('Save to workout'));
    await settle(tester);

    expect(find.byTooltip('Set 1 done, tap to undo'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await settle(tester);
    expect(find.text('Workout complete'), findsOneWidget);
  });

  coachInWorkoutTest('the coach score appears in the history', (
    tester,
    db,
    source,
  ) async {
    await _startHomeBodyweight(tester);
    await _coachFirstExercise(tester, source, const SquatMotion(reps: 2));
    await tester.tap(find.text('Save to workout'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Progress'),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Home bodyweight'));
    await settle(tester);

    expect(find.textContaining('AI Coach'), findsOneWidget);
    expect(find.textContaining('2 reps'), findsWidgets);
  });

  coachInWorkoutTest('a coached plank saves the time held', (
    tester,
    db,
    source,
  ) async {
    await _startHomeBodyweight(tester);
    // Plank is the last exercise of the template.
    await tester.scrollUntilVisible(
      find.text('Start with AI Coach').last,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start with AI Coach').last);
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    source.addAll(plankFrames(length: const Duration(seconds: 12)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Stop'));
    await settle(tester);

    await tester.tap(find.text('Save to workout'));
    await settle(tester);

    final sets = (await tester.runAsync(() => db.select(db.setLogs).get()))!;
    final coached = sets.where((s) => s.coached).single;
    expect(coached.durationSeconds, closeTo(12, 1));
    expect(coached.reps, isNull);
  });

  coachInWorkoutTest('a standalone coach set has nothing to save into', (
    tester,
    db,
    source,
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
    await tester.tap(find.text('Start'));
    await settle(tester);
    source.addAll(squatFrames(const SquatMotion(reps: 2)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Stop'));
    await settle(tester);

    expect(find.text('Save to workout'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });

  coachInWorkoutTest('with no set left to coach the user is told', (
    tester,
    db,
    source,
  ) async {
    await openWorkoutsTab(tester);
    await tester.tap(find.text('Start empty workout'));
    await settle(tester);
    await tester.tap(find.text('Add exercise'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Plank');
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Plank'));
    await settle(tester);
    await tester.tap(find.byTooltip('Complete set 1'));
    await settle(tester);

    await tester.tap(find.text('Start with AI Coach'));
    await settle(tester);

    expect(find.text('Add a set first, then coach it.'), findsOneWidget);
  });
}
