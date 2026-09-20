import 'package:flutter/material.dart';
import 'package:formcoach/data/repositories/routine_draft.dart';

/// Opens a bottom sheet to edit the sets, reps or time and rest of [item].
/// Returns the edited item, or null if the sheet was dismissed.
Future<DraftItem?> showRoutineItemEditor(BuildContext context, DraftItem item) {
  return showModalBottomSheet<DraftItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _RoutineItemEditor(initial: item),
  );
}

class _RoutineItemEditor extends StatefulWidget {
  const _RoutineItemEditor({required this.initial});

  final DraftItem initial;

  @override
  State<_RoutineItemEditor> createState() => _RoutineItemEditorState();
}

class _RoutineItemEditorState extends State<_RoutineItemEditor> {
  late DraftItem _item = widget.initial;

  bool get _timed => _item.targetSeconds != null;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _item.exerciseName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _StepperRow(
              label: 'Sets',
              value: _item.targetSets,
              min: 1,
              max: RoutineLimits.maxSets,
              onChanged: (value) =>
                  setState(() => _item = _item.copyWith(targetSets: value)),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Reps')),
                ButtonSegment(value: true, label: Text('Time')),
              ],
              selected: {_timed},
              onSelectionChanged: (selection) => setState(
                () => _item = selection.first
                    ? _item.withSeconds(30)
                    : _item.withReps(10),
              ),
            ),
            const SizedBox(height: 8),
            if (_timed)
              _StepperRow(
                label: 'Seconds',
                value: _item.targetSeconds!,
                min: 5,
                max: RoutineLimits.maxSeconds,
                step: 5,
                onChanged: (value) =>
                    setState(() => _item = _item.withSeconds(value)),
              )
            else
              _StepperRow(
                label: 'Reps',
                value: _item.targetReps!,
                min: 1,
                max: RoutineLimits.maxReps,
                onChanged: (value) =>
                    setState(() => _item = _item.withReps(value)),
              ),
            _StepperRow(
              label: 'Rest (s)',
              value: _item.restSeconds,
              min: 0,
              max: RoutineLimits.maxRestSeconds,
              step: 15,
              onChanged: (value) =>
                  setState(() => _item = _item.copyWith(restSeconds: value)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_item),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Decrease $label',
          onPressed: value > min
              ? () => onChanged((value - step).clamp(min, max))
              : null,
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Increase $label',
          onPressed: value < max
              ? () => onChanged((value + step).clamp(min, max))
              : null,
        ),
      ],
    );
  }
}
