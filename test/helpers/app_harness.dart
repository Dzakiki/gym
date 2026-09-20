import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/app/app.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:formcoach/data/seed/seed_service.dart';
import 'package:formcoach/data/seed/template_seeder.dart';

import 'file_asset_bundle.dart';

/// Runs [body] against the full app on a seeded in-memory database.
///
/// Drift schedules a timer when a stream is cancelled, so the widget tree is
/// disposed and one more frame is pumped before the test ends.
void appTest(
  String description,
  Future<void> Function(WidgetTester tester, AppDatabase db) body,
) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(description, (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    DateTime clock() => DateTime.utc(2026, 9, 20);
    final bundle = FileAssetBundle();
    // Reading asset files is real I/O, which needs the real (not fake) clock.
    await tester.runAsync(
      () => SeedService(
        exercises: ExerciseSeeder(
          database: db,
          assetBundle: bundle,
          clock: clock,
        ),
        templates: TemplateSeeder(
          database: db,
          assetBundle: bundle,
          clock: clock,
        ),
      ).seedAll(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FormCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    await body(tester, db);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await db.close();
  });
}

/// Opens the Workouts tab from the home screen.
Future<void> openWorkoutsTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Workouts'),
    ),
  );
  await tester.pumpAndSettle();
}
