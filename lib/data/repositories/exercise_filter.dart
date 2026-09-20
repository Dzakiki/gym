import 'package:formcoach/domain/enums.dart';

/// Search and filter options for the exercise library.
class ExerciseFilter {
  const ExerciseFilter({
    this.query = '',
    this.category,
    this.coachSupportedOnly = false,
  });

  final String query;
  final ExerciseCategory? category;
  final bool coachSupportedOnly;

  ExerciseFilter copyWith({
    String? query,
    ExerciseCategory? category,
    bool clearCategory = false,
    bool? coachSupportedOnly,
  }) {
    return ExerciseFilter(
      query: query ?? this.query,
      category: clearCategory ? null : category ?? this.category,
      coachSupportedOnly: coachSupportedOnly ?? this.coachSupportedOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExerciseFilter &&
      other.query == query &&
      other.category == category &&
      other.coachSupportedOnly == coachSupportedOnly;

  @override
  int get hashCode => Object.hash(query, category, coachSupportedOnly);
}
