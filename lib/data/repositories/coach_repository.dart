import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/core/ids.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/repositories/coach_result.dart';
import 'package:formcoach/data/repositories/watch_load.dart';

/// Saves what the Form Coach found into the workout log.
class CoachRepository {
  CoachRepository({
    required this._database,
    required this._clock,
    required this._newId,
  });

  final AppDatabase _database;
  final Clock _clock;
  final IdGenerator _newId;

  /// Records a coached set: fills the set's reps (or held seconds), marks it
  /// done and coached, and stores the coach's analysis. A set that was
  /// coached before is overwritten. Throws [StateError] if the set does not
  /// exist.
  Future<void> saveCoachedSet({
    required String setLogId,
    required String exerciseKey,
    required CoachResult result,
  }) {
    return _database.transaction(() async {
      final now = _clock();

      final updated =
          await (_database.update(
            _database.setLogs,
          )..where((s) => s.id.equals(setLogId) & s.deletedAt.isNull())).write(
            SetLogsCompanion(
              reps: Value(result.isHold ? null : result.repsCounted),
              durationSeconds: Value(result.holdSeconds?.round()),
              coached: const Value(true),
              completedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      if (updated == 0) throw StateError('Set $setLogId not found.');

      await (_database.update(_database.coachAnalyses)
            ..where((a) => a.setLogId.equals(setLogId) & a.deletedAt.isNull()))
          .write(
            CoachAnalysesCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _database
          .into(_database.coachAnalyses)
          .insert(
            CoachAnalysesCompanion.insert(
              id: _newId(),
              setLogId: setLogId,
              exerciseKey: exerciseKey,
              engineVersion: coachEngineVersion,
              setScore: Value(result.setScore),
              repsCounted: Value(result.repsCounted),
              partialReps: Value(result.partialReps),
              holdSeconds: Value(result.holdSeconds),
              faults: Value(jsonEncode(result.faultCounts)),
              perRep: Value(
                jsonEncode([for (final rep in result.reps) rep.toJson()]),
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  /// The coach analyses of a workout's sets, by set id. Emits again when they
  /// change.
  Stream<Map<String, CoachAnalysis>> watchForSession(String sessionId) =>
      watchLoad(
        database: _database,
        tables: [_database.coachAnalyses, _database.setLogs],
        load: () async {
          final analyses = _database.coachAnalyses;
          final sets = _database.setLogs;
          final rows =
              await (_database.select(analyses).join([
                    innerJoin(sets, sets.id.equalsExp(analyses.setLogId)),
                  ])..where(
                    sets.sessionId.equals(sessionId) &
                        analyses.deletedAt.isNull() &
                        sets.deletedAt.isNull(),
                  ))
                  .get();
          return {
            for (final row in rows)
              row.readTable(analyses).setLogId: row.readTable(analyses),
          };
        },
      );
}
