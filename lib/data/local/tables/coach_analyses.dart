import 'package:drift/drift.dart';
import 'package:formcoach/data/local/tables/sync_columns.dart';
import 'package:formcoach/data/local/tables/workouts.dart';

/// The Form Coach's verdict on one coached set. Only numbers are stored: no
/// video and no pose data leave the device.
@DataClassName('CoachAnalysis')
@TableIndex(name: 'idx_coach_analyses_set_log', columns: {#setLogId})
class CoachAnalyses extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get setLogId =>
      text().references(SetLogs, #id, onDelete: KeyAction.cascade)();

  /// The coach exercise, e.g. `squat`.
  TextColumn get exerciseKey => text()();

  /// Which version of the scoring rules produced this, so old and new scores
  /// are never confused.
  IntColumn get engineVersion => integer()();

  /// 0 to 100: the average repetition score, or the share of good form for a
  /// hold. Null if nothing was measured.
  RealColumn get setScore => real().nullable()();
  IntColumn get repsCounted => integer().withDefault(const Constant(0))();
  IntColumn get partialReps => integer().withDefault(const Constant(0))();

  /// Seconds of good form held (hold exercises only).
  RealColumn get holdSeconds => real().nullable()();

  /// JSON object: how many repetitions had each fault, by fault code.
  TextColumn get faults => text().withDefault(const Constant('{}'))();

  /// JSON array with one entry per repetition (score, faults, timings).
  TextColumn get perRep => text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
