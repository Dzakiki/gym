import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/seed/exercise_seeder.dart';
import 'package:uuid/uuid.dart';

/// Loads the built-in program templates from `assets/seed/templates.json`.
///
/// Templates are routines with `isTemplate` set. The exercises they reference
/// must already be seeded (see `SeedService`). Like the exercise seeder, this
/// is idempotent and never overwrites existing rows.
class TemplateSeeder {
  TemplateSeeder({
    required this._database,
    required this._assetBundle,
    required this._clock,
  });

  static const assetPath = 'assets/seed/templates.json';

  static const _uuid = Uuid();

  final AppDatabase _database;
  final AssetBundle _assetBundle;
  final Clock _clock;

  /// A stable id for a template routine, derived from its [slug].
  static String routineIdForSlug(String slug) =>
      _uuid.v5(Namespace.url.value, 'formcoach:routine:$slug');

  static String _itemId(String slug, int position) =>
      _uuid.v5(Namespace.url.value, 'formcoach:routine:$slug:$position');

  Future<void> seed() async {
    final json = await _assetBundle.loadString(assetPath);
    final templates = (jsonDecode(json) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final now = _clock();

    await _database.batch((batch) {
      for (final template in templates) {
        final slug = template['slug'] as String;
        final routineId = routineIdForSlug(slug);
        batch.insert(
          _database.routines,
          RoutinesCompanion.insert(
            id: routineId,
            name: template['name'] as String,
            description: Value(template['description'] as String),
            isTemplate: const Value(true),
            scheduleDays: Value(
              (template['scheduleDays'] as List<dynamic>).cast<int>(),
            ),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );

        final items = (template['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (var position = 0; position < items.length; position++) {
          final item = items[position];
          batch.insert(
            _database.routineExercises,
            RoutineExercisesCompanion.insert(
              id: _itemId(slug, position),
              routineId: routineId,
              exerciseId: ExerciseSeeder.idForSlug(item['exercise'] as String),
              position: position,
              targetSets: Value(item['sets'] as int),
              targetReps: Value(item['reps'] as int?),
              targetSeconds: Value(item['seconds'] as int?),
              restSeconds: Value(item['rest'] as int),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
  }
}
