import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/core/widgets/empty_state.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/domain/enum_labels.dart';
import 'package:formcoach/features/exercises/exercise_providers.dart';

/// Shows how to perform one exercise.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(exerciseId));
    return Scaffold(
      appBar: AppBar(title: Text(exercise.value?.name ?? 'Exercise')),
      body: exercise.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load this exercise',
        ),
        data: (item) => item == null
            ? const EmptyState(
                icon: Icons.search_off,
                title: 'Exercise not found',
                message: 'It may have been deleted.',
              )
            : _ExerciseDetails(exercise: item),
      ),
    );
  }
}

class _ExerciseDetails extends StatelessWidget {
  const _ExerciseDetails({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(exercise.category.label)),
            Chip(label: Text(exercise.equipment.label)),
            for (final muscle in exercise.primaryMuscles)
              Chip(label: Text(muscle.label)),
          ],
        ),
        if (exercise.coachKey != null) ...[
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: const ListTile(
              leading: Icon(Icons.videocam),
              title: Text('AI Coach supported'),
              subtitle: Text('Get live rep counting and form feedback.'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('How to do it', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          exercise.instructions.isEmpty
              ? 'No instructions yet.'
              : exercise.instructions,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
