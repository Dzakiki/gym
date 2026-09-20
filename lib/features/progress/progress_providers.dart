import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/progress_repository.dart';

/// Every completed set of every finished workout.
final completedSetsProvider =
    StreamProvider.autoDispose<List<CompletedSetRecord>>((ref) {
      return ref.watch(progressRepositoryProvider).watchCompletedSets();
    });

/// The Form Coach's scores over time, oldest first.
final coachScoresProvider = StreamProvider.autoDispose<List<CoachScorePoint>>((
  ref,
) {
  return ref.watch(progressRepositoryProvider).watchCoachScores();
});
