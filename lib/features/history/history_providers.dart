import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';

/// Finished workouts, newest first.
final historyProvider = StreamProvider.autoDispose<List<HistoryEntry>>((ref) {
  return ref.watch(workoutRepositoryProvider).watchHistory();
});

/// The Form Coach's analysis of each coached set of a workout, by set id.
final coachAnalysesProvider = StreamProvider.autoDispose
    .family<Map<String, CoachAnalysis>, String>((ref, sessionId) {
      return ref.watch(coachRepositoryProvider).watchForSession(sessionId);
    });
