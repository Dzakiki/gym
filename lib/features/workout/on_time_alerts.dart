import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/features/settings/settings_providers.dart';
import 'package:formcoach/features/workout/rest_alarm.dart';

/// Whether the "rest is over" alert comes on time. Re-read it (invalidate)
/// after the user may have changed the system setting.
final onTimeAlertsProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(restAlarmProvider).alertsOnTime(),
);

/// The first time a rest starts while alerts would come late, explains why
/// and offers to open the system setting. Asks only once; the Profile screen
/// offers it again.
Future<void> offerOnTimeAlerts(BuildContext context, WidgetRef ref) async {
  final store = ref.read(settingsStoreProvider);
  if (store.askedAboutOnTimeAlerts) return;
  final alarm = ref.read(restAlarmProvider);
  if (await alarm.alertsOnTime()) return;
  if (!context.mounted) return;

  await store.setAskedAboutOnTimeAlerts();
  if (!context.mounted) return;
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.timer_outlined),
      title: const Text('Get rest alerts on time?'),
      content: const Text(
        'When FormCoach is in the background, your phone may send the '
        '"Rest is over" alert up to a minute late. Allow FormCoach to set '
        'alarms to get it right on time. You can change this later in '
        'Profile.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  if (allow ?? false) await alarm.allowOnTimeAlerts();
}
