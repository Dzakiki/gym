import 'package:formcoach/features/workout/rest_alarm.dart';

/// Records what the app asked of the rest alarm.
class FakeRestAlarm implements RestAlarm {
  FakeRestAlarm({this.onTime = true});

  /// Whether alerts come on time (on Android: exact alarms are allowed).
  bool onTime;

  int prepared = 0;
  final scheduled = <DateTime>[];
  int cancelled = 0;
  int onTimeRequests = 0;

  @override
  Future<void> prepare() async => prepared++;

  @override
  Future<void> schedule(DateTime endsAt) async => scheduled.add(endsAt);

  @override
  Future<void> cancel() async => cancelled++;

  @override
  Future<bool> alertsOnTime() async => onTime;

  @override
  Future<void> allowOnTimeAlerts() async => onTimeRequests++;
}
