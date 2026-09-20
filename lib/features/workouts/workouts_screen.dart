import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/features/routines/routine_formatting.dart';
import 'package:formcoach/features/routines/routine_providers.dart';
import 'package:formcoach/features/workout/start_workout.dart';
import 'package:formcoach/features/workout/workout_providers.dart';
import 'package:go_router/go_router.dart';

/// Entry point for routines, program templates and the exercise library.
class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: ListView(
        children: [
          const _WorkoutStatusTile(),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Exercise library'),
            subtitle: const Text('Browse and search every exercise'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.exerciseLibrary),
          ),
          _SectionHeader(
            'My routines',
            action: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New routine',
              onPressed: () => context.push(AppRoutes.newRoutine),
            ),
          ),
          const _RoutineSection(
            templates: false,
            emptyMessage:
                'No routines yet. Copy a program template below to start.',
          ),
          const _SectionHeader('Program templates'),
          const _RoutineSection(templates: true),
        ],
      ),
    );
  }
}

/// Resumes the workout in progress, or starts an empty one.
class _WorkoutStatusTile extends ConsumerWidget {
  const _WorkoutStatusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider).value;
    if (active != null) {
      return ListTile(
        tileColor: Theme.of(context).colorScheme.primaryContainer,
        leading: const Icon(Icons.timer_outlined),
        title: const Text('Workout in progress'),
        subtitle: Text(active.name),
        trailing: const Text('Resume'),
        onTap: () => context.go(AppRoutes.workout(active.id)),
      );
    }
    return ListTile(
      leading: const Icon(Icons.play_arrow_outlined),
      title: const Text('Start empty workout'),
      subtitle: const Text('Add exercises as you go'),
      onTap: () => startWorkout(context, ref),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, action == null ? 24 : 16, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _RoutineSection extends ConsumerWidget {
  const _RoutineSection({required this.templates, this.emptyMessage});

  final bool templates;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider(templates));
    return routines.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const ListTile(
        leading: Icon(Icons.error_outline),
        title: Text('Could not load routines'),
      ),
      data: (items) {
        if (items.isEmpty) {
          return ListTile(title: Text(emptyMessage ?? 'Nothing here yet.'));
        }
        return Column(
          children: [for (final routine in items) _RoutineTile(routine)],
        );
      },
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile(this.routine);

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final days = routine.scheduleDays.map(weekdayLabel).join(', ');
    return ListTile(
      title: Text(routine.name),
      subtitle: Text(days.isEmpty ? routine.description : days),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.routineDetail(routine.id)),
    );
  }
}
