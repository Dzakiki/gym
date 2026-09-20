import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/domain/enums.dart';
import 'package:uuid/uuid.dart';

/// Loads the built-in exercise library from `assets/seed/exercises.json`.
///
/// Seeding is idempotent: rows that already exist are left untouched, so user
/// changes are never overwritten and running it on every launch is safe.
class ExerciseSeeder {
  ExerciseSeeder({
    required this._database,
    required this._assetBundle,
    required this._clock,
  });

  static const assetPath = 'assets/seed/exercises.json';

  static const _uuid = Uuid();

  final AppDatabase _database;
  final AssetBundle _assetBundle;
  final Clock _clock;

  /// A stable id for a seeded exercise. It is derived from the [slug], so it
  /// is identical on every device and on the server.
  static String idForSlug(String slug) =>
      _uuid.v5(Namespace.url.value, 'formcoach:exercise:$slug');

  Future<void> seed() async {
    final json = await _assetBundle.loadString(assetPath);
    final entries = (jsonDecode(json) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final now = _clock();

    await _database.batch((batch) {
      batch.insertAll(_database.exercises, [
        for (final entry in entries) _toCompanion(entry, now),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  ExercisesCompanion _toCompanion(Map<String, dynamic> entry, DateTime now) {
    final muscles = (entry['primaryMuscles'] as List<dynamic>).cast<String>();
    return ExercisesCompanion.insert(
      id: idForSlug(entry['slug'] as String),
      name: entry['name'] as String,
      category: ExerciseCategory.values.byName(entry['category'] as String),
      equipment: Equipment.values.byName(entry['equipment'] as String),
      primaryMuscles: [
        for (final name in muscles) MuscleGroup.values.byName(name),
      ],
      instructions: Value(entry['instructions'] as String),
      coachKey: Value(entry['coachKey'] as String?),
      createdAt: now,
      updatedAt: now,
    );
  }
}
