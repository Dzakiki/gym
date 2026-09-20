import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/app/app.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/domain/enums.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  final now = DateTime.utc(2026, 9, 20);

  ExercisesCompanion exercise({
    required String id,
    required String name,
    ExerciseCategory category = ExerciseCategory.strength,
    String? coachKey,
    String instructions = '',
  }) => ExercisesCompanion.insert(
    id: id,
    name: name,
    category: category,
    equipment: Equipment.bodyweight,
    primaryMuscles: [MuscleGroup.core],
    instructions: Value(instructions),
    coachKey: Value(coachKey),
    createdAt: now,
    updatedAt: now,
  );

  /// Runs [body] against a freshly seeded in-memory database.
  ///
  /// Drift schedules a timer when a stream is cancelled, so the widget tree is
  /// disposed and one more frame is pumped before the test ends.
  void libraryTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      db = AppDatabase(NativeDatabase.memory());
      await db.batch(
        (b) => b.insertAll(db.exercises, [
          exercise(
            id: '1',
            name: 'Squat',
            coachKey: 'squat',
            instructions: 'Sit back and down.',
          ),
          exercise(id: '2', name: 'Plank', category: ExerciseCategory.core),
          exercise(id: '3', name: 'Bench press'),
        ]),
      );

      await body(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await db.close();
    });
  }

  Future<void> openLibrary(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FormCoachApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workouts').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercise library'));
    await tester.pumpAndSettle();
  }

  libraryTest('lists all exercises alphabetically', (tester) async {
    await openLibrary(tester);

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(titles, ['Bench press', 'Plank', 'Squat']);
  });

  libraryTest('marks coach-supported exercises', (tester) async {
    await openLibrary(tester);

    final badges = find.descendant(
      of: find.byType(ListTile),
      matching: find.byIcon(Icons.videocam),
    );

    expect(badges, findsOneWidget);
  });

  libraryTest('search narrows the list', (tester) async {
    await openLibrary(tester);

    await tester.enterText(find.byType(TextField), 'plan');
    await tester.pumpAndSettle();

    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Squat'), findsNothing);
  });

  libraryTest('shows an empty state when nothing matches', (tester) async {
    await openLibrary(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No exercises found'), findsOneWidget);
  });

  libraryTest('category chip filters the list', (tester) async {
    await openLibrary(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Core'));
    await tester.pumpAndSettle();

    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Squat'), findsNothing);
  });

  libraryTest('AI Coach chip shows only supported exercises', (tester) async {
    await openLibrary(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'AI Coach'));
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Plank'), findsNothing);
  });

  libraryTest('tapping an exercise opens its details', (tester) async {
    await openLibrary(tester);

    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    expect(find.text('Sit back and down.'), findsOneWidget);
    expect(find.text('AI Coach supported'), findsOneWidget);
  });
}
