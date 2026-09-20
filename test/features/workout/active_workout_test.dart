import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';

import '../../helpers/app_harness.dart';

Future<void> _startPushDay(WidgetTester tester) async {
  await openWorkoutsTab(tester);
  await tester.tap(find.text('Push day'));
  await settle(tester);
  await tester.tap(find.text('Start workout'));
  await settle(tester);
}

Future<List<SetLog>> _sets(WidgetTester tester, AppDatabase db) async {
  final rows = await tester.runAsync(() => db.select(db.setLogs).get());
  return rows!;
}

void main() {
  appTest('an empty workout can be started and resumed', (tester, db) async {
    await openWorkoutsTab(tester);

    await tester.tap(find.text('Start empty workout'));
    await settle(tester);

    expect(find.text('No exercises yet'), findsOneWidget);
    expect(find.text('Add exercise'), findsOneWidget);
    // The tab bar is hidden while training.
    expect(find.byType(NavigationBar), findsNothing);
  });

  appTest('starting from a routine plans its sets', (tester, db) async {
    await _startPushDay(tester);

    expect(find.text('Push day'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.byTooltip('Complete set 4'), findsOneWidget);
    expect((await _sets(tester, db)).length, 15);
  });

  appTest('ticking a set starts the rest countdown', (tester, db) async {
    await _startPushDay(tester);

    await tester.tap(find.byTooltip('Complete set 1').first);
    await tester.pump();

    expect(find.text('Rest 2:00'), findsOneWidget);
    await tester.tap(find.text('+15 s'));
    await tester.pump();
    expect(find.text('Rest 2:15'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Rest 2:14'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.textContaining('Rest '), findsNothing);
  });

  appTest('typed reps are saved', (tester, db) async {
    await _startPushDay(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'reps').first,
      '13',
    );
    await settle(tester);

    expect((await _sets(tester, db)).where((s) => s.reps == 13), hasLength(1));
  });

  appTest('a number above the limit cannot be typed', (tester, db) async {
    await _startPushDay(tester);
    final field = find.widgetWithText(TextFormField, 'kg').first;

    await tester.enterText(field, '999');
    await settle(tester);
    await tester.enterText(field, '1500');
    await settle(tester);

    final weights = (await _sets(tester, db)).map((s) => s.weightKg);
    expect(weights.where((w) => w == 999), hasLength(1));
    expect(weights.any((w) => w != null && w > 1000), isFalse);
  });

  appTest('an exercise can be added mid-workout', (tester, db) async {
    await openWorkoutsTab(tester);
    await tester.tap(find.text('Start empty workout'));
    await settle(tester);

    await tester.tap(find.text('Add exercise'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Plank');
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Plank'));
    await settle(tester);

    expect(find.text('Plank'), findsOneWidget);
    expect(find.byTooltip('Complete set 1'), findsOneWidget);
  });

  appTest('another set can be added to an exercise', (tester, db) async {
    await _startPushDay(tester);

    await tester.tap(find.text('Add set').first);
    await settle(tester);

    expect(find.byTooltip('Complete set 5'), findsOneWidget);
  });

  appTest('finishing shows a summary and returns to workouts', (
    tester,
    db,
  ) async {
    await _startPushDay(tester);
    await tester.tap(find.byTooltip('Complete set 1').first);
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await settle(tester);
    expect(find.text('Finish workout?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await settle(tester);

    expect(find.text('Workout complete'), findsOneWidget);
    expect(find.text('Sets: 1'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(find.text('Start empty workout'), findsOneWidget);
    expect(find.textContaining('Rest '), findsNothing);
  });

  appTest('finishing with nothing ticked off offers to discard', (
    tester,
    db,
  ) async {
    await _startPushDay(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await settle(tester);
    expect(find.text('Discard workout?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await settle(tester);

    expect(find.text('Start empty workout'), findsOneWidget);
    expect((await _sets(tester, db)).every((s) => s.deletedAt != null), isTrue);
  });

  appTest('a workout in progress can be resumed and blocks a second one', (
    tester,
    db,
  ) async {
    await _startPushDay(tester);
    await tester.tap(find.byTooltip('Back to workouts'));
    await settle(tester);

    expect(find.text('Workout in progress'), findsOneWidget);
    expect(find.text('Start empty workout'), findsNothing);

    await tester.tap(find.text('Beginner full body'));
    await settle(tester);
    await tester.tap(find.text('Start workout'));
    await settle(tester);

    expect(find.text('Finish your current workout first.'), findsOneWidget);
    expect(find.text('Push day'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
  });
}
