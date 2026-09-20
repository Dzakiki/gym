import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/core/widgets/empty_state.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';
import 'package:formcoach/domain/weight_unit.dart';
import 'package:formcoach/features/form_coach/exercises/registry.dart';
import 'package:formcoach/features/settings/settings_providers.dart';
import 'package:formcoach/features/workout/rest_banner.dart';
import 'package:formcoach/features/workout/rest_timer.dart';
import 'package:formcoach/features/workout/set_row.dart';
import 'package:formcoach/features/workout/workout_formatting.dart';
import 'package:formcoach/features/workout/workout_providers.dart';
import 'package:go_router/go_router.dart';

/// The screen shown while training: log sets, rest, add exercises, finish.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({required this.workoutId, super.key});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutProvider(workoutId));
    return workout.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _message(
        context,
        icon: Icons.error_outline,
        title: 'Could not load this workout',
      ),
      data: (item) => item == null || item.isFinished
          ? _message(
              context,
              icon: Icons.check_circle_outline,
              title: 'This workout is finished',
            )
          : _WorkoutView(workout: item),
    );
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: EmptyState(
        icon: icon,
        title: title,
        message: 'Go back to your workouts to start a new one.',
      ),
    );
  }
}

class _WorkoutView extends ConsumerWidget {
  const _WorkoutView({required this.workout});

  final ActiveWorkout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = workout.session;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to workouts',
          onPressed: () => context.go(AppRoutes.workouts),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.name),
            _ElapsedTime(startedAt: session.startedAt),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Discard workout',
            onPressed: () => _discard(context, ref),
          ),
          TextButton(
            onPressed: () => _finish(context, ref),
            child: const Text('Finish'),
          ),
        ],
      ),
      body: workout.exercises.isEmpty
          ? const EmptyState(
              icon: Icons.fitness_center,
              title: 'No exercises yet',
              message: 'Add an exercise to start logging sets.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final exercise in workout.exercises)
                  _ExerciseCard(sessionId: session.id, exercise: exercise),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add exercise'),
        onPressed: () => _addExercise(context, ref),
      ),
      bottomNavigationBar: const RestBanner(),
    );
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await context.push<Exercise>(AppRoutes.pickExercise);
    if (exercise == null) return;
    await ref
        .read(workoutRepositoryProvider)
        .addExercise(workout.session.id, exercise.id);
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    // Finishing replaces this screen's content (the workout is now finished),
    // so grab what is needed afterwards before any await.
    final router = GoRouter.of(context);
    final dialogContext = Navigator.of(context, rootNavigator: true).context;
    final unit = ref.read(weightUnitProvider);
    final done = workout.completedSets;
    final confirmed = await _confirm(
      context,
      title: done == 0 ? 'Discard workout?' : 'Finish workout?',
      message: done == 0
          ? 'No sets are ticked off, so this workout will not be saved.'
          : '$done sets completed. Sets you did not tick off are removed.',
      action: done == 0 ? 'Discard' : 'Finish',
    );
    if (!confirmed) return;

    final summary = await ref
        .read(workoutRepositoryProvider)
        .finishWorkout(workout.session.id);
    ref.read(restTimerProvider.notifier).skip();
    if (summary != null && dialogContext.mounted) {
      await _showSummary(dialogContext, summary, unit);
    }
    router.go(AppRoutes.workouts);
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final confirmed = await _confirm(
      context,
      title: 'Discard workout?',
      message: 'Everything logged in this workout will be deleted.',
      action: 'Discard',
    );
    if (!confirmed) return;

    await ref
        .read(workoutRepositoryProvider)
        .discardWorkout(workout.session.id);
    ref.read(restTimerProvider.notifier).skip();
    router.go(AppRoutes.workouts);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showSummary(
    BuildContext context,
    WorkoutSummary summary,
    WeightUnit unit,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${formatDuration(summary.duration)}'),
            Text('Sets: ${summary.completedSets}'),
            if (summary.volumeKg > 0)
              Text('Volume: ${formatVolume(summary.volumeKg, unit: unit)}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.sessionId, required this.exercise});

  final String sessionId;
  final ActiveExercise exercise;

  /// Opens the coach for the first set that is not done yet; the results are
  /// saved into that set.
  void _startCoach(BuildContext context) {
    final open = exercise.sets.where((s) => s.completedAt == null);
    if (open.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a set first, then coach it.')),
      );
      return;
    }
    context.push(
      AppRoutes.coachSession(
        exercise.exercise.coachKey!,
        setLogId: open.first.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.exercise.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (coachDefinitionFor(exercise.exercise.coachKey) != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Start with AI Coach'),
                  onPressed: () => _startCoach(context),
                ),
              ),
            const SizedBox(height: 8),
            for (final set in exercise.sets)
              SetRow(
                key: ValueKey(set.id),
                set: set,
                restSeconds: exercise.restSeconds,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
                onPressed: () => ref
                    .read(workoutRepositoryProvider)
                    .addSet(sessionId, exercise.exercise.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows how long the workout has been running, updating every second.
class _ElapsedTime extends ConsumerStatefulWidget {
  const _ElapsedTime({required this.startedAt});

  final DateTime startedAt;

  @override
  ConsumerState<_ElapsedTime> createState() => _ElapsedTimeState();
}

class _ElapsedTimeState extends ConsumerState<_ElapsedTime> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = ref.read(clockProvider)().difference(widget.startedAt);
    return Text(
      formatClock(elapsed.inSeconds),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
