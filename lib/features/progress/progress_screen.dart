import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/core/date_format.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';
import 'package:formcoach/features/form_coach/exercises/registry.dart';
import 'package:formcoach/features/history/history_providers.dart';
import 'package:formcoach/features/progress/progress_charts.dart';
import 'package:formcoach/features/progress/progress_formatting.dart';
import 'package:formcoach/features/progress/progress_providers.dart';
import 'package:formcoach/features/progress/progress_stats.dart';
import 'package:formcoach/features/settings/settings_providers.dart';
import 'package:formcoach/features/workout/workout_formatting.dart';
import 'package:go_router/go_router.dart';

/// Training volume, form scores, personal records and past workouts.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _Header('Volume per week'),
          const _VolumeSection(),
          const _Header('Form score'),
          const _FormSection(),
          const _Header('Personal records'),
          const _RecordsSection(),
          const _Header('Workouts'),
          if (history.isEmpty)
            const ListTile(
              title: Text('No workouts yet'),
              subtitle: Text('Finish a workout and it will show up here.'),
            )
          else
            for (final entry in history) _HistoryTile(entry: entry),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(text),
  );
}

class _VolumeSection extends ConsumerWidget {
  const _VolumeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(completedSetsProvider).value ?? const [];
    final unit = ref.watch(weightUnitProvider);
    final weeks = weeklyVolumes(sets, ref.watch(clockProvider)());
    if (weeks.every((week) => week.volumeKg == 0)) {
      return const _Hint(
        'Log sets with weight and finish a workout to see your volume.',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VolumeChart(weeks: weeks, unit: unit),
    );
  }
}

class _FormSection extends ConsumerStatefulWidget {
  const _FormSection();

  @override
  ConsumerState<_FormSection> createState() => _FormSectionState();
}

class _FormSectionState extends ConsumerState<_FormSection> {
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final scores = ref.watch(coachScoresProvider).value ?? const [];
    if (scores.isEmpty) {
      return const _Hint('Coach a set in a workout to track your form.');
    }

    final keys = {for (final point in scores) point.exerciseKey}.toList();
    final selected = keys.contains(_selectedKey) ? _selectedKey! : keys.first;
    final shown = [
      for (final point in scores)
        if (point.exerciseKey == selected) point,
    ];
    final recent = shown.length > 20 ? shown.sublist(shown.length - 20) : shown;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final key in keys)
                ChoiceChip(
                  label: Text(coachDefinitionFor(key)?.name ?? key),
                  selected: key == selected,
                  onSelected: (_) => setState(() => _selectedKey = key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FormScoreChart(points: recent),
        ],
      ),
    );
  }
}

class _RecordsSection extends ConsumerWidget {
  const _RecordsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(completedSetsProvider).value ?? const [];
    final scores = ref.watch(coachScoresProvider).value ?? const [];
    final unit = ref.watch(weightUnitProvider);
    final records = personalRecords(sets, scores).take(10).toList();
    if (records.isEmpty) {
      return const _Hint('Your personal bests will show up here.');
    }
    return Column(
      children: [
        for (final record in records)
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: Text(describeRecord(record, unit)),
            subtitle: Text(formatDate(record.achievedAt)),
          ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final session = entry.session;
    return ListTile(
      title: Text(session.name),
      subtitle: Text(
        '${formatDate(session.startedAt)}, '
        '${formatDuration(entry.duration)}, ${entry.completedSets} sets',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.historyDetail(session.id)),
    );
  }
}
