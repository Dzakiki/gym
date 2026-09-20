import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/features/history/history_providers.dart';
import 'package:formcoach/features/home/streak.dart';
import 'package:formcoach/features/routines/routine_formatting.dart';
import 'package:formcoach/features/routines/routine_providers.dart';
import 'package:formcoach/features/workout/start_workout.dart';
import 'package:formcoach/features/workout/workout_providers.dart';
import 'package:go_router/go_router.dart';

/// The landing screen: workout in progress, today's routine and the streak.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _StreakCard(),
          const SizedBox(height: 16),
          if (active != null) ...[
            _ResumeCard(session: active),
            const SizedBox(height: 16),
          ],
          const _TodaySection(),
          const SizedBox(height: 16),
          if (active == null)
            OutlinedButton.icon(
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('Start empty workout'),
              onPressed: () => startWorkout(context, ref),
            ),
        ],
      ),
    );
  }
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).value ?? const [];
    final now = ref.watch(clockProvider)();
    final streak = computeStreak([
      for (final entry in history) ?entry.session.endedAt,
    ], now);
    final theme = Theme.of(context);

    final title = streak.weeks == 0
        ? 'Start your streak'
        : streak.weeks == 1
        ? '1 week streak'
        : '${streak.weeks} week streak';
    final subtitle = switch (streak.thisWeek) {
      0 => 'No workouts yet this week.',
      1 => '1 workout this week.',
      final n => '$n workouts this week.',
    };
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.local_fire_department,
          size: 36,
          color: theme.colorScheme.onPrimaryContainer,
        ),
        title: Text(title, style: theme.textTheme.titleLarge),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: const Text('Workout in progress'),
        subtitle: Text(session.name),
        trailing: const Text('Resume'),
        onTap: () => context.go(AppRoutes.workout(session.id)),
      ),
    );
  }
}

class _TodaySection extends ConsumerWidget {
  const _TodaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(clockProvider)().toLocal().weekday;
    final routines = ref.watch(routinesProvider(false)).value ?? const [];
    final scheduled = [
      for (final routine in routines)
        if (routine.scheduleDays.contains(today)) routine,
    ];
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today (${weekdayLabel(today)})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (scheduled.isEmpty)
          Card(
            child: ListTile(
              title: const Text('Nothing scheduled today'),
              subtitle: const Text(
                'Rest up, or open your routines to pick a workout.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.workouts),
            ),
          )
        else
          for (final routine in scheduled)
            Card(
              child: ListTile(
                title: Text(routine.name),
                subtitle: Text(
                  routine.description.isEmpty
                      ? 'Scheduled for today'
                      : routine.description,
                ),
                trailing: FilledButton(
                  onPressed: () =>
                      startWorkout(context, ref, routineId: routine.id),
                  child: const Text('Start'),
                ),
                onTap: () => context.push(AppRoutes.routineDetail(routine.id)),
              ),
            ),
      ],
    );
  }
}
