import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';

/// The workout in progress, or null when there is none.
final activeSessionProvider = StreamProvider.autoDispose<WorkoutSession?>((
  ref,
) {
  return ref.watch(workoutRepositoryProvider).watchActiveSession();
});

final workoutProvider = StreamProvider.autoDispose
    .family<ActiveWorkout?, String>((ref, id) {
      return ref.watch(workoutRepositoryProvider).watchWorkout(id);
    });
