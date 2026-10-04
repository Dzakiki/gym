import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/features/workout/rest_alarm.dart';

/// The state of a running rest countdown.
class RestTimerState {
  const RestTimerState({required this.remaining, required this.total});

  /// Seconds left.
  final int remaining;

  /// Seconds the countdown started with (including any added time).
  final int total;

  /// Fraction of the rest that is left, from 1 down to 0.
  double get fractionLeft => total == 0 ? 0 : remaining / total;
}

/// Counts down the rest between sets. The state is null when no rest is
/// running. Rings a haptic pulse when the countdown ends on screen.
///
/// The countdown runs to a fixed end time rather than counting ticks, so it
/// stays right after the phone paused the app. While the app is hidden, the
/// [RestAlarm] alerts the athlete when the rest is over.
class RestTimer extends Notifier<RestTimerState?> {
  static const addedSeconds = 15;

  Timer? _ticker;
  DateTime? _endsAt;
  bool _hidden = false;

  @override
  RestTimerState? build() {
    final lifecycle = AppLifecycleListener(onHide: appHidden, onShow: appShown);
    ref.onDispose(() {
      _ticker?.cancel();
      lifecycle.dispose();
    });
    return null;
  }

  /// Starts (or restarts) a countdown of [seconds]. Does nothing for 0.
  void start(int seconds) {
    if (seconds <= 0) return;
    _ticker?.cancel();
    _endsAt = _now().add(Duration(seconds: seconds));
    state = RestTimerState(remaining: seconds, total: seconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    unawaited(_alarm.prepare());
  }

  /// Adds [addedSeconds] to a running countdown.
  void addTime() {
    final current = state;
    final endsAt = _endsAt;
    if (current == null || endsAt == null) return;
    _endsAt = endsAt.add(const Duration(seconds: addedSeconds));
    state = RestTimerState(
      remaining: current.remaining + addedSeconds,
      total: current.total + addedSeconds,
    );
  }

  /// Stops the countdown without any signal.
  void skip() {
    _stop();
    unawaited(_alarm.cancel());
  }

  /// The app left the screen: hand the end of the rest to the alarm.
  @visibleForTesting
  void appHidden() {
    _hidden = true;
    final endsAt = _endsAt;
    if (endsAt != null) unawaited(_alarm.schedule(endsAt));
  }

  /// The app is back on screen: the countdown shows the time again.
  @visibleForTesting
  void appShown() {
    _hidden = false;
    unawaited(_alarm.cancel());
    if (_endsAt != null) _refresh();
  }

  RestAlarm get _alarm => ref.read(restAlarmProvider);

  DateTime _now() => ref.read(clockProvider)();

  void _refresh() {
    final current = state;
    final endsAt = _endsAt;
    if (current == null || endsAt == null) return;
    final millisLeft = endsAt.difference(_now()).inMilliseconds;
    if (millisLeft <= 0) {
      _stop();
      // Away from the screen the alarm does the alerting.
      if (!_hidden) unawaited(HapticFeedback.heavyImpact());
      return;
    }
    state = RestTimerState(
      remaining: (millisLeft + 999) ~/ 1000,
      total: current.total,
    );
  }

  void _stop() {
    _ticker?.cancel();
    _endsAt = null;
    state = null;
  }
}

final restTimerProvider = NotifierProvider<RestTimer, RestTimerState?>(
  RestTimer.new,
);
