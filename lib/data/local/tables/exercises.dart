import 'package:drift/drift.dart';
import 'package:formcoach/data/local/converters.dart';
import 'package:formcoach/data/local/tables/sync_columns.dart';
import 'package:formcoach/domain/enums.dart';

/// The exercise library: seeded global exercises plus user-made custom ones.
@TableIndex(name: 'idx_exercises_name', columns: {#name})
class Exercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get category => textEnum<ExerciseCategory>()();
  TextColumn get equipment => textEnum<Equipment>()();
  TextColumn get primaryMuscles =>
      text().map(const MuscleGroupListConverter())();
  TextColumn get instructions => text().withDefault(const Constant(''))();

  /// Maps to a Form Coach exercise definition (e.g. `squat`), or null when the
  /// AI coach does not support this exercise.
  TextColumn get coachKey => text().nullable()();

  /// True for exercises created by the user, false for seeded ones.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
