import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/core/widgets/empty_state.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/routine_draft.dart';
import 'package:formcoach/features/routines/routine_formatting.dart';
import 'package:formcoach/features/routines/routine_item_editor.dart';
import 'package:go_router/go_router.dart';

/// Creates a routine, or edits the one with [routineId].
class RoutineBuilderScreen extends ConsumerStatefulWidget {
  const RoutineBuilderScreen({this.routineId, super.key});

  final String? routineId;

  @override
  ConsumerState<RoutineBuilderScreen> createState() =>
      _RoutineBuilderScreenState();
}

/// A draft item with a stable key so reordering keeps the right row.
class _Entry {
  _Entry(this.item);

  final Object key = Object();
  DraftItem item;
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _days = <int>{};
  final _entries = <_Entry>[];

  bool _loading = false;
  bool _notFound = false;
  bool _saving = false;

  bool get _isEditing => widget.routineId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loading = true;
      _load(widget.routineId!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load(String id) async {
    final detail = await ref.read(routineRepositoryProvider).getDetail(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (detail == null || detail.routine.isTemplate) {
        _notFound = true;
        return;
      }
      _nameController.text = detail.routine.name;
      _descriptionController.text = detail.routine.description;
      _days.addAll(detail.routine.scheduleDays);
      _entries.addAll(
        detail.items.map(
          (item) => _Entry(
            DraftItem(
              id: item.entry.id,
              exerciseId: item.exercise.id,
              exerciseName: item.exercise.name,
              targetSets: item.entry.targetSets,
              targetReps: item.entry.targetReps,
              targetSeconds: item.entry.targetSeconds,
              restSeconds: item.entry.restSeconds,
            ),
          ),
        ),
      );
    });
  }

  RoutineDraft get _draft => RoutineDraft(
    id: widget.routineId,
    name: _nameController.text,
    description: _descriptionController.text,
    scheduleDays: _days.toList()..sort(),
    items: [for (final entry in _entries) entry.item],
  );

  Future<void> _addExercise() async {
    final exercise = await context.push<Exercise>(AppRoutes.pickExercise);
    if (exercise == null) return;
    setState(
      () => _entries.add(
        _Entry(
          DraftItem.forExercise(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
          ),
        ),
      ),
    );
  }

  Future<void> _editEntry(_Entry entry) async {
    final edited = await showRoutineItemEditor(context, entry.item);
    if (edited != null) setState(() => entry.item = edited);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(routineRepositoryProvider).saveRoutine(_draft);
      if (mounted) context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the routine.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _draft.validationError;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit routine' : 'New routine'),
        actions: [
          TextButton(
            onPressed: error == null && !_saving ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _body(error),
    );
  }

  Widget _body(String? error) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_notFound) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Routine not found',
        message: 'It may have been deleted, or it is a read-only template.',
      );
    }
    return ReorderableListView.builder(
      header: _buildForm(),
      footer: _buildFooter(error),
      itemCount: _entries.length,
      onReorderItem: (oldIndex, newIndex) => setState(() {
        _entries.insert(newIndex, _entries.removeAt(oldIndex));
      }),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return ListTile(
          key: ValueKey(entry.key),
          title: Text(entry.item.exerciseName),
          subtitle: Text(_summary(entry.item)),
          onTap: () => _editEntry(entry),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove ${entry.item.exerciseName}',
            onPressed: () => setState(() => _entries.remove(entry)),
          ),
        );
      },
    );
  }

  String _summary(DraftItem item) {
    final target = item.targetReps != null
        ? '${item.targetSets} x ${item.targetReps}'
        : '${item.targetSets} x ${item.targetSeconds} s';
    return '$target, rest ${formatRest(item.restSeconds)}';
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Routine name',
              border: OutlineInputBorder(),
            ),
            maxLength: RoutineLimits.maxNameLength,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Text('Schedule', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(weekdayLabel(day)),
                  selected: _days.contains(day),
                  onSelected: (selected) => setState(
                    () => selected ? _days.add(day) : _days.remove(day),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Exercises', style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  Widget _buildFooter(String? error) {
    final showHint =
        error != null &&
        (_nameController.text.isNotEmpty || _entries.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
            onPressed: _addExercise,
          ),
          if (showHint) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
