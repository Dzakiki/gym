import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:formcoach/domain/enums.dart';

/// Stores a list of [MuscleGroup] values as a JSON array of enum names.
class MuscleGroupListConverter
    extends TypeConverter<List<MuscleGroup>, String> {
  const MuscleGroupListConverter();

  @override
  List<MuscleGroup> fromSql(String fromDb) {
    final names = (jsonDecode(fromDb) as List<dynamic>).cast<String>();
    return [for (final name in names) MuscleGroup.values.byName(name)];
  }

  @override
  String toSql(List<MuscleGroup> value) =>
      jsonEncode([for (final muscle in value) muscle.name]);
}

/// Stores a list of ints (e.g. ISO weekdays 1-7) as a JSON array.
class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<int>();

  @override
  String toSql(List<int> value) => jsonEncode(value);
}
