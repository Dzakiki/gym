import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/domain/weight_unit.dart';
import 'package:formcoach/features/settings/settings_providers.dart';

/// Settings and information about the app.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider);
    final voice = ref.watch(voiceCuesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          const _SectionHeader('Units'),
          ListTile(
            title: const Text('Weight unit'),
            subtitle: const Text('Weights are stored in kg and converted.'),
            trailing: SegmentedButton<WeightUnit>(
              segments: [
                for (final option in WeightUnit.values)
                  ButtonSegment(value: option, label: Text(option.label)),
              ],
              selected: {unit},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(weightUnitProvider.notifier).select(selection.first),
            ),
          ),
          const _SectionHeader('AI Coach'),
          SwitchListTile(
            title: const Text('Spoken cues'),
            subtitle: const Text('The coach says corrections out loud.'),
            value: voice,
            onChanged: (enabled) =>
                ref.read(voiceCuesProvider.notifier).set(enabled: enabled),
          ),
          const _SectionHeader('About'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'FormCoach is a training aid, not medical advice. Stop if you '
              'feel pain. Camera images are processed on your phone and are '
              'never uploaded.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
