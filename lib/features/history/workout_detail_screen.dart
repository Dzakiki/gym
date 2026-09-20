import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/core/date_format.dart';
import 'package:formcoach/core/widgets/empty_state.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';
import 'package:formcoach/domain/weight_unit.dart';
import 'package:formcoach/features/history/history_providers.dart';
import 'package:formcoach/features/history/set_formatting.dart';
import 'package:formcoach/features/settings/settings_providers.dart';
import 'package:formcoach/features/workout/workout_formatting.dart';
import 'package:formcoach/features/workout/workout_providers.dart';
import 'package:go_router/go_router.dart';

/// A finished workout: when it happened and every set that was done.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({required this.workoutId, super.key});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutProvider(workoutId));
    final value = workout.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(value?.session.name ?? 'Workout'),
        actions: [
          if (value != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete workout',
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
      body: workout.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load this workout',
        ),
        data: (item) => item == null
            ? const EmptyState(
                icon: Icons.search_off,
                title: 'Workout not found',
                message: 'It may have been deleted.',
              )
            : _Body(
                workout: item,
                unit: ref.watch(weightUnitProvider),
                analyses:
                    ref.watch(coachAnalysesProvider(workoutId)).value ??
                    const {},
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('This workout will be removed from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(workoutRepositoryProvider).discardWorkout(workoutId);
    router.pop();
  }
}

/// A short note about the coach's score for a set, or nothing.
String _coachNote(CoachAnalysis? analysis) {
  final score = analysis?.setScore;
  return score == null ? '' : '  (AI Coach ${score.round()})';
}

class _Body extends StatelessWidget {
  const _Body({
    required this.workout,
    required this.unit,
    required this.analyses,
  });

  final ActiveWorkout workout;
  final WeightUnit unit;

  /// The coach's analysis of coached sets, by set id.
  final Map<String, CoachAnalysis> analyses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = workout.session;
    final ended = session.endedAt;
    final volume = workout.exercises
        .expand((e) => e.sets)
        .where((s) => s.completedAt != null)
        .fold<double>(0, (sum, s) => sum + (s.reps ?? 0) * (s.weightKg ?? 0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${formatDate(session.startedAt)} at ${formatTime(session.startedAt)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (ended != null)
              Chip(
                label: Text(
                  formatDuration(ended.difference(session.startedAt)),
                ),
              ),
            Chip(label: Text('${workout.completedSets} sets')),
            if (volume > 0) Chip(label: Text(formatVolume(volume, unit: unit))),
          ],
        ),
        const SizedBox(height: 16),
        for (final exercise in workout.exercises)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.exercise.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final set in exercise.sets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        'Set ${set.setIndex + 1}:  ${formatSetLog(set, unit: unit)}'
                        '${_coachNote(analyses[set.id])}',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
