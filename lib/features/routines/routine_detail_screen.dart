import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/core/widgets/empty_state.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/routine_repository.dart';
import 'package:formcoach/features/routines/routine_formatting.dart';
import 'package:formcoach/features/routines/routine_providers.dart';
import 'package:go_router/go_router.dart';

/// Shows a routine or template with its exercises and targets.
class RoutineDetailScreen extends ConsumerWidget {
  const RoutineDetailScreen({required this.routineId, super.key});

  final String routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(routineDetailProvider(routineId));
    final value = detail.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(value?.routine.name ?? 'Routine'),
        actions: [
          if (value != null && !value.routine.isTemplate) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit routine',
              onPressed: () => context.push(AppRoutes.editRoutine(routineId)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete routine',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load this routine',
        ),
        data: (item) => item == null
            ? const EmptyState(
                icon: Icons.search_off,
                title: 'Routine not found',
                message: 'It may have been deleted.',
              )
            : _RoutineBody(detail: item),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete routine?'),
        content: const Text('This routine will be removed from your list.'),
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
    await ref.read(routineRepositoryProvider).deleteRoutine(routineId);
    if (context.mounted) context.pop();
  }
}

class _RoutineBody extends ConsumerWidget {
  const _RoutineBody({required this.detail});

  final RoutineDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routine = detail.routine;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (routine.description.isNotEmpty)
                Text(routine.description, style: theme.textTheme.bodyLarge),
              if (routine.scheduleDays.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final day in routine.scheduleDays)
                      Chip(label: Text(weekdayLabel(day))),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              for (final item in detail.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.exercise.name),
                  subtitle: Text('Rest ${formatRest(item.entry.restSeconds)}'),
                  trailing: Text(
                    formatTarget(item.entry),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
            ],
          ),
        ),
        if (routine.isTemplate)
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy to my routines'),
                onPressed: () => _copy(context, ref),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final newId = await ref
        .read(routineRepositoryProvider)
        .copyTemplate(detail.routine.id);
    if (newId == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Added to my routines')));
    context.pushReplacement(AppRoutes.routineDetail(newId));
  }
}
