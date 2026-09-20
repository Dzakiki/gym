import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/workout_repository.dart';
import 'package:formcoach/features/workout/rest_timer.dart';
import 'package:formcoach/features/workout/set_input.dart';

/// One logged or planned set: weight, reps (or seconds) and a done button.
/// Swipe left to remove the set.
class SetRow extends ConsumerWidget {
  const SetRow({required this.set, required this.restSeconds, super.key});

  final SetLog set;

  /// Rest to start after this set is ticked off.
  final int restSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(workoutRepositoryProvider);
    final done = set.completedAt != null;
    final timed = set.durationSeconds != null;
    final number = set.setIndex + 1;

    return Dismissible(
      key: ValueKey('dismiss-${set.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => repository.removeSet(set.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$number',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: _NumberField(
                key: ValueKey('weight-${set.id}'),
                label: 'kg',
                initialValue: formatWeight(set.weightKg),
                decimal: true,
                max: WorkoutRepository.maxWeightKg,
                onChanged: (text) =>
                    repository.updateSetWeight(set.id, parseWeight(text)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: timed
                  ? _NumberField(
                      key: ValueKey('seconds-${set.id}'),
                      label: 'sec',
                      initialValue: '${set.durationSeconds}',
                      max: WorkoutRepository.maxDurationSeconds,
                      onChanged: (text) => repository.updateSetDuration(
                        set.id,
                        parseWholeNumber(text),
                      ),
                    )
                  : _NumberField(
                      key: ValueKey('reps-${set.id}'),
                      label: 'reps',
                      initialValue: set.reps?.toString() ?? '',
                      max: WorkoutRepository.maxReps,
                      onChanged: (text) => repository.updateSetReps(
                        set.id,
                        parseWholeNumber(text),
                      ),
                    ),
            ),
            IconButton(
              icon: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? Theme.of(context).colorScheme.primary : null,
              ),
              tooltip: done
                  ? 'Set $number done, tap to undo'
                  : 'Complete set $number',
              onPressed: () async {
                await repository.setCompleted(set.id, completed: !done);
                if (!done) {
                  ref.read(restTimerProvider.notifier).start(restSeconds);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.initialValue,
    required this.max,
    required this.onChanged,
    this.decimal = false,
    super.key,
  });

  final String label;
  final String initialValue;
  final num max;
  final bool decimal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
        ),
        LengthLimitingTextInputFormatter(decimal ? 6 : 4),
        MaxValueFormatter(max),
      ],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
