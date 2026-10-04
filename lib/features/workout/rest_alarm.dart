import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// Tells the athlete their rest is over while the app is not on screen.
abstract interface class RestAlarm {
  /// Gets ready to alert (asks for the notification permission the first
  /// time). Called when a rest starts, while the app is on screen.
  Future<void> prepare();

  /// Alerts at [endsAt] (UTC), replacing any alert scheduled earlier.
  Future<void> schedule(DateTime endsAt);

  /// Cancels the scheduled alert, if any.
  Future<void> cancel();

  /// Whether the alert comes right when the rest ends. On Android 14+ it may
  /// come up to about a minute late unless the user allows the app to set
  /// exact alarms.
  Future<bool> alertsOnTime();

  /// Opens the system setting that lets alerts come on time.
  Future<void> allowOnTimeAlerts();
}

/// A local notification posted by the system when the rest ends, through the
/// `flutter_local_notifications` plugin.
///
/// Problems with the plugin (permission denied, no platform support) are
/// swallowed: a rest timer that cannot notify must still count down.
class LocalNotificationRestAlarm implements RestAlarm {
  LocalNotificationRestAlarm([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 1;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'rest_timer',
      'Rest timer',
      channelDescription: 'Tells you when the rest between sets is over.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _prepared;

  @override
  Future<void> prepare() => _prepared ??= _guard(() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_rest'),
        // Permissions are asked for below, not when the plugin starts.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _android?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
  });

  @override
  Future<void> schedule(DateTime endsAt) => _guard(() async {
    await prepare();
    // Exact alarms need the user's consent on Android 14+; an inexact one
    // may come a little late but still comes.
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Rest is over',
      body: 'Time for your next set.',
      scheduledDate: tz.TZDateTime.from(endsAt, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });

  @override
  Future<void> cancel() => _guard(() => _plugin.cancel(id: _notificationId));

  @override
  Future<bool> alertsOnTime() async {
    try {
      // Only Android delays alerts; elsewhere there is nothing to allow.
      return await _android?.canScheduleExactNotifications() ?? true;
    } on Object catch (error) {
      debugPrint('Rest alarm failed: $error');
      return true;
    }
  }

  @override
  Future<void> allowOnTimeAlerts() =>
      _guard(() async => _android?.requestExactAlarmsPermission());

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      debugPrint('Rest alarm failed: $error');
    }
  }
}

/// Never alerts. Used in tests.
class SilentRestAlarm implements RestAlarm {
  const SilentRestAlarm();

  @override
  Future<void> prepare() async {}

  @override
  Future<void> schedule(DateTime endsAt) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> alertsOnTime() async => true;

  @override
  Future<void> allowOnTimeAlerts() async {}
}

final restAlarmProvider = Provider<RestAlarm>(
  (ref) => LocalNotificationRestAlarm(),
);
