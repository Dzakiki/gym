import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';

/// Finished workouts, newest first.
final historyProvider = StreamProvider.autoDispose<List<HistoryEntry>>((ref) {
  return ref.watch(workoutRepositoryProvider).watchHistory();
});
