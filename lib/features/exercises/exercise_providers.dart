import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/exercise_filter.dart';
import 'package:formcoach/domain/enums.dart';

/// Holds the search text and filters of the exercise library screen.
class ExerciseFilterNotifier extends Notifier<ExerciseFilter> {
  @override
  ExerciseFilter build() => const ExerciseFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  /// Pass null to show all categories.
  void setCategory(ExerciseCategory? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
  }

  void setCoachSupportedOnly({required bool value}) =>
      state = state.copyWith(coachSupportedOnly: value);
}

final exerciseFilterProvider =
    NotifierProvider.autoDispose<ExerciseFilterNotifier, ExerciseFilter>(
      ExerciseFilterNotifier.new,
    );

final filteredExercisesProvider = StreamProvider.autoDispose<List<Exercise>>((
  ref,
) {
  final filter = ref.watch(exerciseFilterProvider);
  return ref.watch(exerciseRepositoryProvider).watchExercises(filter);
});

final exerciseByIdProvider = StreamProvider.autoDispose
    .family<Exercise?, String>((ref, id) {
      return ref.watch(exerciseRepositoryProvider).watchById(id);
    });
