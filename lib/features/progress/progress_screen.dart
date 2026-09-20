import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/core/date_format.dart';
import 'package:formcoach/core/widgets/empty_state.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';
import 'package:formcoach/features/history/history_providers.dart';
import 'package:formcoach/features/workout/workout_formatting.dart';
import 'package:go_router/go_router.dart';

/// Shows past workouts. Charts and records will be added here.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load your history',
        ),
        data: (entries) => entries.isEmpty
            ? const EmptyState(
                icon: Icons.history,
                title: 'No workouts yet',
                message: 'Finish a workout and it will show up here.',
              )
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _HistoryTile(entry: entries[index]),
              ),
      ),
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
