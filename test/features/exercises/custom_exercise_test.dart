import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/domain/enums.dart';

import '../../helpers/app_harness.dart';

Future<void> _openLibrary(WidgetTester tester) async {
  await openWorkoutsTab(tester);
  await tester.tap(find.text('Exercise library'));
  await settle(tester);
}

Future<void> _openForm(WidgetTester tester) async {
  await _openLibrary(tester);
  await tester.tap(find.text('New exercise'));
  await settle(tester);
}

Finder get _save => find.widgetWithText(TextButton, 'Save');

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(_save).onPressed != null;

void main() {
  appTest('the library offers a way to add an exercise', (tester, db) async {
    await _openLibrary(tester);

    expect(find.text('New exercise'), findsOneWidget);
  });

  appTest('Save needs a name and at least one muscle', (tester, db) async {
    await _openForm(tester);
    expect(_saveEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).first, 'Sled push');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);

    await tester.tap(find.widgetWithText(FilterChip, 'Quadriceps'));
    await tester.pump();
    expect(_saveEnabled(tester), isTrue);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
  });

  appTest('a saved exercise appears in the library and is stored', (
    tester,
    db,
  ) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Sled push');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cardio'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Machine'));
    await tester.tap(find.widgetWithText(FilterChip, 'Quadriceps'));
    await tester.tap(find.widgetWithText(FilterChip, 'Glutes'));
    await tester.pump();

    await tester.tap(_save);
    await settle(tester);

    expect(find.text('Exercise library'), findsOneWidget);
    // The list is long and lazy, so search for the new exercise.
    await tester.enterText(find.byType(TextField), 'Sled');
    await settle(tester);
    expect(find.text('Sled push'), findsOneWidget);
    expect(find.text('Cardio, Machine, custom'), findsOneWidget);
    final rows = (await tester.runAsync(() => db.select(db.exercises).get()))!;
    final saved = rows.singleWhere((e) => e.name == 'Sled push');
    expect(saved.isCustom, isTrue);
    expect(saved.category, ExerciseCategory.cardio);
    expect(saved.equipment, Equipment.machine);
    expect(saved.primaryMuscles, [MuscleGroup.glutes, MuscleGroup.quadriceps]);
  });

  appTest('a custom exercise can be deleted, a built-in one cannot', (
    tester,
    db,
  ) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Sled push');
    await tester.tap(find.widgetWithText(FilterChip, 'Quadriceps'));
    await tester.pump();
    await tester.tap(_save);
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'Sled');
    await settle(tester);
    await tester.tap(find.text('Sled push'));
    await settle(tester);
    await tester.tap(find.byTooltip('Delete exercise'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(find.text('Sled push'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Squat');
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Squat'));
    await settle(tester);
    expect(find.byTooltip('Delete exercise'), findsNothing);
  });

  appTest('a custom exercise can be picked for a routine', (tester, db) async {
    await openWorkoutsTab(tester);
    await tester.tap(find.byTooltip('New routine'));
    await settle(tester);
    await tester.tap(find.text('Add exercise'));
    await settle(tester);
    await tester.tap(find.text('New exercise'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Sled push');
    await tester.tap(find.widgetWithText(FilterChip, 'Quadriceps'));
    await tester.pump();
    await tester.tap(_save);
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'Sled');
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Sled push'));
    await settle(tester);

    expect(find.text('Sled push'), findsOneWidget);
    expect(find.text('3 x 10, rest 90 s'), findsOneWidget);
  });
}
