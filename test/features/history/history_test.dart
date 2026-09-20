import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

Future<void> _openProgressTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Progress'),
    ),
  );
  await settle(tester);
}

/// Starts Push day, ticks off the first set and finishes the workout.
Future<void> _finishOneSetWorkout(WidgetTester tester) async {
  await openWorkoutsTab(tester);
  await tester.tap(find.text('Push day'));
  await settle(tester);
  await tester.tap(find.text('Start workout'));
  await settle(tester);
  await tester.tap(find.byTooltip('Complete set 1').first);
  await settle(tester);
  await tester.tap(find.widgetWithText(TextButton, 'Finish'));
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
  await settle(tester);
  await tester.tap(find.text('Done'));
  await settle(tester);
}

void main() {
  appTest('shows an empty state before any workout is finished', (
    tester,
    db,
  ) async {
    await _openProgressTab(tester);

    expect(find.text('No workouts yet'), findsOneWidget);
  });

  appTest('a finished workout appears in the history', (tester, db) async {
    await _finishOneSetWorkout(tester);

    await _openProgressTab(tester);

    expect(find.text('No workouts yet'), findsNothing);
    expect(find.text('Push day'), findsOneWidget);
    expect(find.textContaining('1 sets'), findsOneWidget);
  });

  appTest('opening a workout shows its sets', (tester, db) async {
    await _finishOneSetWorkout(tester);
    await _openProgressTab(tester);

    await tester.tap(find.text('Push day'));
    await settle(tester);

    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Set 1:  8 reps'), findsOneWidget);
    expect(find.text('1 sets'), findsOneWidget);
  });

  appTest('a workout can be deleted from the history', (tester, db) async {
    await _finishOneSetWorkout(tester);
    await _openProgressTab(tester);
    await tester.tap(find.text('Push day'));
    await settle(tester);

    await tester.tap(find.byTooltip('Delete workout'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(find.text('No workouts yet'), findsOneWidget);
  });
}
