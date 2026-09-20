import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:formcoach/domain/enums.dart';
import 'package:formcoach/features/form_coach/exercises/registry.dart';

import '../../helpers/file_asset_bundle.dart';

void main() {
  late AppDatabase db;
  late ExerciseSeeder seeder;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    seeder = ExerciseSeeder(
      database: db,
      assetBundle: FileAssetBundle(),
      clock: () => DateTime.utc(2026, 9, 20),
    );
  });
  tearDown(() => db.close());

  test('inserts the whole built-in library', () async {
    await seeder.seed();

    final rows = await db.select(db.exercises).get();

    expect(rows.length, greaterThanOrEqualTo(50));
    expect(rows.every((r) => !r.isCustom), isTrue);
  });

  test('is idempotent and does not overwrite user changes', () async {
    await seeder.seed();
    final first = (await db.select(db.exercises).get()).first;
    await (db.update(db.exercises)..where((e) => e.id.equals(first.id))).write(
      const ExercisesCompanion(name: Value('My renamed exercise')),
    );

    await seeder.seed();

    final rows = await db.select(db.exercises).get();
    expect(rows.length, greaterThanOrEqualTo(50));
    expect(
      rows.where((r) => r.id == first.id).single.name,
      'My renamed exercise',
    );
  });

  test('ids are stable across runs', () {
    expect(
      ExerciseSeeder.idForSlug('squat'),
      ExerciseSeeder.idForSlug('squat'),
    );
    expect(
      ExerciseSeeder.idForSlug('squat'),
      isNot(ExerciseSeeder.idForSlug('push-up')),
    );
  });

  group('seed file', () {
    late List<Map<String, dynamic>> entries;

    setUpAll(() {
      final json = File(ExerciseSeeder.assetPath).readAsStringSync();
      entries = (jsonDecode(json) as List<dynamic>)
          .cast<Map<String, dynamic>>();
    });

    test('slugs and names are unique', () {
      final slugs = entries.map((e) => e['slug']).toSet();
      final names = entries.map((e) => e['name']).toSet();

      expect(slugs.length, entries.length);
      expect(names.length, entries.length);
    });

    test('every entry uses valid enum values and has instructions', () {
      for (final e in entries) {
        expect(
          () => ExerciseCategory.values.byName(e['category'] as String),
          returnsNormally,
          reason: '${e['slug']}',
        );
        expect(
          () => Equipment.values.byName(e['equipment'] as String),
          returnsNormally,
          reason: '${e['slug']}',
        );
        final muscles = (e['primaryMuscles'] as List<dynamic>).cast<String>();
        expect(muscles, isNotEmpty, reason: '${e['slug']}');
        for (final m in muscles) {
          expect(
            () => MuscleGroup.values.byName(m),
            returnsNormally,
            reason: '${e['slug']}',
          );
        }
        expect(
          (e['instructions'] as String).trim(),
          isNotEmpty,
          reason: '${e['slug']}',
        );
      }
    });

    test('coach keys match the exercises the coach can judge', () {
      final keys = entries
          .map((e) => e['coachKey'])
          .whereType<String>()
          .toSet();

      expect(keys, coachExercises.keys.toSet());
    });
  });
}
