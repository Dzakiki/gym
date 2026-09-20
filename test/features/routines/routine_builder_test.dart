import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

Finder get _saveButton => find.widgetWithText(TextButton, 'Save');

bool _isSaveEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(_saveButton).onPressed != null;

Future<void> _openNewRoutine(WidgetTester tester) async {
  await openWorkoutsTab(tester);
  await tester.tap(find.byTooltip('New routine'));
  await tester.pumpAndSettle();
}

Future<void> _addExercise(WidgetTester tester, String name) async {
  await tester.tap(find.text('Add exercise'));
  await tester.pumpAndSettle();
  // The library is a long lazy list, so search like a user would.
  await tester.enterText(find.byType(TextField), name);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, name));
  await tester.pumpAndSettle();
}

void main() {
  appTest('Save stays disabled until the routine is valid', (tester, db) async {
    await _openNewRoutine(tester);
    expect(_isSaveEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).first, 'Morning');
    await tester.pump();
    expect(_isSaveEnabled(tester), isFalse);
    expect(find.text('Add at least one exercise.'), findsOneWidget);

    await _addExercise(tester, 'Squat');
    expect(_isSaveEnabled(tester), isTrue);
  });

  appTest('creates a routine and lists it under my routines', (
    tester,
    db,
  ) async {
    await _openNewRoutine(tester);
    await tester.enterText(find.byType(TextField).first, 'Morning');
    await _addExercise(tester, 'Squat');
    expect(find.text('3 x 10, rest 90 s'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Mon'));
    await tester.pump();
    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(
      find.text('No routines yet. Copy a program template below to start.'),
      findsNothing,
    );
  });

  appTest('editing an exercise changes its sets', (tester, db) async {
    await _openNewRoutine(tester);
    await _addExercise(tester, 'Squat');

    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase Sets'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('4 x 10, rest 90 s'), findsOneWidget);
  });

  appTest('an exercise can target time instead of reps', (tester, db) async {
    await _openNewRoutine(tester);
    await _addExercise(tester, 'Plank');

    await tester.tap(find.text('Plank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Time'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('3 x 30 s, rest 90 s'), findsOneWidget);
  });

  appTest('removing the last exercise makes the routine invalid', (
    tester,
    db,
  ) async {
    await _openNewRoutine(tester);
    await tester.enterText(find.byType(TextField).first, 'Morning');
    await _addExercise(tester, 'Squat');
    expect(_isSaveEnabled(tester), isTrue);

    await tester.tap(find.byTooltip('Remove Squat'));
    await tester.pump();

    expect(_isSaveEnabled(tester), isFalse);
    expect(find.text('Add at least one exercise.'), findsOneWidget);
  });

  appTest('a copied routine can be renamed', (tester, db) async {
    await openWorkoutsTab(tester);
    await tester.tap(find.text('Push day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy to my routines'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit routine'));
    await tester.pumpAndSettle();
    expect(find.text('Bench press'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'My push day');
    await tester.pump();
    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    expect(find.text('My push day'), findsWidgets);
  });
  group('leaving with unsaved changes', () {
    appTest('an untouched new routine can be left without a prompt', (
      tester,
      db,
    ) async {
      await _openNewRoutine(tester);

      await tester.pageBack();
      await settle(tester);

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New routine'), findsNothing);
    });

    appTest('leaving after typing asks first and can keep editing', (
      tester,
      db,
    ) async {
      await _openNewRoutine(tester);
      await tester.enterText(find.byType(TextField).first, 'Morning');
      await tester.pump();

      await tester.pageBack();
      await settle(tester);
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await settle(tester);
      expect(find.text('New routine'), findsWidgets);
      expect(find.text('Discard changes?'), findsNothing);
    });

    appTest('discarding leaves without saving', (tester, db) async {
      await _openNewRoutine(tester);
      await tester.enterText(find.byType(TextField).first, 'Morning');
      await tester.pump();

      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await settle(tester);

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New routine'), findsNothing);
      expect(find.text('Morning'), findsNothing);
    });

    appTest('saving leaves without a prompt', (tester, db) async {
      await _openNewRoutine(tester);
      await tester.enterText(find.byType(TextField).first, 'Morning');
      await _addExercise(tester, 'Squat');

      await tester.tap(_saveButton);
      await settle(tester);

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Morning'), findsOneWidget);
    });

    appTest('editing an existing routine without changes needs no prompt', (
      tester,
      db,
    ) async {
      await openWorkoutsTab(tester);
      await tester.tap(find.text('Push day'));
      await settle(tester);
      await tester.tap(find.text('Copy to my routines'));
      await settle(tester);
      await tester.tap(find.byTooltip('Edit routine'));
      await settle(tester);

      await tester.pageBack();
      await settle(tester);

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit routine'), findsNothing);
    });

    appTest('changing an existing routine asks before leaving', (
      tester,
      db,
    ) async {
      await openWorkoutsTab(tester);
      await tester.tap(find.text('Push day'));
      await settle(tester);
      await tester.tap(find.text('Copy to my routines'));
      await settle(tester);
      await tester.tap(find.byTooltip('Edit routine'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Renamed');
      await tester.pump();

      await tester.pageBack();
      await settle(tester);

      expect(find.text('Discard changes?'), findsOneWidget);
    });

    appTest('undoing a change removes the prompt', (tester, db) async {
      await _openNewRoutine(tester);
      await tester.enterText(find.byType(TextField).first, 'Morning');
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      await tester.pageBack();
      await settle(tester);

      expect(find.text('Discard changes?'), findsNothing);
    });
  });
}
