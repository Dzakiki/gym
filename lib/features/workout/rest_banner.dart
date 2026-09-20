import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/features/workout/rest_timer.dart';
import 'package:formcoach/features/workout/workout_formatting.dart';

/// Shows the running rest countdown with quick actions. Hidden when no rest
/// is running.
class RestBanner extends ConsumerWidget {
  const RestBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rest = ref.watch(restTimerProvider);
    if (rest == null) return const SizedBox.shrink();

    final notifier = ref.read(restTimerProvider.notifier);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rest ${formatClock(rest.remaining)}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: notifier.addTime,
                    child: const Text('+15 s'),
                  ),
                  TextButton(
                    onPressed: notifier.skip,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              LinearProgressIndicator(value: rest.fractionLeft),
            ],
          ),
        ),
      ),
    );
  }
}
