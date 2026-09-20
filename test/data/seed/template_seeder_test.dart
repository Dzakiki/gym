import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:formcoach/data/seed/seed_service.dart';
import 'package:formcoach/data/seed/template_seeder.dart';

import '../../helpers/file_asset_bundle.dart';

void main() {
  late AppDatabase db;
  late SeedService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final bundle = FileAssetBundle();
    DateTime clock() => DateTime.utc(2026, 9, 20);
    service = SeedService(
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
    );
  });
  tearDown(() => db.close());

  test('seeds the program templates with their exercises', () async {
    await service.seedAll();

    final routines = await db.select(db.routines).get();
    final items = await db.select(db.routineExercises).get();

    expect(routines, hasLength(5));
    expect(routines.every((r) => r.isTemplate), isTrue);
    expect(items, hasLength(27));
  });

  test('is idempotent', () async {
    await service.seedAll();
    await service.seedAll();

    expect(await db.select(db.routines).get(), hasLength(5));
    expect(await db.select(db.routineExercises).get(), hasLength(27));
  });

  test('template ids are stable', () {
    expect(
      TemplateSeeder.routineIdForSlug('push-day'),
      TemplateSeeder.routineIdForSlug('push-day'),
    );
  });

  test('every template exercise exists in the exercise library', () {
    final exerciseSlugs = (jsonDecode(
      File(ExerciseSeeder.assetPath).readAsStringSync(),
    ) as List<dynamic>).map((e) => (e as Map<String, dynamic>)['slug']).toSet();
    final templates = (jsonDecode(
      File(TemplateSeeder.assetPath).readAsStringSync(),
    ) as List<dynamic>).cast<Map<String, dynamic>>();

    for (final template in templates) {
      for (final item in (template['items'] as List<dynamic>)) {
        final slug = (item as Map<String, dynamic>)['exercise'];
        expect(exerciseSlugs, contains(slug), reason: '${template['slug']}');
      }
    }
  });

  test('each item has reps or seconds, and sensible sets and rest', () {
    final templates = (jsonDecode(
      File(TemplateSeeder.assetPath).readAsStringSync(),
    ) as List<dynamic>).cast<Map<String, dynamic>>();

    for (final template in templates) {
      for (final raw in (template['items'] as List<dynamic>)) {
        final item = raw as Map<String, dynamic>;
        final hasTarget = item['reps'] != null || item['seconds'] != null;
        expect(
          hasTarget,
          isTrue,
          reason: '${template['slug']}/${item['exercise']}',
        );
        expect(item['sets'] as int, inInclusiveRange(1, 10));
        expect(item['rest'] as int, inInclusiveRange(0, 600));
      }
    }
  });
}
