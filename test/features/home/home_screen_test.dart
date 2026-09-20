import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/core/clock.dart';

import '../../helpers/app_harness.dart';

/// Monday 21 September 2026, midday, local time.
DateTime _monday() => DateTime(2026, 9, 21, 12);

void homeTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  appTest(
    description,
    (tester, db) => body(tester),
    overrides: [clockProvider.overrideWithValue(_monday)],
  );
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

/// Copies the Push day template (scheduled Monday and Thursday).
Future<void> _copyPushDay(WidgetTester tester) async {
  await _openTab(tester, 'Workouts');
  await tester.tap(find.text('Push day'));
  await settle(tester);
  await tester.tap(find.text('Copy to my routines'));
  await settle(tester);
}

void main() {
  homeTest('a new user sees an empty streak and nothing scheduled', (
    tester,
  ) async {
    expect(find.text('Start your streak'), findsOneWidget);
    expect(find.text('No workouts yet this week.'), findsOneWidget);
    expect(find.text('Today (Mon)'), findsOneWidget);
    expect(find.text('Nothing scheduled today'), findsOneWidget);
    expect(find.text('Start empty workout'), findsOneWidget);
  });

  homeTest('a routine scheduled for today is offered', (tester) async {
    await _copyPushDay(tester);

    await _openTab(tester, 'Home');

    expect(find.text('Push day'), findsOneWidget);
    expect(find.text('Nothing scheduled today'), findsNothing);
    expect(find.text('Start'), findsOneWidget);
  });

  homeTest('a routine not scheduled for today is not offered', (tester) async {
    // Pull day is scheduled for Tuesday and Friday.
    await _openTab(tester, 'Workouts');
    await tester.tap(find.text('Pull day'));
    await settle(tester);
    await tester.tap(find.text('Copy to my routines'));
    await settle(tester);

    await _openTab(tester, 'Home');

    expect(find.text('Nothing scheduled today'), findsOneWidget);
  });

  homeTest('Start begins the scheduled workout', (tester) async {
    await _copyPushDay(tester);
    await _openTab(tester, 'Home');

    await tester.tap(find.text('Start'));
    await settle(tester);

    expect(find.text('Bench press'), findsOneWidget);
  });

  homeTest('a workout in progress can be resumed from Home', (tester) async {
    await tester.tap(find.text('Start empty workout'));
    await settle(tester);
    await tester.tap(find.byTooltip('Back to workouts'));
    await settle(tester);

    await _openTab(tester, 'Home');

    expect(find.text('Workout in progress'), findsOneWidget);
    expect(find.text('Start empty workout'), findsNothing);
    await tester.tap(find.text('Resume'));
    await settle(tester);
    expect(find.text('No exercises yet'), findsOneWidget);
  });

  homeTest('finishing a workout starts the streak', (tester) async {
    await _openTab(tester, 'Workouts');
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

    await _openTab(tester, 'Home');

    expect(find.text('1 week streak'), findsOneWidget);
    expect(find.text('1 workout this week.'), findsOneWidget);
  });
}
