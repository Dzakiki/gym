import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/exercise_repository.dart';
import 'package:formcoach/domain/enum_labels.dart';
import 'package:formcoach/domain/enums.dart';
import 'package:go_router/go_router.dart';

/// Creates a custom exercise.
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key});

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final _name = TextEditingController();
  final _instructions = TextEditingController();
  var _category = ExerciseCategory.strength;
  var _equipment = Equipment.bodyweight;
  final _muscles = <MuscleGroup>{};
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _muscles.isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(exerciseRepositoryProvider)
          .createCustom(
            name: _name.text,
            category: _category,
            equipment: _equipment,
            primaryMuscles: MuscleGroup.values
                .where(_muscles.contains)
                .toList(),
            instructions: _instructions.text,
          );
      if (mounted) context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the exercise.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New exercise'),
        actions: [
          TextButton(
            onPressed: _valid && !_saving ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Exercise name',
              border: OutlineInputBorder(),
            ),
            maxLength: ExerciseRepository.maxNameLength,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Category', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final category in ExerciseCategory.values)
                ChoiceChip(
                  label: Text(category.label),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Equipment', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final equipment in Equipment.values)
                ChoiceChip(
                  label: Text(equipment.label),
                  selected: _equipment == equipment,
                  onSelected: (_) => setState(() => _equipment = equipment),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Main muscles (pick at least one)',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final muscle in MuscleGroup.values)
                FilterChip(
                  label: Text(muscle.label),
                  selected: _muscles.contains(muscle),
                  onSelected: (selected) => setState(
                    () => selected
                        ? _muscles.add(muscle)
                        : _muscles.remove(muscle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _instructions,
            decoration: const InputDecoration(
              labelText: 'How to do it (optional)',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
