import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/core/widgets/empty_state.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/domain/enum_labels.dart';
import 'package:formcoach/domain/enums.dart';
import 'package:formcoach/features/exercises/exercise_providers.dart';
import 'package:go_router/go_router.dart';

/// Browse and search every exercise.
///
/// In [selectMode] tapping an exercise closes the screen and returns it to the
/// caller (used when adding an exercise to a routine).
class ExerciseLibraryScreen extends ConsumerWidget {
  const ExerciseLibraryScreen({this.selectMode = false, super.key});

  final bool selectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(filteredExercisesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(selectMode ? 'Choose an exercise' : 'Exercise library'),
      ),
      body: Column(
        children: [
          const _SearchField(),
          const _FilterChips(),
          Expanded(
            child: exercises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => const EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load exercises',
                message: 'Please restart the app and try again.',
              ),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'No exercises found',
                      message: 'Try a different search or filter.',
                    )
                  : _ExerciseList(items: items, selectMode: selectMode),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        decoration: const InputDecoration(
          labelText: 'Search exercises',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.search,
        onChanged: ref.read(exerciseFilterProvider.notifier).setQuery,
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(exerciseFilterProvider);
    final notifier = ref.read(exerciseFilterProvider.notifier);
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          FilterChip(
            avatar: const Icon(Icons.videocam, size: 18),
            label: const Text('AI Coach'),
            selected: filter.coachSupportedOnly,
            onSelected: (value) => notifier.setCoachSupportedOnly(value: value),
          ),
          for (final category in ExerciseCategory.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(category.label),
              selected: filter.category == category,
              onSelected: (selected) =>
                  notifier.setCategory(selected ? category : null),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.items, required this.selectMode});

  final List<Exercise> items;
  final bool selectMode;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final exercise = items[index];
        return ListTile(
          title: Text(exercise.name),
          subtitle: Text(
            '${exercise.category.label}, ${exercise.equipment.label}',
          ),
          trailing: exercise.coachKey == null
              ? null
              : Icon(
                  Icons.videocam,
                  color: Theme.of(context).colorScheme.primary,
                  semanticLabel: 'AI Coach supported',
                ),
          onTap: () => selectMode
              ? context.pop(exercise)
              : context.push(AppRoutes.exerciseDetail(exercise.id)),
        );
      },
    );
  }
}
