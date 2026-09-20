import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/features/form_coach/coach_controller.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/controlled_pose_source.dart';

DateTime _monday() => DateTime(2026, 9, 21, 12);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

Future<void> _finishWorkout(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Finish'));
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
  await settle(tester);
  await tester.tap(find.text('Done'));
  await settle(tester);
}

/// Starts Push day, types [weight] and [reps] for the first set, ticks it off
/// and finishes the workout.
Future<void> _liftBench(
  WidgetTester tester, {
  required String weight,
  required String reps,
  String unit = 'kg',
}) async {
  await _openTab(tester, 'Workouts');
  await tester.tap(find.text('Push day'));
  await settle(tester);
  await tester.tap(find.text('Start workout'));
  await settle(tester);
  await tester.enterText(
    find.widgetWithText(TextFormField, unit).first,
    weight,
  );
  await settle(tester);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'reps').first,
    reps,
  );
  await settle(tester);
  await tester.tap(find.byTooltip('Complete set 1').first);
  await settle(tester);
  await _finishWorkout(tester);
}

void main() {
  final overrides = [clockProvider.overrideWithValue(_monday)];

  appTest('an empty Progress tab explains what will appear', (
    tester,
    db,
  ) async {
    await _openTab(tester, 'Progress');

    expect(find.textContaining('to see your volume'), findsOneWidget);
    expect(find.textContaining('Coach a set in a workout'), findsOneWidget);
    expect(find.text('Your personal bests will show up here.'), findsOneWidget);
    expect(find.text('No workouts yet'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  }, overrides: overrides);

  appTest('a weighted set shows the volume chart and a record', (
    tester,
    db,
  ) async {
    await _liftBench(tester, weight: '80', reps: '5');

    await _openTab(tester, 'Progress');

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Bench press, heaviest: 80 kg x 5'), findsOneWidget);
    expect(find.text('Push day'), findsOneWidget);
  }, overrides: overrides);

  appTest(
    'records use the chosen unit',
    (tester, db) async {
      await _liftBench(tester, weight: '175', reps: '5', unit: 'lb');

      await _openTab(tester, 'Progress');

      expect(find.text('Bench press, heaviest: 175 lb x 5'), findsOneWidget);
    },
    overrides: overrides,
    initialSettings: {'weight_unit': 'lb'},
  );

  final source = ControlledPoseSource();
  appTest('a coached set shows the form chart and a form record', (
    tester,
    db,
  ) async {
    addTearDown(source.close);
    await _openTab(tester, 'Workouts');
    await tester.tap(find.text('Home bodyweight'));
    await settle(tester);
    await tester.tap(find.text('Start workout'));
    await settle(tester);
    await tester.tap(find.text('Start with AI Coach').first);
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    source.addAll(squatFrames(const SquatMotion(reps: 2)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Stop'));
    await settle(tester);
    await tester.tap(find.text('Save to workout'));
    await settle(tester);
    await _finishWorkout(tester);

    await _openTab(tester, 'Progress');

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Squat'), findsOneWidget);
    expect(find.textContaining('Squat, best form: '), findsOneWidget);
  }, overrides: [...overrides, poseSourceProvider.overrideWithValue(source)]);
}
